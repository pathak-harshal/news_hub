import 'package:dio/dio.dart';
import 'package:news_hub/core/error/exceptions.dart';
import 'package:news_hub/core/logging/app_logger.dart';

/// Logs each request, response and failed request through [AppLogger].
///
/// - `→` request line at `debug`: method, full URL and a redacted **copy** of
///   the headers. Dio's own header map is never modified (its
///   case-insensitive map breaks under `removeWhere`, Step 9b).
/// - `←` response line at `debug`: status, method, path and time taken.
///   Bodies are never logged.
/// - `✕` error line at `warning`: method, path, error type and status.
///   Errors that already hold an [AppException] were logged by an inner
///   retry attempt (Retry → Logging → Error), so they are skipped; each
///   failed request is logged once.
///
/// Reads [DioException] for logging only (CLAUDE.md §3.4). `dio_client.dart`
/// adds this interceptor only when `AppConfig.enableHttpLogging` is true.
final class LoggingInterceptor extends Interceptor {
  LoggingInterceptor({required this._logger, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const String _startedAtKey = 'logging_started_at';
  static const String _redacted = '***';
  static const Set<String> _sensitiveHeaders = <String>{
    'x-api-key',
    'authorization',
    'cookie',
    'set-cookie',
  };

  final AppLogger _logger;
  final DateTime Function() _now;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.extra[_startedAtKey] = _now();
    _logger.debug(
      '→ ${options.method} ${options.uri} '
      'headers: ${_redactedCopy(options.headers)}',
    );
    handler.next(options);
  }

  @override
  void onResponse(
    Response<Object?> response,
    ResponseInterceptorHandler handler,
  ) {
    final RequestOptions options = response.requestOptions;
    _logger.debug(
      '← ${response.statusCode} ${options.method} ${options.path}'
      '${_timeTaken(options)}',
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.error is! AppException) {
      final RequestOptions options = err.requestOptions;
      final int? statusCode = err.response?.statusCode;
      final String status = statusCode == null ? '' : ' $statusCode';
      final String detail = err.message?.split('\n').first ?? 'no message';
      _logger.warning(
        '✕ ${options.method} ${options.path} → ${err.type.name}$status'
        '${_timeTaken(options)}: $detail',
      );
    }
    handler.next(err);
  }

  String _timeTaken(RequestOptions options) {
    final Object? startedAt = options.extra[_startedAtKey];
    return startedAt is DateTime
        ? ' (${_now().difference(startedAt).inMilliseconds} ms)'
        : '';
  }

  Map<String, Object?> _redactedCopy(Map<String, Object?> headers) =>
      <String, Object?>{
        for (final MapEntry<String, Object?> header in headers.entries)
          header.key: _sensitiveHeaders.contains(header.key.toLowerCase())
              ? _redacted
              : header.value,
      };
}
