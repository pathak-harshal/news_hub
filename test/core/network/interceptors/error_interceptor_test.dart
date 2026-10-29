import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:news_hub/core/error/exceptions.dart';
import 'package:news_hub/core/network/interceptors/error_interceptor.dart';

import '../../../helpers/fake_http_client_adapter.dart';

const String _path = '/top-headlines';

/// A real [Dio] whose transport is scripted; only the network is fake.
Dio _buildDio(
  List<FakeResponder> responders, {
  bool withErrorInterceptor = true,
}) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'https://newsapi.test/v2'))
    ..httpClientAdapter = FakeHttpClientAdapter(responders);
  if (withErrorInterceptor) {
    dio.interceptors.add(ErrorInterceptor());
  }
  return dio;
}

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

/// Sends one GET through a [Dio] with [ErrorInterceptor] and returns the
/// `error` attached to the resulting [DioException].
Future<Object?> _mappedErrorFor(FakeResponder responder) async {
  final Dio dio = _buildDio(<FakeResponder>[responder]);
  final DioException e = await _captureDioException(
    () => dio.get<Object?>(_path),
  );
  return e.error;
}

Map<String, Object?> _newsApiError(String code, String message) =>
    <String, Object?>{'status': 'error', 'code': code, 'message': message};

Matcher _isServerException({
  required int? statusCode,
  required String? code,
  Object? message,
}) => isA<ServerException>()
    .having((ServerException e) => e.statusCode, 'statusCode', statusCode)
    .having((ServerException e) => e.code, 'code', code)
    .having((ServerException e) => e.message, 'message', message ?? isNotEmpty);

Matcher _isUnauthorizedException({required String? code, Object? message}) =>
    isA<UnauthorizedException>()
        .having((UnauthorizedException e) => e.code, 'code', code)
        .having(
          (UnauthorizedException e) => e.message,
          'message',
          message ?? isNotEmpty,
        );

Matcher _isNetworkException() => isA<NetworkException>().having(
  (NetworkException e) => e.message,
  'message',
  isNotEmpty,
);

Matcher _isParsingException() => isA<ParsingException>().having(
  (ParsingException e) => e.message,
  'message',
  isNotEmpty,
);

/// Exhaustive on purpose (no default): a new `DioExceptionType` in a future
/// dio release breaks this test's compilation until the mapping is decided.
Matcher _expectedFor(DioExceptionType type) => switch (type) {
  DioExceptionType.connectionTimeout ||
  DioExceptionType.sendTimeout ||
  DioExceptionType.receiveTimeout ||
  DioExceptionType.transformTimeout ||
  DioExceptionType.connectionError ||
  DioExceptionType.badCertificate ||
  DioExceptionType.cancel => isA<NetworkException>(),
  DioExceptionType.badResponse ||
  DioExceptionType.unknown => isA<ServerException>(),
};

