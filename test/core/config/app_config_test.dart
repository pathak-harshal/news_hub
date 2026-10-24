import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/core/config/app_config.dart';
import 'package:news_hub/core/config/flavor.dart';
import 'package:news_hub/core/logging/log_level.dart';

/// A complete, valid set of environment values, as in `env/dev.json`.
/// Returns a fresh copy so each test can modify it safely.
Map<String, String> validValues() => <String, String>{
  'FLAVOR': 'dev',
  'API_BASE_URL': 'https://newsapi.org/v2',
  'API_KEY': 'test-key-123',
  'ENABLE_HTTP_LOGGING': 'true',
  'LOG_LEVEL': 'debug',
};

/// Matches a [FormatException] whose message contains [text].
Matcher throwsFormatExceptionContaining(String text) => throwsA(
  isA<FormatException>().having(
    (FormatException e) => e.message,
    'message',
    contains(text),
  ),
);

void main() {
  group('AppConfig.fromMap', () {
    // 1
    test('parses a complete, valid map', () {
      final AppConfig config = AppConfig.fromMap(validValues());

      expect(
        config,
        AppConfig(
          flavor: Flavor.dev,
          apiBaseUrl: Uri.parse('https://newsapi.org/v2'),
          apiKey: 'test-key-123',
          enableHttpLogging: true,
          logLevel: LogLevel.debug,
        ),
      );
    });

    // 2
    test('applies defaults when optional keys are missing', () {
      final Map<String, String> values = validValues()
        ..remove('ENABLE_HTTP_LOGGING')
        ..remove('LOG_LEVEL');

      final AppConfig config = AppConfig.fromMap(values);

      expect(config.enableHttpLogging, isFalse);
      expect(config.logLevel, LogLevel.info);
    });

    // 3
    for (final String key in <String>['FLAVOR', 'API_BASE_URL', 'API_KEY']) {
      test('throws FormatException naming $key when it is missing', () {
        final Map<String, String> values = validValues()..remove(key);

        expect(
          () => AppConfig.fromMap(values),
          throwsFormatExceptionContaining(key),
        );
      });
    }

    // 4
    for (final String blank in <String>['', '   ']) {
      test('throws FormatException when API_KEY is blank ("$blank")', () {
        final Map<String, String> values = validValues()..['API_KEY'] = blank;

        expect(
          () => AppConfig.fromMap(values),
          throwsFormatExceptionContaining('API_KEY'),
        );
      });
    }

    // 5
    test('throws FormatException pointing to env/dev.json when API_KEY is '
        'still the example placeholder', () {
      final Map<String, String> values = validValues()
        ..['API_KEY'] = 'YOUR_NEWSAPI_KEY';

      expect(
        () => AppConfig.fromMap(values),
        throwsFormatExceptionContaining('env/dev.json'),
      );
    });

    // 6
    for (final String badUrl in <String>[
      'newsapi.org/v2',
      'http://newsapi.org/v2',
      'not a url',
    ]) {
      test('throws FormatException for API_BASE_URL "$badUrl"', () {
        final Map<String, String> values = validValues()
          ..['API_BASE_URL'] = badUrl;

        expect(
          () => AppConfig.fromMap(values),
          throwsFormatExceptionContaining('API_BASE_URL'),
        );
      });
    }

    // 7
    test('parses ENABLE_HTTP_LOGGING "false"', () {
      final Map<String, String> values = validValues()
        ..['ENABLE_HTTP_LOGGING'] = 'false';

      expect(AppConfig.fromMap(values).enableHttpLogging, isFalse);
    });

    test('throws FormatException for ENABLE_HTTP_LOGGING other than '
        'true/false', () {
      final Map<String, String> values = validValues()
        ..['ENABLE_HTTP_LOGGING'] = 'yes';

      expect(
        () => AppConfig.fromMap(values),
        throwsFormatExceptionContaining('ENABLE_HTTP_LOGGING'),
      );
    });

    // 8
    test('throws FormatException for an unknown LOG_LEVEL', () {
      final Map<String, String> values = validValues()
        ..['LOG_LEVEL'] = 'verbose';

      expect(
        () => AppConfig.fromMap(values),
        throwsFormatExceptionContaining('LOG_LEVEL'),
      );
    });
  });

  group('AppConfig.toString', () {
    // 9
    test('never contains the API key', () {
      final AppConfig config = AppConfig.fromMap(validValues());

      expect(config.toString(), isNot(contains('test-key-123')));
    });

    group('AppConfig.fromEnvironment', () {
      // 10
      test(
        'fails fast naming FLAVOR when run without --dart-define-from-file',
        () {
          expect(
            AppConfig.fromEnvironment,
            throwsFormatExceptionContaining('FLAVOR'),
          );
        },
        skip: const bool.hasEnvironment('FLAVOR')
            ? 'Tests were run with --dart-define-from-file, so values exist.'
            : false,
      );
    });
  });
}
