import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/core/logging/log_level.dart';

void main() {
  group('LogLevel.fromName', () {
    const Map<String, LogLevel> validNames = <String, LogLevel>{
      'debug': LogLevel.debug,
      'info': LogLevel.info,
      'warning': LogLevel.warning,
      'error': LogLevel.error,
    };

    for (final MapEntry<String, LogLevel> entry in validNames.entries) {
      test('parses "${entry.key}" to ${entry.value}', () {
        expect(LogLevel.fromName(entry.key), entry.value);
      });
    }

    test('throws FormatException naming the value for an unknown level', () {
      expect(
        () => LogLevel.fromName('verbose'),
        throwsA(
          isA<FormatException>().having(
            (FormatException e) => e.message,
            'message',
            contains('verbose'),
          ),
        ),
      );
    });

    test('is case-sensitive', () {
      expect(() => LogLevel.fromName('DEBUG'), throwsFormatException);
    });
  });

  group('LogLevel ordering', () {
    test('runs from most verbose (debug) to least verbose (error)', () {
      expect(LogLevel.values, <LogLevel>[
        LogLevel.debug,
        LogLevel.info,
        LogLevel.warning,
        LogLevel.error,
      ]);
    });
  });
}
