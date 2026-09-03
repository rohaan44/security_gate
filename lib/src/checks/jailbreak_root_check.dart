import '../check_result.dart';
import '../failure_action.dart';
import '../retry_policy.dart';
import '../security_check.dart';

/// Detects whether the device is jailbroken (iOS) or rooted (Android).
///
/// ## Native dependency
///
/// This check requires a jailbreak/root detection package. Wire it to
/// one of the following:
/// - [`flutter_jailbreak_detection`](https://pub.dev/packages/flutter_jailbreak_detection)
/// - [`safe_device`](https://pub.dev/packages/safe_device)
/// - A custom platform channel implementation.
///
/// ## Usage
///
/// ```dart
/// final pipeline = SecurityPipeline(
///   checks: [JailbreakRootCheck()],
/// );
/// ```
class JailbreakRootCheck extends SecurityCheck {
  /// Optional custom failure message to override the default.
  final String? customFailureMessage;

  /// Creates a [JailbreakRootCheck].
  JailbreakRootCheck({this.customFailureMessage});

  @override
  String get name => 'Jailbreak / Root Detection';

  @override
  Duration get timeout => const Duration(seconds: 10);

  @override
  RetryPolicy? get retryPolicy => null;

  @override
  Future<CheckResult> execute() async {
    try {
      // TODO: wire to flutter_jailbreak_detection or similar package
      // Example integration:
      //   final isJailbroken = await FlutterJailbreakDetection.jailbroken;
      //   if (isJailbroken) {
      //     return CheckResult.fail(
      //       checkName: name,
      //       reason: customFailureMessage ?? 'Device is jailbroken or rooted.',
      //       action: FailureAction.forceExit,
      //     );
      //   }

      // Stub: always passes until wired to a real detection package.
      return CheckResult.pass(checkName: name);
    } catch (e) {
      return CheckResult.fail(
        checkName: name,
        reason: customFailureMessage ?? 'Jailbreak/root detection failed: $e',
        action: FailureAction.forceExit,
      );
    }
  }
}
