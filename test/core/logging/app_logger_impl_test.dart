import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:news_hub/core/logging/app_logger.dart';
import 'package:news_hub/core/logging/app_logger_impl.dart';
import 'package:news_hub/core/logging/log_level.dart';

/// Minimal printer so tests never depend on the package's formatting.
/// It returns one line because `Logger` only forwards events to the output
/// when the printer produced at least one line.
final class _LinePrinter extends LogPrinter {
  @override
  List<String> log(LogEvent event) => <String>['line'];
}

typedef _Harness = ({AppLogger logger, MemoryOutput output});

/// Builds a logger whose events are captured in memory, never printed.
_Harness _build(LogLevel minLevel) {
  final MemoryOutput output = MemoryOutput();
  final AppLogger logger = AppLoggerImpl(
    minLevel: minLevel,
    output: output,
    printer: _LinePrinter(),
  );
  return (logger: logger, output: output);
}

/// Calls the [AppLogger] method that matches [level].
void _emit(
  AppLogger logger,
  LogLevel level,
  String message, {
  Object? error,
  StackTrace? stackTrace,
}) {
  switch (level) {
    case LogLevel.debug:
      logger.debug(message, error: error, stackTrace: stackTrace);
    case LogLevel.info:
      logger.info(message, error: error, stackTrace: stackTrace);
    case LogLevel.warning:
      logger.warning(message, error: error, stackTrace: stackTrace);
    case LogLevel.error:
      logger.error(message, error: error, stackTrace: stackTrace);
  }
}

/// The `logger` package level each of our levels must map to.
Level _expectedLevel(LogLevel level) => switch (level) {
  LogLevel.debug => Level.debug,
  LogLevel.info => Level.info,
  LogLevel.warning => Level.warning,
  LogLevel.error => Level.error,
};

void main() {
  group('AppLoggerImpl methods', () {
    for (final LogLevel level in LogLevel.values) {
      test('${level.name}() emits one event at the matching Level, keeping '
          'message, error and stackTrace', () {
        final _Harness harness = _build(LogLevel.debug);
        final StateError error = StateError('boom');
        final StackTrace stackTrace = StackTrace.fromString('test-trace');

        _emit(
          harness.logger,
          level,
          'hello',
          error: error,
          stackTrace: stackTrace,
        );

        expect(harness.output.buffer, hasLength(1));
        final LogEvent event = harness.output.buffer.single.origin;
        expect(event.level, equals(_expectedLevel(level)));
        expect(event.message, equals('hello'));
        expect(event.error, same(error));
        expect(event.stackTrace, same(stackTrace));
      });
    }

    test('error and stackTrace default to null', () {
      final _Harness harness = _build(LogLevel.debug);

      harness.logger.info('hello');

      final LogEvent event = harness.output.buffer.single.origin;
      expect(event.error, isNull);
      expect(event.stackTrace, isNull);
    });
  });

  group('defaults', () {
    test('builds with the default printer and console output', () {
      // Exercises the production wiring (PrettyPrinter + ConsoleOutput)
      // without logging anything, so nothing is printed.
      AppLogger build() => AppLoggerImpl(minLevel: LogLevel.error);

      expect(build, returnsNormally);
      expect(build(), isA<AppLogger>());
    });
  });

  group('minLevel filtering', () {
    for (final LogLevel minLevel in LogLevel.values) {
      test('minLevel ${minLevel.name} emits only levels at or above it', () {
        final _Harness harness = _build(minLevel);

        for (final LogLevel level in LogLevel.values) {
          _emit(harness.logger, level, level.name);
        }

        final List<Level> emitted = harness.output.buffer
            .map((OutputEvent event) => event.level)
            .toList();
        final List<Level> expected = LogLevel.values
            .where((LogLevel level) => level.index >= minLevel.index)
            .map(_expectedLevel)
            .toList();

        expect(emitted, equals(expected));
      });
    }
  });
}
