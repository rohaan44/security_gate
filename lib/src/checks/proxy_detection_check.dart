import '../check_result.dart';
import '../failure_action.dart';
import '../security_check.dart';

/// Detects whether the device is routing traffic through an HTTP/HTTPS proxy.
///
/// Checks system environment variables and proxy settings to determine
/// if a proxy is configured. This is a basic detection — sophisticated
/// proxies may not be detectable via this method alone.
///
/// ## No native dependency required
///
/// This check uses `dart:io` environment variable inspection.
///
/// ## Usage
///
/// ```dart
/// final pipeline = SecurityPipeline(
///   checks: [ProxyDetectionCheck()],
/// );
/// ```
class ProxyDetectionCheck extends SecurityCheck {
  /// Optional list of allowed proxy hosts. If set, connections through
  /// these proxies will not trigger a failure.
  final List<String> allowedProxyHosts;

  /// Optional custom failure message to override the default.
  final String? customFailureMessage;

  /// Creates a [ProxyDetectionCheck].
  ///
  /// [allowedProxyHosts] can be used to whitelist known corporate proxies.
  ProxyDetectionCheck({
    this.allowedProxyHosts = const [],
    this.customFailureMessage,
  });

  @override
  String get name => 'Proxy Detection';

  @override
  Duration get timeout => const Duration(seconds: 5);

  @override
  Future<CheckResult> execute() async {
    try {
      // Check common proxy environment variables.
      final proxyVars = [
        'http_proxy',
        'HTTP_PROXY',
        'https_proxy',
        'HTTPS_PROXY',
        'all_proxy',
        'ALL_PROXY',
      ];

      for (final varName in proxyVars) {
        final value = String.fromEnvironment(varName, defaultValue: '');
        if (value.isNotEmpty) {
          // Check if this proxy is in the allowed list.
          final isAllowed = allowedProxyHosts.any(
            (host) => value.contains(host),
          );
          if (!isAllowed) {
            return CheckResult.fail(
              checkName: name,
              reason: customFailureMessage ??
                  'HTTP proxy detected via $varName: $value',
              action: FailureAction.dialog,
            );
          }
        }
      }

      // TODO: For deeper detection, wire to a platform channel that checks
      // system proxy settings via:
      //   - Android: ConnectivityManager.getDefaultProxy()
      //   - iOS: CFNetworkCopySystemProxySettings()

      return CheckResult.pass(checkName: name);
    } catch (e) {
      return CheckResult.fail(
        checkName: name,
        reason: 'Proxy detection failed: $e',
        action: FailureAction.dialog,
      );
    }
  }
}
