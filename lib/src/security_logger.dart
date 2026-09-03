/// Log severity levels used by [SecurityLogger].
enum LogLevel {
  /// Verbose diagnostic information for debugging.
  debug,

  /// General informational messages about pipeline progress.
  info,

  /// Potential issues that don't prevent execution but should be noted.
  warning,

  /// Errors that affect check results or pipeline execution.
  error,
}

/// Abstract interface for logging within the security pipeline.
///
/// Implement this class to wire pipeline logging into your app's logging
/// infrastructure (e.g. `package:logging`, Firebase Crashlytics, etc.).
///
/// ```dart
/// class MyAppLogger implements SecurityLogger {
///   @override
///   void log(String message, {LogLevel level = LogLevel.info}) {
///     myLogger.log(message, severity: level.name);
///   }
/// }
/// ```
abstract class SecurityLogger {
  /// Logs a [message] at the given [level].
  void log(String message, {LogLevel level = LogLevel.info});
}

/// Default logger that writes to `print()`.
///
/// Used when no custom [SecurityLogger] is provided to the pipeline.
class DefaultLogger implements SecurityLogger {
  /// Creates a [DefaultLogger].
  const DefaultLogger();

  @override
  void log(String message, {LogLevel level = LogLevel.info}) {
    print('[SecurityGate/${level.name.toUpperCase()}] $message');
  }
}
