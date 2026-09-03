import 'check_result.dart';
import 'failure_action.dart';

/// The aggregate result of running a [SecurityPipeline].
///
/// Contains the pass/fail status, the ordered list of individual
/// [CheckResult]s, and the total time the pipeline took to execute.
class PipelineResult {
  /// Whether all checks in the pipeline passed.
  final bool passed;

  /// Ordered list of results for each check that was executed.
  ///
  /// If the pipeline stopped early due to a failure, this list will
  /// contain results only up to (and including) the failed check.
  final List<CheckResult> results;

  /// Total time the entire pipeline took to execute.
  final Duration totalElapsed;

  /// Creates a [PipelineResult].
  const PipelineResult({
    required this.passed,
    required this.results,
    required this.totalElapsed,
  });

  /// The first check that failed, or `null` if all checks passed.
  CheckResult? get failedCheck {
    for (final result in results) {
      if (!result.passed) return result;
    }
    return null;
  }

  /// Whether any check in the pipeline failed. Shorthand for `!passed`.
  bool get isFailed => !passed;

  /// The failure reason of the first failing check, or `null` if all passed.
  String? get failureReason => failedCheck?.failureReason;

  /// The recommended failure action of the first failing check, or `null` if all passed.
  FailureAction? get failureAction => failedCheck?.failureAction;

  /// The number of checks that were executed.
  int get checksExecuted => results.length;

  /// The number of checks that passed.
  int get checksPassed => results.where((r) => r.passed).length;

  @override
  String toString() {
    if (passed) {
      return 'PipelineResult(PASSED, ${results.length} checks, '
          '${totalElapsed.inMilliseconds}ms)';
    }
    final failed = failedCheck;
    return 'PipelineResult(FAILED at "${failed?.checkName}", '
        '${results.length} checks executed, '
        '${totalElapsed.inMilliseconds}ms)';
  }
}
