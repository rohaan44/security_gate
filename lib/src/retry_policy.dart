/// Configures retry behavior for a [SecurityCheck] that fails.
///
/// When a check's [CheckResult.failureAction] is [FailureAction.retry],
/// the pipeline will re-attempt the check up to [maxAttempts] times,
/// waiting [backoff] × [backoffMultiplier]^attempt between each retry.
class RetryPolicy {
  /// Maximum number of retry attempts (excluding the initial attempt).
  ///
  /// For example, `maxAttempts: 3` means the check can run up to 4 times
  /// total (1 initial + 3 retries).
  final int maxAttempts;

  /// Base duration to wait between retry attempts.
  final Duration backoff;

  /// Multiplier applied to [backoff] for each successive retry attempt.
  ///
  /// For example, with `backoff: Duration(seconds: 2)` and
  /// `backoffMultiplier: 1.5`:
  /// - Retry 1 waits 2s
  /// - Retry 2 waits 3s
  /// - Retry 3 waits 4.5s
  final double backoffMultiplier;

  /// Creates a [RetryPolicy].
  const RetryPolicy({
    this.maxAttempts = 3,
    this.backoff = const Duration(seconds: 2),
    this.backoffMultiplier = 1.5,
  }) : assert(maxAttempts > 0, 'maxAttempts must be at least 1'),
       assert(backoffMultiplier >= 1.0, 'backoffMultiplier must be >= 1.0');

  /// Calculates the wait duration for a given [attempt] (0-indexed).
  Duration backoffForAttempt(int attempt) {
    if (attempt <= 0) return backoff;
    double multiplier = 1.0;
    for (int i = 0; i < attempt; i++) {
      multiplier *= backoffMultiplier;
    }
    return Duration(
      milliseconds: (backoff.inMilliseconds * multiplier).round(),
    );
  }

  @override
  String toString() =>
      'RetryPolicy(maxAttempts: $maxAttempts, backoff: ${backoff.inMilliseconds}ms, '
      'multiplier: $backoffMultiplier)';
}
