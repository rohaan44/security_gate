import 'dart:io';

import '../check_result.dart';
import '../failure_action.dart';
import '../retry_policy.dart';
import '../security_check.dart';

/// Verifies internet connectivity and Wi-Fi network security.
///
/// Checks that the device has internet connectivity and optionally
/// verifies that the Wi-Fi network meets security requirements (e.g.
/// not an open/unsecured network).
///
/// ## Native dependency
///
/// For full functionality, wire this to:
/// - [`connectivity_plus`](https://pub.dev/packages/connectivity_plus) for
///   connectivity status
/// - [`network_info_plus`](https://pub.dev/packages/network_info_plus) for
///   Wi-Fi network details (SSID, BSSID, etc.)
///
/// The stub implementation performs a basic connectivity check via DNS lookup.
///
/// ## Usage
///
/// ```dart
/// final pipeline = SecurityPipeline(
///   checks: [
///     InternetWifiSecurityCheck(
///       requireSecureWifi: true,
///       connectivityCheckHost: 'google.com',
///     ),
///   ],
/// );
/// ```
class InternetWifiSecurityCheck extends SecurityCheck {
  /// Whether to require that Wi-Fi networks be secured (WPA2/WPA3).
  ///
  /// When `true`, the check will fail if the device is connected to
  /// an open/unsecured Wi-Fi network. Requires platform channel
  /// integration for full functionality.
  final bool requireSecureWifi;

  /// Host to use for connectivity verification via DNS lookup.
  final String connectivityCheckHost;

  /// Optional custom failure message to override the default.
  final String? customFailureMessage;

  /// Creates an [InternetWifiSecurityCheck].
  InternetWifiSecurityCheck({
    this.requireSecureWifi = false,
    this.connectivityCheckHost = 'google.com',
    this.customFailureMessage,
  });

  @override
  String get name => 'Internet / Wi-Fi Security';

  @override
  Duration get timeout => const Duration(seconds: 10);

  @override
  RetryPolicy? get retryPolicy => const RetryPolicy(
    maxAttempts: 2,
    backoff: Duration(seconds: 2),
  );

  @override
  Future<CheckResult> execute() async {
    try {
      // Basic connectivity check via DNS lookup.
      final result = await InternetAddress.lookup(connectivityCheckHost);
      if (result.isEmpty || result.first.rawAddress.isEmpty) {
        return CheckResult.fail(
          checkName: name,
          reason: customFailureMessage ?? 'No internet connectivity detected.',
          action: FailureAction.retry,
        );
      }

      // TODO: wire to connectivity_plus for detailed connectivity status
      // Example:
      //   final connectivityResult = await Connectivity().checkConnectivity();
      //   if (connectivityResult == ConnectivityResult.none) {
      //     return CheckResult.fail(...);
      //   }

      // TODO: wire to network_info_plus for Wi-Fi security verification
      // Example:
      //   if (requireSecureWifi && connectivityResult == ConnectivityResult.wifi) {
      //     final wifiInfo = NetworkInfo();
      //     final wifiName = await wifiInfo.getWifiName();
      //     // Check Wi-Fi security level via platform channel
      //   }

      return CheckResult.pass(checkName: name);
    } on SocketException {
      return CheckResult.fail(
        checkName: name,
        reason: 'No internet connectivity — DNS lookup failed.',
        action: FailureAction.retry,
      );
    } catch (e) {
      return CheckResult.fail(
        checkName: name,
        reason: 'Internet/Wi-Fi security check failed: $e',
        action: FailureAction.retry,
      );
    }
  }
}
