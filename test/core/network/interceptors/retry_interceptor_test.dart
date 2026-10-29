import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/error/exceptions.dart';
import 'package:news_hub/core/network/interceptors/error_interceptor.dart';
import 'package:news_hub/core/network/interceptors/retry_interceptor.dart';

import '../../../helpers/fake_http_client_adapter.dart';
import '../../../helpers/mocks.dart';

const String _path = '/top-headlines';

const Duration _timeout = Duration(seconds: 1);

FakeResponder _ok() => jsonResponse(200, <String, Object?>{'status': 'ok'});

FakeResponder _status(int statusCode) =>
    jsonResponse(statusCode, <String, Object?>{
      'status': 'error',
      'code': 'test',
      'message': 'HTTP $statusCode',
    });

FakeResponder _connectionError() => throwing(
  (RequestOptions o) =>
      DioException.connectionError(requestOptions: o, reason: 'refused'),
);

/// Retryable transport failures, by name.
final Map<String, FakeResponder Function()> _retryableErrors =
    <String, FakeResponder Function()>{
      'connectionTimeout': () => throwing(
        (RequestOptions o) => DioException.connectionTimeout(
          timeout: _timeout,
          requestOptions: o,
        ),
      ),
      'sendTimeout': () => throwing(
        (RequestOptions o) =>
            DioException.sendTimeout(timeout: _timeout, requestOptions: o),
      ),
      'receiveTimeout': () => throwing(
        (RequestOptions o) =>
            DioException.receiveTimeout(timeout: _timeout, requestOptions: o),
      ),
      'connectionError': _connectionError,
    };

/// Failures that must never be retried, by name.
final Map<String, FakeResponder Function()> _nonRetryableErrors =
    <String, FakeResponder Function()>{
      'cancel': () => throwing(
        (RequestOptions o) =>
            DioException.requestCancelled(requestOptions: o, reason: 'user'),
      ),
      'badCertificate': () => throwing(
        (RequestOptions o) => DioException.badCertificate(requestOptions: o),
      ),
      'transformTimeout': () => throwing(
        (RequestOptions o) =>
            DioException.transformTimeout(timeout: _timeout, requestOptions: o),
      ),
      'unknown': () => throwing((RequestOptions o) => StateError('boom')),
    };

/// Runs [request] and returns the [DioException] it fails with.
Future<DioException> _captureDioException(
  Future<Object?> Function() request,
) async {
  try {
    await request();
  } on DioException catch (e) {
    return e;
  }
  fail('Expected the request to throw a DioException');
}

