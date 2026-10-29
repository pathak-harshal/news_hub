import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/config/app_config.dart';
import 'package:news_hub/core/config/app_constants.dart';
import 'package:news_hub/core/config/flavor.dart';
import 'package:news_hub/core/error/exceptions.dart';
import 'package:news_hub/core/logging/log_level.dart';
import 'package:news_hub/core/network/cache/http_cache_config.dart';
import 'package:news_hub/core/network/dio_client.dart';
import 'package:news_hub/core/network/interceptors/api_key_interceptor.dart';
import 'package:news_hub/core/network/interceptors/error_interceptor.dart';
import 'package:news_hub/core/network/interceptors/logging_interceptor.dart';
import 'package:news_hub/core/network/interceptors/retry_interceptor.dart';

import '../../helpers/fake_http_client_adapter.dart';
import '../../helpers/mocks.dart';

const String _baseUrl = 'https://newsapi.test/v2';
const String _apiKey = 'test-api-key';
const String _path = '/top-headlines';

/// Our interceptors, in the order they must run. Dio's own built-in
/// interceptors are ignored by the order tests.
const List<Type> _ourInterceptorTypes = <Type>[
  ApiKeyInterceptor,
  DioCacheInterceptor,
  RetryInterceptor,
  LoggingInterceptor,
  ErrorInterceptor,
];

AppConfig _config({required bool enableHttpLogging}) => AppConfig(
  flavor: Flavor.dev,
  apiBaseUrl: Uri.parse(_baseUrl),
  apiKey: _apiKey,
  enableHttpLogging: enableHttpLogging,
  logLevel: LogLevel.debug,
);

FakeResponder _ok() => jsonResponse(200, <String, Object?>{'status': 'ok'});

FakeResponder _status(int statusCode, String code) =>
    jsonResponse(statusCode, <String, Object?>{
      'status': 'error',
      'code': code,
      'message': 'HTTP $statusCode',
    });

List<Type> _ourInterceptorsInOrder(Dio dio) => dio.interceptors
    .map((Interceptor interceptor) => interceptor.runtimeType)
    .where(_ourInterceptorTypes.contains)
    .toList();

void main() {
  late MockAppLogger logger;
  late List<Duration> delays;
  late FakeHttpClientAdapter adapter;

  /// Builds the client exactly as production does (fresh in-memory cache
  /// per test), then swaps in a scripted transport.
  Dio buildClient(
    List<FakeResponder> responders, {
    bool enableHttpLogging = true,
  }) {
    final Dio dio = createDioClient(
      config: _config(enableHttpLogging: enableHttpLogging),
      logger: logger,
      cacheOptions: createHttpCacheOptions(),
      retryDelay: (Duration duration) async => delays.add(duration),
    );
    adapter = FakeHttpClientAdapter(responders);
    dio.httpClientAdapter = adapter;
    return dio;
  }

  setUp(() {
    logger = MockAppLogger();
    delays = <Duration>[];
  });

  group('createDioClient', () {
    group('base options', () {
      test('uses the configured base URL', () {
        final Dio dio = buildClient(<FakeResponder>[_ok()]);

        expect(dio.options.baseUrl, _baseUrl);
      });

      test('uses the AppConstants timeouts', () {
        final Dio dio = buildClient(<FakeResponder>[_ok()]);

        expect(dio.options.connectTimeout, AppConstants.connectTimeout);
        expect(dio.options.sendTimeout, AppConstants.sendTimeout);
        expect(dio.options.receiveTimeout, AppConstants.receiveTimeout);
      });

      test('decodes error bodies (receiveDataWhenStatusError)', () {
        final Dio dio = buildClient(<FakeResponder>[_ok()]);

        expect(dio.options.receiveDataWhenStatusError, isTrue);
      });
    });

    group('interceptor order', () {
      test('ApiKey → Cache → Retry → Logging → Error when logging is on', () {
        final Dio dio = buildClient(<FakeResponder>[_ok()]);

        expect(_ourInterceptorsInOrder(dio), _ourInterceptorTypes);
      });

      test('leaves out Logging when logging is off', () {
        final Dio dio = buildClient(<FakeResponder>[
          _ok(),
        ], enableHttpLogging: false);

        expect(_ourInterceptorsInOrder(dio), <Type>[
          ApiKeyInterceptor,
          DioCacheInterceptor,
          RetryInterceptor,
          ErrorInterceptor,
        ]);
      });
    });

    group('end to end', () {
      test('sends the configured API key in the X-Api-Key header', () async {
        final Dio dio = buildClient(<FakeResponder>[_ok()]);

        await dio.get<Object?>(_path);

        expect(adapter.requests.single.headers['X-Api-Key'], _apiKey);
      });

      test('serves a repeated GET from the cache', () async {
        final Dio dio = buildClient(<FakeResponder>[_ok()]);

        await dio.get<Object?>(_path);
        final Response<Object?> second = await dio.get<Object?>(_path);

        expect(adapter.requests, hasLength(1));
        expect(second.data, <String, Object?>{'status': 'ok'});
      });

      test('asks the network again for a different query', () async {
        final Dio dio = buildClient(<FakeResponder>[_ok()]);

        await dio.get<Object?>(
          _path,
          queryParameters: <String, Object?>{'page': 1},
        );
        await dio.get<Object?>(
          _path,
          queryParameters: <String, Object?>{'page': 2},
        );

        expect(adapter.requests, hasLength(2));
      });

      test('retries a 503 and returns the later success', () async {
        final Dio dio = buildClient(<FakeResponder>[
          _status(503, 'unexpectedError'),
          _ok(),
        ]);

        final Response<Object?> response = await dio.get<Object?>(_path);

        expect(response.statusCode, 200);
        expect(adapter.requests, hasLength(2));
        expect(delays, const <Duration>[Duration(milliseconds: 500)]);
      });

      test('does not cache a failed request', () async {
        final Dio dio = buildClient(<FakeResponder>[
          _status(503, 'unexpectedError'),
          _status(503, 'unexpectedError'),
          _status(503, 'unexpectedError'),
          _ok(),
        ]);

        await expectLater(
          dio.get<Object?>(_path),
          throwsA(isA<DioException>()),
        );
        final Response<Object?> response = await dio.get<Object?>(_path);

        expect(response.statusCode, 200);
        expect(adapter.requests, hasLength(4));
      });

      test('a 401 reaches the caller as UnauthorizedException via '
          'guardApiCall', () async {
        final Dio dio = buildClient(<FakeResponder>[
          _status(401, 'apiKeyInvalid'),
        ]);

        await expectLater(
          guardApiCall<Response<Object?>>(() => dio.get<Object?>(_path)),
          throwsA(
            isA<UnauthorizedException>().having(
              (UnauthorizedException e) => e.code,
              'code',
              'apiKeyInvalid',
            ),
          ),
        );
      });
    });

    group('logging', () {
      test('logs requests when logging is on', () async {
        final Dio dio = buildClient(<FakeResponder>[_ok()]);

        await dio.get<Object?>(_path);

        verify(() => logger.debug(any())).called(greaterThan(0));
      });

      test('logs nothing at debug when logging is off', () async {
        final Dio dio = buildClient(<FakeResponder>[
          _ok(),
        ], enableHttpLogging: false);

        await dio.get<Object?>(_path);

        verifyNever(() => logger.debug(any()));
      });
    });
  });
}
