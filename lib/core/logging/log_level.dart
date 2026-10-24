/// App-level log severity, read from `LOG_LEVEL` in `env/<flavor>.json`.
///
/// This is our own enum so that config code never imports the `logger`
/// package. `AppLoggerImpl` (Step 6) maps it to `logger`'s levels.
///
/// Ordered from most verbose to least verbose: a configured level shows
/// that level and everything after it.
enum LogLevel {
  debug,
  info,
  warning,
  error;

  /// Parses the `LOG_LEVEL` value from `env/<flavor>.json`.
  ///
  /// Throws a [FormatException] naming [name] if it is not a known level.
  static LogLevel fromName(String name) {
    final LogLevel? level = LogLevel.values.asNameMap()[name];
    if (level == null) {
      final String allowed = LogLevel.values
          .map((LogLevel l) => l.name)
          .join(', ');
      throw FormatException(
        'Unknown LOG_LEVEL "$name". Expected one of: $allowed.',
      );
    }
    return level;
  }
}
