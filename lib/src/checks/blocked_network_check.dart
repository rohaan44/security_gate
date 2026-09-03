import 'dart:io';

import '../check_result.dart';
import '../failure_action.dart';
import '../security_check.dart';

/// Detects whether the device is connected through a VPN or is on a
/// blocked network.
///
/// Checks active network interfaces for VPN tunnel interfaces and
/// optionally verifies the external IP against a blocklist.
///
/// ## No native dependency required
///
/// This check uses `dart:io` [NetworkInterface] inspection for VPN
/// detection. For IP-based blocklist checking, you may optionally
/// wire it to an IP reputation service.
///
/// ## Usage
///
/// ```dart
/// final pipeline = SecurityPipeline(
///   checks: [
///     BlockedNetworkCheck(
///       blockVpn: true,
///       blockedSubnets: ['10.8.0.0/24'],
///     ),
///   ],
/// );
/// ```
class BlockedNetworkCheck extends SecurityCheck {
  /// Whether to fail if a VPN tunnel interface is detected.
  final bool blockVpn;

  /// List of blocked subnet prefixes (e.g. `['10.8.0.', '172.16.']`).
  ///
  /// If the device's IP address starts with any of these prefixes,
  /// the check will fail.
  final List<String> blockedSubnets;

  /// Optional custom failure message to override the default.
  final String? customFailureMessage;

  /// Creates a [BlockedNetworkCheck].
  BlockedNetworkCheck({
    this.blockVpn = true,
    this.blockedSubnets = const [],
    this.customFailureMessage,
  });

  @override
  String get name => 'Blocked Network / VPN Detection';

  @override
  Duration get timeout => const Duration(seconds: 10);

  @override
  Future<CheckResult> execute() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.any,
      );

      // Check for VPN tunnel interfaces.
      if (blockVpn) {
        for (final iface in interfaces) {
          final ifaceName = iface.name.toLowerCase();
          // Common VPN tunnel interface names across platforms.
          if (ifaceName.startsWith('tun') ||
              ifaceName.startsWith('tap') ||
              ifaceName.startsWith('ppp') ||
              ifaceName.startsWith('utun') ||
              ifaceName.startsWith('ipsec') ||
              ifaceName.startsWith('wg')) {
            return CheckResult.fail(
              checkName: name,
              reason: customFailureMessage ??
                  'VPN tunnel interface detected: ${iface.name}',
              action: FailureAction.dialog,
            );
          }
        }
      }

      // Check for blocked subnets.
      if (blockedSubnets.isNotEmpty) {
        for (final iface in interfaces) {
          for (final addr in iface.addresses) {
            final ip = addr.address;
            for (final subnet in blockedSubnets) {
              if (ip.startsWith(subnet)) {
                return CheckResult.fail(
                  checkName: name,
                  reason: customFailureMessage ??
                      'Device IP $ip is on blocked subnet $subnet '
                          '(interface: ${iface.name}).',
                  action: FailureAction.dialog,
                );
              }
            }
          }
        }
      }

      return CheckResult.pass(checkName: name);
    } catch (e) {
      return CheckResult.fail(
        checkName: name,
        reason: 'Network check failed: $e',
        action: FailureAction.dialog,
      );
    }
  }
}
