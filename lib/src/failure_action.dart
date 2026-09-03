/// Defines the action the host app should take when a security check fails.
///
/// The pipeline itself never acts on these — it reports the requested action
/// via [CheckResult] and lets the host app decide what to do.
enum FailureAction {
  /// Silently log the failure; do not interrupt the user.
  silent,

  /// Suggest showing a dialog or alert to the user.
  dialog,

  /// Suggest forcefully closing the app.
  ///
  /// The pipeline will **never** call `exit()` itself. The host app must
  /// decide how to handle this on iOS (where `exit(0)` is an App Store
  /// rejection risk) vs Android.
  forceExit,

  /// Indicate that the check should be retried according to its [RetryPolicy].
  ///
  /// If no [RetryPolicy] is configured on the check, this behaves like
  /// [dialog].
  retry,
}