void main() {
  late MockAppLogger logger;
  late List<Duration> delays;
  late FakeHttpClientAdapter adapter;

  /// A real [Dio] with [RetryInterceptor] (and optionally [ErrorInterceptor]
  /// last, as in production) over a scripted transport.
  Dio buildDio(
    List<FakeResponder> responders, {
    int maxRetries = 2,
    bool withErrorInterceptor = false,
  }) {
    adapter = FakeHttpClientAdapter(responders);
    final Dio dio = Dio(BaseOptions(baseUrl: 'https://newsapi.test/v2'))
      ..httpClientAdapter = adapter;
    dio.interceptors.add(
      RetryInterceptor(
        dio: dio,
        logger: logger,
        maxRetries: maxRetries,
        delay: (Duration duration) async => delays.add(duration),
      ),
    );
    if (withErrorInterceptor) {
      dio.interceptors.add(ErrorInterceptor());
    }
    return dio;
  }

  setUp(() {
    logger = MockAppLogger();
    delays = <Duration>[];
  });

  group('RetryInterceptor', () {
    test('retries a GET after a connection error and returns the '
        'response', () async {
      final Dio dio = buildDio(<FakeResponder>[_connectionError(), _ok()]);

      final Response<Object?> response = await dio.get<Object?>(_path);

      expect(response.statusCode, 200);
      expect(adapter.requests, hasLength(2));
    });

    test('retries a HEAD request', () async {
      final Dio dio = buildDio(<FakeResponder>[_connectionError(), _ok()]);

      await dio.head<Object?>(_path);

      expect(adapter.requests, hasLength(2));
    });

    test('waits 500 ms, then 1 s, between attempts', () async {
      final Dio dio = buildDio(<FakeResponder>[
        _status(503),
        _status(503),
        _ok(),
      ]);

      await dio.get<Object?>(_path);

      expect(adapter.requests, hasLength(3));
      expect(delays, const <Duration>[
        Duration(milliseconds: 500),
        Duration(seconds: 1),
      ]);
    });

    test('gives up after maxRetries retries and passes on the last '
        'error', () async {
      final Dio dio = buildDio(<FakeResponder>[_status(503)]);

      final DioException e = await _captureDioException(
        () => dio.get<Object?>(_path),
      );

      expect(e.type, DioExceptionType.badResponse);
      expect(e.response?.statusCode, 503);
      expect(adapter.requests, hasLength(3));
      expect(delays, hasLength(2));
    });

    test('retries 500, 502, 503 and 504', () async {
      for (final int statusCode in <int>[500, 502, 503, 504]) {
        final Dio dio = buildDio(<FakeResponder>[_status(statusCode), _ok()]);

        await dio.get<Object?>(_path);

        expect(adapter.requests, hasLength(2), reason: 'status $statusCode');
      }
    });

    test('retries timeouts and connection errors', () async {
      for (final MapEntry<String, FakeResponder Function()> c
          in _retryableErrors.entries) {
        final Dio dio = buildDio(<FakeResponder>[c.value(), _ok()]);

        await dio.get<Object?>(_path);

        expect(adapter.requests, hasLength(2), reason: c.key);
      }
    });

    test('does not retry 400, 401, 404, 429 or 501', () async {
      for (final int statusCode in <int>[400, 401, 404, 429, 501]) {
        final Dio dio = buildDio(<FakeResponder>[_status(statusCode), _ok()]);

        await _captureDioException(() => dio.get<Object?>(_path));

        expect(adapter.requests, hasLength(1), reason: 'status $statusCode');
      }
      expect(delays, isEmpty);
    });

    test('does not retry cancel, badCertificate, transformTimeout or '
        'unknown errors', () async {
      for (final MapEntry<String, FakeResponder Function()> c
          in _nonRetryableErrors.entries) {
        final Dio dio = buildDio(<FakeResponder>[c.value(), _ok()]);

        await _captureDioException(() => dio.get<Object?>(_path));

        expect(adapter.requests, hasLength(1), reason: c.key);
      }
      expect(delays, isEmpty);
    });

    test('does not retry a POST', () async {
      final Dio dio = buildDio(<FakeResponder>[_connectionError(), _ok()]);

      await _captureDioException(() => dio.post<Object?>(_path));

      expect(adapter.requests, hasLength(1));
    });

    test('maxRetries 0 disables retrying', () async {
      final Dio dio = buildDio(<FakeResponder>[
        _connectionError(),
        _ok(),
      ], maxRetries: 0);

      await _captureDioException(() => dio.get<Object?>(_path));

      expect(adapter.requests, hasLength(1));
      expect(delays, isEmpty);
    });

    test('gives each request its own retry budget', () async {
      final Dio dio = buildDio(<FakeResponder>[
        _status(503),
        _ok(),
        _status(503),
        _ok(),
      ]);

      await dio.get<Object?>(_path);
      await dio.get<Object?>(_path);

      expect(adapter.requests, hasLength(4));
      expect(delays, const <Duration>[
        Duration(milliseconds: 500),
        Duration(milliseconds: 500),
      ]);
    });

    test('logs one warning per retry, without header values', () async {
      final Dio dio = buildDio(<FakeResponder>[
        _status(503),
        _status(503),
        _ok(),
      ]);

      await dio.get<Object?>(
        _path,
        options: Options(headers: <String, Object?>{'X-Api-Key': 'secret-key'}),
      );

      final List<Object?> messages = verify(() => logger.warning(captureAny()))
          .captured;
      expect(messages, hasLength(2));
      for (final Object? message in messages) {
        expect(message, isA<String>());
        expect(message, contains('GET'));
        expect(message, contains(_path));
        expect(message, isNot(contains('secret-key')));
      }
    });

    test('does not log when nothing is retried', () async {
      final Dio dio = buildDio(<FakeResponder>[_status(400)]);

      await _captureDioException(() => dio.get<Object?>(_path));

      verifyNever(() => logger.warning(any()));
    });

    test('with ErrorInterceptor last, a persistent 503 ends as one '
        'ServerException', () async {
      final Dio dio = buildDio(<FakeResponder>[
        _status(503),
      ], withErrorInterceptor: true);

      final DioException e = await _captureDioException(
        () => dio.get<Object?>(_path),
      );

      expect(adapter.requests, hasLength(3));
      expect(
        e.error,
        isA<ServerException>().having(
          (ServerException s) => s.statusCode,
          'statusCode',
          503,
        ),
      );
    });
  });
}