void main() {
  group('ErrorInterceptor', () {
    group('network failures → NetworkException', () {
      const Duration timeout = Duration(seconds: 1);
      final Map<String, DioException Function(RequestOptions)>
      cases = <String, DioException Function(RequestOptions)>{
        'connectionTimeout': (RequestOptions o) =>
            DioException.connectionTimeout(timeout: timeout, requestOptions: o),
        'sendTimeout': (RequestOptions o) =>
            DioException.sendTimeout(timeout: timeout, requestOptions: o),
        'receiveTimeout': (RequestOptions o) =>
            DioException.receiveTimeout(timeout: timeout, requestOptions: o),
        'transformTimeout': (RequestOptions o) =>
            DioException.transformTimeout(timeout: timeout, requestOptions: o),
        'connectionError': (RequestOptions o) => DioException.connectionError(
          requestOptions: o,
          reason: 'Connection refused',
        ),
        'badCertificate': (RequestOptions o) =>
            DioException.badCertificate(requestOptions: o),
        'cancel': (RequestOptions o) => DioException.requestCancelled(
          requestOptions: o,
          reason: 'cancelled by caller',
        ),
      };

      for (final MapEntry<String, DioException Function(RequestOptions)> c
          in cases.entries) {
        test(c.key, () async {
          expect(
            await _mappedErrorFor(throwing(c.value)),
            _isNetworkException(),
          );
        });
      }
    });

    test('maps every DioExceptionType value to an AppException', () async {
      for (final DioExceptionType type in DioExceptionType.values) {
        final Object? mapped = await _mappedErrorFor(
          throwing(
            (RequestOptions o) => DioException(
              requestOptions: o,
              type: type,
              response: type == DioExceptionType.badResponse
                  ? Response<Object?>(requestOptions: o, statusCode: 503)
                  : null,
            ),
          ),
        );
        expect(mapped, _expectedFor(type), reason: 'type: ${type.name}');
      }
    });

    group('bad responses', () {
      test('401 with a NewsAPI body → UnauthorizedException with its code '
          'and message', () async {
        final Object? mapped = await _mappedErrorFor(
          jsonResponse(
            401,
            _newsApiError('apiKeyInvalid', 'Your API key is invalid.'),
          ),
        );
        expect(
          mapped,
          _isUnauthorizedException(
            code: 'apiKeyInvalid',
            message: 'Your API key is invalid.',
          ),
        );
      });

      test(
        '401 with a non-JSON body → UnauthorizedException, code null',
        () async {
          final Object? mapped = await _mappedErrorFor(
            rawResponse(
              401,
              '<html>Unauthorized</html>',
              contentType: 'text/html',
            ),
          );
          expect(mapped, _isUnauthorizedException(code: null));
        },
      );

      test('429 rateLimited → ServerException(429, rateLimited)', () async {
        final Object? mapped = await _mappedErrorFor(
          jsonResponse(429, _newsApiError('rateLimited', 'Too many requests.')),
        );
        expect(
          mapped,
          _isServerException(
            statusCode: 429,
            code: 'rateLimited',
            message: 'Too many requests.',
          ),
        );
      });

      test(
        '500 unexpectedError → ServerException(500, unexpectedError)',
        () async {
          final Object? mapped = await _mappedErrorFor(
            jsonResponse(
              500,
              _newsApiError('unexpectedError', 'Server error.'),
            ),
          );
          expect(
            mapped,
            _isServerException(statusCode: 500, code: 'unexpectedError'),
          );
        },
      );

      test(
        '400 with an HTML string body → ServerException, code null',
        () async {
          final Object? mapped = await _mappedErrorFor(
            rawResponse(
              400,
              '<html>Bad Gateway</html>',
              contentType: 'text/html',
            ),
          );
          expect(mapped, _isServerException(statusCode: 400, code: null));
        },
      );

      test(
        '400 whose code is not a String → code null, message kept',
        () async {
          final Object? mapped = await _mappedErrorFor(
            jsonResponse(400, <String, Object?>{
              'status': 'error',
              'code': 42,
              'message': 'Bad parameter.',
            }),
          );
          expect(
            mapped,
            _isServerException(
              statusCode: 400,
              code: null,
              message: 'Bad parameter.',
            ),
          );
        },
      );
    });

    group('unknown errors', () {
      test('malformed JSON body → ParsingException', () async {
        final Object? mapped = await _mappedErrorFor(
          rawResponse(
            200,
            '{"status": "ok", ',
            contentType: Headers.jsonContentType,
          ),
        );
        expect(mapped, _isParsingException());
      });

      test('any other error → ServerException with no status code', () async {
        final Object? mapped = await _mappedErrorFor(
          throwing((RequestOptions o) => StateError('adapter exploded')),
        );
        expect(mapped, _isServerException(statusCode: null, code: null));
      });
    });

    test('an error that already holds an AppException passes through '
        'unchanged', () async {
      const ServerException alreadyMapped = ServerException(
        message: 'already mapped',
        statusCode: 418,
      );
      final Object? mapped = await _mappedErrorFor(
        throwing(
          (RequestOptions o) =>
              DioException(requestOptions: o, error: alreadyMapped),
        ),
      );
      expect(mapped, same(alreadyMapped));
    });

    test('keeps the original requestOptions on the DioException', () async {
      final Dio dio = _buildDio(<FakeResponder>[
        jsonResponse(500, _newsApiError('unexpectedError', 'Server error.')),
      ]);
      final DioException e = await _captureDioException(
        () => dio.get<Object?>(_path),
      );
      expect(e.requestOptions.path, _path);
      expect(e.type, DioExceptionType.badResponse);
    });

    test('leaves successful responses untouched', () async {
      final Dio dio = _buildDio(<FakeResponder>[
        jsonResponse(200, <String, Object?>{'status': 'ok'}),
      ]);
      final Response<Object?> response = await dio.get<Object?>(_path);
      expect(response.statusCode, 200);
      expect(response.data, <String, Object?>{'status': 'ok'});
    });
  });

  group('guardApiCall', () {
    test('returns the value of a successful call', () async {
      expect(await guardApiCall<int>(() async => 42), 42);
    });

    test('unwraps the AppException attached by ErrorInterceptor', () async {
      final Dio dio = _buildDio(<FakeResponder>[
        jsonResponse(401, _newsApiError('apiKeyMissing', 'No API key.')),
      ]);
      await expectLater(
        guardApiCall<Response<Object?>>(() => dio.get<Object?>(_path)),
        throwsA(_isUnauthorizedException(code: 'apiKeyMissing')),
      );
    });

    test(
      'maps a DioException that has no AppException (no interceptor)',
      () async {
        final Dio dio = _buildDio(<FakeResponder>[
          jsonResponse(429, _newsApiError('rateLimited', 'Too many requests.')),
        ], withErrorInterceptor: false);
        await expectLater(
          guardApiCall<Response<Object?>>(() => dio.get<Object?>(_path)),
          throwsA(_isServerException(statusCode: 429, code: 'rateLimited')),
        );
      },
    );

    test('maps a bare connection error to NetworkException', () async {
      await expectLater(
        guardApiCall<int>(
          () async => throw DioException.connectionError(
            requestOptions: RequestOptions(path: _path),
            reason: 'Connection refused',
          ),
        ),
        throwsA(_isNetworkException()),
      );
    });

    test('FormatException → ParsingException', () async {
      await expectLater(
        guardApiCall<int>(() async => throw const FormatException('bad json')),
        throwsA(_isParsingException()),
      );
    });

    test('TypeError → ParsingException', () async {
      await expectLater(
        guardApiCall<int>(() async {
          const Object totalResults = 'not a number';
          return totalResults as int;
        }),
        throwsA(_isParsingException()),
      );
    });

    test('CheckedFromJsonException → ParsingException', () async {
      await expectLater(
        guardApiCall<int>(
          () async => throw CheckedFromJsonException(
            <String, Object?>{'totalResults': 'x'},
            'totalResults',
            'NewsResponseModel',
            'type mismatch',
          ),
        ),
        throwsA(_isParsingException()),
      );
    });

    test('rethrows an AppException unchanged', () async {
      const NetworkException offline = NetworkException('offline');
      await expectLater(
        guardApiCall<int>(() async => throw offline),
        throwsA(same(offline)),
      );
    });

    test('rethrows any other error unchanged', () async {
      await expectLater(
        guardApiCall<int>(() async => throw StateError('bug')),
        throwsA(isA<StateError>()),
      );
    });

    test('keeps the original stack trace when converting', () async {
      final StackTrace original = StackTrace.fromString('original-trace');
      try {
        await guardApiCall<int>(
          () async => Error.throwWithStackTrace(
            const FormatException('bad json'),
            original,
          ),
        );
        fail('Expected a ParsingException');
      } on ParsingException catch (_, stackTrace) {
        expect(stackTrace.toString(), contains('original-trace'));
      }
    });
  });
}
