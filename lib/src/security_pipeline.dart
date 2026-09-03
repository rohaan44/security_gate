import 'dart:async';

import 'check_result.dart';
import 'failure_action.dart';
import 'pipeline_result.dart';
import 'security_check.dart';
import 'security_logger.dart';

/// Signature for a callback invoked when a check starts executing.
typedef OnCheckStart = void Function(SecurityCheck check);

/// Signature for a callback invoked when a check passes.
typedef OnCheckPassed = void Function(
  SecurityCheck check,
  CheckResult result,
);

/// Signature for a callback invoked when a check fails.
typedef OnCheckFailed = void Function(
  SecurityCheck check,
  CheckResult result,
);

/// Signature for a callback invoked when the entire pipeline completes.
typedef OnPipelineComplete = void Function(PipelineResult result);

/// Runs an ordered sequence of [SecurityCheck]s and reports results.
///
/// The pipeline is **UI-agnostic** — it has no dependency on `Navigator`,
/// `BuildContext`, or any state management library. It communicates
/// results through callbacks and a returned [PipelineResult].
///
/// ## Simple usage
///
/// ```dart
/// final pipeline = SecurityPipeline(
///   checks: [JailbreakRootCheck(), ProxyDetectionCheck()],
/// );
///
/// final result = await pipeline.execute();
/// if (result.passed) {
///   // All checks passed — navigate to home screen
/// } else {
///   // Handle failure — show dialog, etc.
///   print(result.failedCheck?.failureReason);
/// }
/// ```
///
/// ## With callbacks
///
/// ```dart
/// final pipeline = SecurityPipeline(
///   checks: [JailbreakRootCheck(), ProxyDetectionCheck()],
///   onCheckStart: (check) => print('Running: ${check.name}'),
///   onCheckPassed: (check, result) => print('✓ ${check.name}'),
///   onCheckFailed: (check, result) => print('✗ ${check.name}'),
///   onPipelineComplete: (result) {
///     if (result.passed) {
///       // navigate to home
///     } else {
///       // show error dialog
///     }
///   },
/// );
///
/// await pipeline.execute();
/// ```
class SecurityPipeline {
  /// The ordered list of checks to execute.
  final List<SecurityCheck> checks;

  /// Logger used for all pipeline and check log messages.
  final SecurityLogger logger;

  /// Called when a check starts executing (before each attempt).
  final OnCheckStart? onCheckStart;

  /// Called when a check passes.
  final OnCheckPassed? onCheckPassed;

  /// Called when a check fails (after all retry attempts are exhausted).
  final OnCheckFailed? onCheckFailed;

  /// Called when the pipeline finishes (whether all checks passed or one failed).
  final OnPipelineComplete? onPipelineComplete;

  /// Creates a [SecurityPipeline].
  ///
  /// [checks] is the ordered list of security checks to run.
  /// [logger] defaults to [DefaultLogger] if not provided.
  SecurityPipeline({
    required this.checks,
    SecurityLogger? logger,
    this.onCheckStart,
    this.onCheckPassed,
    this.onCheckFailed,
    this.onPipelineComplete,
  }) : logger = logger ?? const DefaultLogger();

