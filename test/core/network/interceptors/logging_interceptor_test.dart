import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/error/exceptions.dart';
import 'package:news_hub/core/network/interceptors/error_interceptor.dart';
import 'package:news_hub/core/network/interceptors/logging_interceptor.dart';
import 'package:news_hub/core/network/interceptors/retry_interceptor.dart';

import '../../../helpers/fake_http_client_adapter.dart';
import '../../../helpers/mocks.dart';

const String _baseUrl = 'https://newsapi.test/v2';
const String _path = '/top-headlines';

FakeResponder _ok() => jsonResponse(200, <String, Object?>{'status': 'ok'});

FakeResponder _status(int statusCode) =>
    jsonResponse(statusCode, <String, Object?>{
      'status': 'error',
      'code': 'test',
      'message': 'HTTP $statusCode',
    });

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
  late FakeHttpClientAdapter adapter;
  late DateTime current;

  /// A real [Dio] with [LoggingInterceptor] over a scripted transport.
  /// With [withRetryAndError], the production order around it is used:
  /// Retry → Logging → Error.
  Dio buildDio(
    List<FakeResponder> responders, {
    bool withRetryAndError = false,
  }) {
    adapter = FakeHttpClientAdapter(responders);
    final Dio dio = Dio(BaseOptions(baseUrl: _baseUrl))
      ..httpClientAdapter = adapter;
    if (withRetryAndError) {
      dio.interceptors.add(
        RetryInterceptor(dio: dio, logger: logger, delay: (_) async {}),
      );
    }
    dio.interceptors.add(
      LoggingInterceptor(logger: logger, now: () => current),
    );
    if (withRetryAndError) {
      dio.interceptors.add(ErrorInterceptor());
    }
    return dio;
  }

  /// Every message passed to `logger.debug`, in order.
  List<String> debugMessages() =>
      verify(() => logger.debug(captureAny())).captured.cast<String>();

  /// Every message passed to `logger.warning`, in order.
  List<String> warningMessages() =>
      verify(() => logger.warning(captureAny())).captured.cast<String>();

  setUp(() {
    logger = MockAppLogger();
    current = DateTime(2026, 10, 25, 9);
  });

  group('LoggingInterceptor', () {
    group('requests', () {
      test('logs method and full URL, including the query, at debug', () async {
        final Dio dio = buildDio(<FakeResponder>[_ok()]);

        await dio.get<Object?>(
          _path,
          queryParameters: <String, Object?>{'country': 'us'},
        );

        expect(
          debugMessages().where((String m) => m.startsWith('→ ')),
          <Matcher>[startsWith('→ GET $_baseUrl$_path?country=us')],
        );
      });

      test('redacts X-Api-Key in any letter case', () async {
        for (final String name in <String>['X-Api-Key', 'x-api-key']) {
          logger = MockAppLogger();
          final Dio dio = buildDio(<FakeResponder>[_ok()]);

          await dio.get<Object?>(
            _path,
            options: Options(headers: <String, Object?>{name: 'secret-key'}),
          );

          final String requestLine = debugMessages().firstWhere(
            (String m) => m.startsWith('→ '),
          );
          expect(requestLine, contains('***'), reason: name);
          expect(requestLine, isNot(contains('secret-key')), reason: name);
        }
      });

      test('redacts Authorization, Cookie and Set-Cookie but keeps other '
          'headers', () async {
        final Dio dio = buildDio(<FakeResponder>[_ok()]);

        await dio.get<Object?>(
          _path,
          options: Options(
            headers: <String, Object?>{
              'Authorization': 'Bearer token-1',
              'Cookie': 'session=abc',
              'Set-Cookie': 'id=xyz',
              'Accept': 'application/json',
            },
          ),
        );

        final String requestLine = debugMessages().firstWhere(
          (String m) => m.startsWith('→ '),
        );
        expect(requestLine, isNot(contains('token-1')));
        expect(requestLine, isNot(contains('session=abc')));
        expect(requestLine, isNot(contains('id=xyz')));
        expect(requestLine, contains('application/json'));
      });

      test('redacts a copy: the real request still carries the key', () async {
        final Dio dio = buildDio(<FakeResponder>[_ok()]);

        await dio.get<Object?>(
          _path,
          options: Options(
            headers: <String, Object?>{'X-Api-Key': 'secret-key'},
          ),
        );

        expect(adapter.requests.single.headers['X-Api-Key'], 'secret-key');
      });

      test('logs a request that has no custom headers', () async {
        final Dio dio = buildDio(<FakeResponder>[_ok()]);

        await dio.get<Object?>(_path);

        expect(
          debugMessages().where((String m) => m.startsWith('→ GET ')),
          hasLength(1),
        );
      });
    });

    group('responses', () {
      test('logs status, method, path and time taken at debug', () async {
        final FakeResponder slowOk = _ok();
        final Dio dio = buildDio(<FakeResponder>[
          (RequestOptions o) {
            current = current.add(const Duration(milliseconds: 120));
            return slowOk(o);
          },
        ]);

        await dio.get<Object?>(_path);

        final String responseLine = debugMessages().firstWhere(
          (String m) => m.startsWith('← '),
        );
        expect(responseLine, startsWith('← 200 GET $_path'));
        expect(responseLine, contains('120 ms'));
      });

      test('never logs the response body', () async {
        final Dio dio = buildDio(<FakeResponder>[
          jsonResponse(200, <String, Object?>{'secret': 'secret-body'}),
        ]);

        await dio.get<Object?>(_path);

        expect(debugMessages(), everyElement(isNot(contains('secret-body'))));
        verifyNever(() => logger.warning(any()));
      });
    });

    group('errors', () {
      test('logs a failed request once, at warning, with type and '
          'status', () async {
        final Dio dio = buildDio(<FakeResponder>[_status(503)]);

        await _captureDioException(() => dio.get<Object?>(_path));

        final List<String> warnings = warningMessages();
        expect(warnings, hasLength(1));
        expect(warnings.single, startsWith('✕ GET $_path'));
        expect(warnings.single, contains('badResponse'));
        expect(warnings.single, contains('503'));
      });

      test(
        'does not log an error that already holds an AppException',
        () async {
          final Dio dio = buildDio(<FakeResponder>[
            throwing(
              (RequestOptions o) => DioException(
                requestOptions: o,
                error: const ServerException(message: 'already logged'),
              ),
            ),
          ]);

          await _captureDioException(() => dio.get<Object?>(_path));

          verifyNever(() => logger.warning(any()));
        },
      );

      test('with Retry → Logging → Error, a persistent 503 is logged as an '
          'error exactly once', () async {
        final Dio dio = buildDio(<FakeResponder>[
          _status(503),
        ], withRetryAndError: true);

        await _captureDioException(() => dio.get<Object?>(_path));

        expect(adapter.requests, hasLength(3));
        final List<String> warnings = warningMessages();
        expect(warnings.where((String m) => m.startsWith('✕ ')), hasLength(1));
        expect(
          warnings.where((String m) => m.startsWith('Retrying ')),
          hasLength(2),
        );
      });
    });
  });
}
