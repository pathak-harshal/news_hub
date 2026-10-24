import 'package:logger/logger.dart';
import 'package:news_hub/core/logging/app_logger.dart';
import 'package:news_hub/core/logging/log_level.dart';

/// [AppLogger] backed by the `logger` package.
///
/// Registered in Step 12 as `AppLoggerImpl(minLevel: config.logLevel)`.
/// [output] and [printer] exist so tests can capture events in memory; app
/// code leaves them null and gets the console with a quiet pretty printer.
///
/// Uses `ProductionFilter`, so [minLevel] is applied the same way in every
/// build mode. Release-build logging policy is revisited with D7.
final class AppLoggerImpl implements AppLogger {
  AppLoggerImpl({
    required LogLevel minLevel,
    LogOutput? output,
    LogPrinter? printer,
  }) : _logger = Logger(
         filter: ProductionFilter(),
         level: _toLoggerLevel(minLevel),
         printer: printer ?? _defaultPrinter(),
         output: output ?? ConsoleOutput(),
       );

  final Logger _logger;

  @override
  void debug(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.d(message, error: error, stackTrace: stackTrace);
  }

  @override
  void info(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.i(message, error: error, stackTrace: stackTrace);
  }

  @override
  void warning(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.w(message, error: error, stackTrace: stackTrace);
  }

  @override
  void error(String message, {Object? error, StackTrace? stackTrace}) {
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// The only place our [LogLevel] meets the package's `Level`.
  static Level _toLoggerLevel(LogLevel level) => switch (level) {
    LogLevel.debug => Level.debug,
    LogLevel.info => Level.info,
    LogLevel.warning => Level.warning,
    LogLevel.error => Level.error,
  };

  /// No call stack on ordinary lines, 8 frames for errors, no emojis, and
  /// no timestamps.
  static LogPrinter _defaultPrinter() => PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 8,
    printEmojis: false,
    dateTimeFormat: DateTimeFormat.none,
  );
}