  /// Executes all checks sequentially and returns a [PipelineResult].
  ///
  /// The pipeline stops on the first non-retryable failure. If a check has
  /// a [RetryPolicy] and its failure action is [FailureAction.retry], the
  /// pipeline will retry according to the policy before giving up.
  ///
  /// Returns a [PipelineResult] with `passed == true` only if every check
  /// in the list passed.
  Future<PipelineResult> execute() async {
    final pipelineStopwatch = Stopwatch()..start();
    final results = <CheckResult>[];

    logger.log(
      'Starting security pipeline with ${checks.length} check(s).',
      level: LogLevel.info,
    );

    for (final check in checks) {
      final result = await _runCheckWithRetry(check);
      results.add(result);

      if (!result.passed) {
        logger.log(
          'Pipeline stopped: "${check.name}" failed — ${result.failureReason}',
          level: LogLevel.error,
        );
        onCheckFailed?.call(check, result);

        pipelineStopwatch.stop();
        final pipelineResult = PipelineResult(
          passed: false,
          results: List.unmodifiable(results),
          totalElapsed: pipelineStopwatch.elapsed,
        );
        onPipelineComplete?.call(pipelineResult);
        return pipelineResult;
      }

      onCheckPassed?.call(check, result);
    }

    pipelineStopwatch.stop();
    logger.log(
      'All ${checks.length} check(s) passed in '
      '${pipelineStopwatch.elapsedMilliseconds}ms.',
      level: LogLevel.info,
    );

    final pipelineResult = PipelineResult(
      passed: true,
      results: List.unmodifiable(results),
      totalElapsed: pipelineStopwatch.elapsed,
    );
    onPipelineComplete?.call(pipelineResult);
    return pipelineResult;
  }

  /// Runs a single check with timeout handling and optional retry.
  Future<CheckResult> _runCheckWithRetry(SecurityCheck check) async {
    final retryPolicy = check.retryPolicy;
    final maxAttempts = (retryPolicy?.maxAttempts ?? 0) + 1; // +1 for initial

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      if (attempt > 0) {
        final waitDuration = retryPolicy!.backoffForAttempt(attempt - 1);
        logger.log(
          'Retrying "${check.name}" (attempt ${attempt + 1}/$maxAttempts) '
          'after ${waitDuration.inMilliseconds}ms backoff.',
          level: LogLevel.info,
        );
        await Future<void>.delayed(waitDuration);
      }

      onCheckStart?.call(check);
      logger.log(
        'Running "${check.name}"${attempt > 0 ? " (attempt ${attempt + 1})" : ""}...',
        level: LogLevel.debug,
      );

      final result = await _executeWithTimeout(check);

      if (result.passed) {
        logger.log(
          '✓ "${check.name}" passed in ${result.elapsed.inMilliseconds}ms.',
          level: LogLevel.info,
        );
        return result;
      }

      // If this is the last attempt or the failure action is not retry, stop.
      final isLastAttempt = attempt >= maxAttempts - 1;
      final shouldRetry =
          result.failureAction == FailureAction.retry && !isLastAttempt;

      if (!shouldRetry) {
        return result;
      }

      logger.log(
        '✗ "${check.name}" failed (attempt ${attempt + 1}): '
        '${result.failureReason}',
        level: LogLevel.warning,
      );
    }

    // Should not reach here, but just in case:
    return CheckResult.fail(
      checkName: check.name,
      check: check,
      reason: 'Exhausted all retry attempts.',
      action: FailureAction.dialog,
    );
  }

  /// Executes a single check with its configured timeout.
  Future<CheckResult> _executeWithTimeout(SecurityCheck check) async {
    final stopwatch = Stopwatch()..start();
    try {
      final rawResult = await check.execute().timeout(check.timeout);
      stopwatch.stop();

      // Ensure the check instance and elapsed duration are attached.
      return rawResult.copyWith(
        check: rawResult.check ?? check,
        elapsed: rawResult.elapsed == Duration.zero
            ? stopwatch.elapsed
            : rawResult.elapsed,
      );
    } on TimeoutException {
      stopwatch.stop();
      logger.log(
        '⏱ "${check.name}" timed out after ${check.timeout.inSeconds}s.',
        level: LogLevel.error,
      );
      return CheckResult.timeout(
        checkName: check.name,
        check: check,
        timeoutDuration: check.timeout,
      );
    } catch (e, stackTrace) {
      stopwatch.stop();
      logger.log(
        '💥 "${check.name}" threw an exception: $e\n$stackTrace',
        level: LogLevel.error,
      );
      return CheckResult.fail(
        checkName: check.name,
        check: check,
        reason: 'Unhandled exception: $e',
        action: FailureAction.dialog,
        elapsed: stopwatch.elapsed,
      );
    }
  }
}
