/// Application-wide logging contract (CLAUDE.md §4.3).
///
/// Every file logs through an injected [AppLogger]; `print()` and
/// `debugPrint()` are forbidden. Pure Dart with no imports, so any layer may
/// depend on it and tests mock it with mocktail.
///
/// Levels:
/// - [debug]: development diagnostics.
/// - [info]: lifecycle events (app start, navigation, bloc transitions).
/// - [warning]: recoverable problems (cache fallback, retry).
/// - [error]: failures, with [error] and [stackTrace] whenever available.
///
/// Messages must never contain secrets, API keys or full response bodies.
abstract interface class AppLogger {
  /// Development diagnostics.
  void debug(String message, {Object? error, StackTrace? stackTrace});

  /// Lifecycle events.
  void info(String message, {Object? error, StackTrace? stackTrace});

  /// Recoverable problems.
  void warning(String message, {Object? error, StackTrace? stackTrace});

  /// Failures. Pass the caught [error] and [stackTrace] whenever available.
  void error(String message, {Object? error, StackTrace? stackTrace});
}
