import 'check_result.dart';
import 'retry_policy.dart';

/// Abstract interface for a single device-security check.
///
/// Implement this class to create custom security checks. Each check has a
/// [name], an async [execute] method that returns a [CheckResult], a
/// configurable [timeout], and an optional [retryPolicy].
///
/// ```dart
/// class MyCustomCheck extends SecurityCheck {
///   @override
///   String get name => 'My Custom Check';
///
///   @override
///   Future<CheckResult> execute() async {
///     final isSecure = await _performMyCheck();
///     if (isSecure) {
///       return CheckResult.pass(checkName: name);
///     }
///     return CheckResult.fail(
///       checkName: name,
///       reason: 'Device failed custom security check.',
///     );
///   }
/// }
/// ```
abstract class SecurityCheck {
  /// Human-readable name for this check, used in logging and results.
  String get name;

  /// Executes the security check and returns a [CheckResult].
  ///
  /// Implementations should not throw exceptions — instead, catch them
  /// internally and return a [CheckResult.fail]. The pipeline will also
  /// catch unhandled exceptions and wrap them, but explicit handling is
  /// preferred for better error messages.
  Future<CheckResult> execute();

  /// Maximum time allowed for this check to complete.
  ///
  /// If [execute] does not complete within this duration, the pipeline
  /// will produce a [CheckResult.timeout] and move on according to the
  /// failure policy.
  ///
  /// Defaults to 15 seconds. Override to customize per check.
  Duration get timeout => const Duration(seconds: 15);

  /// Optional retry policy for this check.
  ///
  /// If non-null, the pipeline will retry the check on failure (when
  /// the [CheckResult.failureAction] is [FailureAction.retry]) according
  /// to this policy's backoff and max-attempt settings.
  ///
  /// Defaults to `null` (no retries).
  RetryPolicy? get retryPolicy => null;

  @override
  String toString() => 'SecurityCheck($name)';
}
