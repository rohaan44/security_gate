import 'failure_action.dart';
import 'security_check.dart';

/// The result of executing a single [SecurityCheck].
///
/// Carries pass/fail status, an optional human-readable failure reason,
/// the recommended [FailureAction], timing information, and a reference
/// to the [SecurityCheck] instance that generated it.
class CheckResult {
  /// Whether the check passed.
  final bool passed;

  /// Human-readable reason for failure, or `null` if the check passed.
  final String? failureReason;

  /// The action the host app should take if this check failed.
  ///
  /// Ignored when [passed] is `true`.
  final FailureAction failureAction;

  /// The name of the check that produced this result.
  final String checkName;

  /// The [SecurityCheck] instance that produced this result, if available.
  ///
  /// Allows type-safe matching in your UI without relying on string names:
  /// ```dart
  /// switch (failed.check) {
  ///   case BlockedNetworkCheck():
  ///     _showVpnModal();
  ///   case JailbreakRootCheck():
  ///     _showRootModal();
  /// }
  /// ```
  final SecurityCheck? check;

  /// How long the check took to execute.
  final Duration elapsed;

  /// Creates a [CheckResult].
  const CheckResult({
    required this.passed,
    required this.checkName,
    this.check,
    this.failureReason,
    this.failureAction = FailureAction.dialog,
    this.elapsed = Duration.zero,
  });

  /// Creates a passing result.
  factory CheckResult.pass({
    required String checkName,
    SecurityCheck? check,
    Duration elapsed = Duration.zero,
  }) {
    return CheckResult(
      passed: true,
      checkName: checkName,
      check: check,
      elapsed: elapsed,
    );
  }

  /// Creates a failing result with a reason and recommended action.
  factory CheckResult.fail({
    required String checkName,
    required String reason,
    SecurityCheck? check,
    FailureAction action = FailureAction.dialog,
    Duration elapsed = Duration.zero,
  }) {
    return CheckResult(
      passed: false,
      checkName: checkName,
      check: check,
      failureReason: reason,
      failureAction: action,
      elapsed: elapsed,
    );
  }

  /// Creates a timeout failure result.
  factory CheckResult.timeout({
    required String checkName,
    required Duration timeoutDuration,
    SecurityCheck? check,
  }) {
    return CheckResult(
      passed: false,
      checkName: checkName,
      check: check,
      failureReason:
          'Check "$checkName" timed out after ${timeoutDuration.inSeconds}s.',
      failureAction: FailureAction.retry,
      elapsed: timeoutDuration,
    );
  }

  /// Returns `true` if this result was produced by a check of type [T].
  ///
  /// Example:
  /// ```dart
  /// if (result.isA<BlockedNetworkCheck>()) {
  ///   _showVpnModal();
  /// }
  /// ```
  bool isA<T extends SecurityCheck>() => check is T;

  /// Returns the underlying [SecurityCheck] cast to [T], or `null` if the check
  /// is not of type [T].
  T? getCheck<T extends SecurityCheck>() => check is T ? check as T : null;

  /// Returns a copy of this result with the given fields replaced.
  CheckResult copyWith({
    bool? passed,
    String? checkName,
    SecurityCheck? check,
    String? failureReason,
    FailureAction? failureAction,
    Duration? elapsed,
  }) {
    return CheckResult(
      passed: passed ?? this.passed,
      checkName: checkName ?? this.checkName,
      check: check ?? this.check,
      failureReason: failureReason ?? this.failureReason,
      failureAction: failureAction ?? this.failureAction,
      elapsed: elapsed ?? this.elapsed,
    );
  }

  @override
  String toString() {
    if (passed) {
      return 'CheckResult(PASS, check: $checkName, elapsed: ${elapsed.inMilliseconds}ms)';
    }
    return 'CheckResult(FAIL, check: $checkName, reason: $failureReason, '
        'action: ${failureAction.name}, elapsed: ${elapsed.inMilliseconds}ms)';
  }
}
