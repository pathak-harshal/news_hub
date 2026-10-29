import 'package:dio/dio.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:news_hub/core/error/exceptions.dart';

/// The single place where a [DioException] becomes an [AppException] (D10).
///
/// Added last in the interceptor chain, so retries and the HTTP cache see the
/// raw error first. It passes the error on with [ErrorInterceptorHandler.next]
/// and the mapped [AppException] attached as [DioException.error]; Dio hands
/// that same [DioException] to the caller, and [guardApiCall] unwraps it.
final class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.error is AppException) {
      handler.next(err);
      return;
    }
    handler.next(err.copyWith(error: _mapDioException(err)));
  }
}

/// Runs one Retrofit call and lets only [AppException]s escape from Dio and
/// response parsing.
///
/// - A [DioException] becomes the [AppException] attached by
///   [ErrorInterceptor], or is mapped here if none is attached.
/// - [FormatException], [TypeError] and [CheckedFromJsonException] (thrown,
///   then rethrown, by Retrofit's generated `fromJson` call) become a
///   [ParsingException].
/// - An [AppException] and any other error propagate unchanged, so the
///   repository's catch-all can log them as an unexpected failure (D9).
///
/// Original stack traces are kept. Wrap exactly one API call per invocation,
/// so that catching [TypeError] cannot hide unrelated bugs.
Future<T> guardApiCall<T>(Future<T> Function() call) async {
  try {
    return await call();
  } on DioException catch (e, stackTrace) {
    final Object? attached = e.error;
    Error.throwWithStackTrace(
      attached is AppException ? attached : _mapDioException(e),
      stackTrace,
    );
  } on FormatException catch (e, stackTrace) {
    Error.throwWithStackTrace(
      ParsingException('Malformed response: ${e.message}'),
      stackTrace,
    );
  } on CheckedFromJsonException catch (e, stackTrace) {
    Error.throwWithStackTrace(
      ParsingException(
        'Could not parse ${e.className}.${e.key ?? '?'}: '
        '${e.message ?? 'invalid value'}',
      ),
      stackTrace,
    );
  } on TypeError catch (e, stackTrace) {
    Error.throwWithStackTrace(
      ParsingException('Unexpected response shape: $e'),
      stackTrace,
    );
  }
}

/// Exhaustive over [DioExceptionType] with no default branch: a new type in
/// a future dio release does not compile until it is mapped here.
AppException _mapDioException(DioException err) {
  final String fallback =
      err.message ?? 'Request failed (${err.type.name}): ${err.error}';
  return switch (err.type) {
    DioExceptionType.connectionTimeout ||
    DioExceptionType.sendTimeout ||
    DioExceptionType.receiveTimeout ||
    DioExceptionType.transformTimeout ||
    DioExceptionType.connectionError ||
    DioExceptionType.badCertificate ||
    DioExceptionType.cancel => NetworkException(fallback),
    DioExceptionType.badResponse => _mapBadResponse(err, fallback),
    DioExceptionType.unknown => switch (err.error) {
      FormatException(:final String message) => ParsingException(
        'Malformed response body: $message',
      ),
      _ => ServerException(message: fallback),
    },
  };
}

AppException _mapBadResponse(DioException err, String fallback) {
  final Response<Object?>? response = err.response;
  final int? statusCode = response?.statusCode;
  final ({String? code, String? message}) body = _readNewsApiError(
    response?.data,
  );
  final String message = body.message ?? fallback;
  if (statusCode == 401) {
    return UnauthorizedException(message: message, code: body.code);
  }
  return ServerException(
    message: message,
    statusCode: statusCode,
    code: body.code,
  );
}

/// Reads NewsAPI's error envelope `{status, code, message}`.
///
/// Dio decodes JSON into `Map<String, dynamic>`, which is a
/// `Map<String, Object?>` at runtime. Any other body (an HTML page, plain
/// text, no body) or a missing / non-String field yields `null`.
({String? code, String? message}) _readNewsApiError(Object? data) {
  if (data is! Map<String, Object?>) {
    return (code: null, message: null);
  }
  final Object? code = data['code'];
  final Object? message = data['message'];
  return (
    code: code is String ? code : null,
    message: message is String && message.isNotEmpty ? message : null,
  );
}
