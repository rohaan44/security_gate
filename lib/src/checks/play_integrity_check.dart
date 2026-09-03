import 'dart:io';

import '../check_result.dart';
import '../failure_action.dart';
import '../retry_policy.dart';
import '../security_check.dart';

/// Verifies device integrity via Android Play Integrity API.
///
/// This check is **Android-only**. On iOS, it automatically passes since
/// Play Integrity is not applicable.
///
/// ## Native dependency
///
/// Wire this to the Play Integrity API via:
/// - [`play_integrity`](https://pub.dev/packages/play_integrity)
/// - A custom platform channel implementation.
///
/// ## Usage
///
/// ```dart
/// final pipeline = SecurityPipeline(
///   checks: [PlayIntegrityCheck()],
/// );
/// ```
class PlayIntegrityCheck extends SecurityCheck {
  @override
  String get name => 'Play Integrity';

  @override
  Duration get timeout => const Duration(seconds: 20);

  @override
  RetryPolicy? get retryPolicy => const RetryPolicy(
    maxAttempts: 2,
    backoff: Duration(seconds: 3),
  );

  @override
  Future<CheckResult> execute() async {
    // Play Integrity is Android-only; skip on iOS.
    if (Platform.isIOS) {
      return CheckResult.pass(checkName: name);
    }

    try {
      // TODO: wire to play_integrity package or custom platform channel
      // Example integration:
      //   final token = await PlayIntegrity.requestIntegrityToken(
      //     nonce: _generateNonce(),
      //   );
      //   final verdict = await _verifyTokenOnServer(token);
      //   if (!verdict.meetsDeviceIntegrity) {
      //     return CheckResult.fail(
      //       checkName: name,
      //       reason: 'Device failed Play Integrity verification.',
      //       action: FailureAction.forceExit,
      //     );
      //   }

      // Stub: always passes until wired to a real integration.
      return CheckResult.pass(checkName: name);
    } catch (e) {
      return CheckResult.fail(
        checkName: name,
        reason: 'Play Integrity check failed: $e',
        action: FailureAction.retry,
      );
    }
  }
}
