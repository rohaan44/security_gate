/// A pluggable, callback-driven device-security-check pipeline for Flutter.
///
/// **security_gate** lets you define and run an ordered sequence of security
/// checks (jailbreak, root, Play Integrity, proxy, VPN, keyboard, Wi-Fi)
/// and get a simple pass/fail result. The host app decides what to do on
/// success or failure — no UI, navigation, or state management baked in.
///
/// ## Quick start
///
/// ```dart
/// import 'package:security_gate/security_gate.dart';
///
/// final pipeline = SecurityPipeline(
///   checks: [
///     InternetWifiSecurityCheck(),
///     JailbreakRootCheck(),
///     PlayIntegrityCheck(),
///     ProxyDetectionCheck(),
///     BlockedNetworkCheck(blockVpn: true),
///   ],
/// );
///
/// final result = await pipeline.execute();
/// if (result.passed) {
///   // Navigate to home screen
/// } else {
///   // Handle specific failure via type-safe pattern matching
///   switch (result.failedCheck?.check) {
///     case BlockedNetworkCheck():
///       // Show VPN modal
///     default:
///       // Show generic error
///   }
/// }
/// ```
library;

// Core abstractions
export 'src/failure_action.dart';
export 'src/check_result.dart';
export 'src/retry_policy.dart';
export 'src/security_check.dart';
export 'src/pipeline_result.dart';
export 'src/security_logger.dart';
export 'src/security_pipeline.dart';

// Built-in checks (opt-in)
export 'src/checks/jailbreak_root_check.dart';
export 'src/checks/play_integrity_check.dart';
export 'src/checks/proxy_detection_check.dart';
export 'src/checks/blocked_network_check.dart';
export 'src/checks/third_party_keyboard_check.dart';
export 'src/checks/internet_wifi_security_check.dart';
