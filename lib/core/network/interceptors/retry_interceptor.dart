import 'package:dio/dio.dart';
import 'package:news_hub/core/logging/app_logger.dart';

/// Waits for [duration]; injected so tests never touch a real clock.
typedef RetryDelay = Future<void> Function(Duration duration);

/// Retries idempotent requests that failed for a reason likely to be
/// temporary, waiting `baseDelay × 2^attempt` between attempts.
///
/// Retried: `GET` / `HEAD` with a connection, send or receive timeout, a
/// connection error, or HTTP 500 / 502 / 503 / 504. Everything else
/// (4xx including 429, cancel, bad certificate, transform timeout, unknown)
/// is passed on at once. NewsAPI's free key has a small daily quota, so a
/// rate-limit error is never retried.
///
/// A retry goes back through the whole chain via [Dio.fetch], so it gets the
/// API key and cache again; the attempt number travels in
/// `RequestOptions.extra[attemptKey]`, so nested retries share one budget.
///
/// Reads [DioException] for the decision only and never maps or replaces it
/// (CLAUDE.md §3.4). Logs a warning per retry with method, path, attempt and
/// reason; never headers.
final class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required this._dio,
    required this._logger,
    this._maxRetries = 2,
    this._baseDelay = const Duration(milliseconds: 500),
    RetryDelay? delay,
  }) : _delay = delay ?? Future<void>.delayed;

  /// Key in `RequestOptions.extra` holding how many retries have run.
  static const String attemptKey = 'retry_attempt';

  static const Set<String> _retryableMethods = <String>{'GET', 'HEAD'};
  static const Set<int> _retryableStatusCodes = <int>{500, 502, 503, 504};

  final Dio _dio;
  final AppLogger _logger;
  final int _maxRetries;
  final Duration _baseDelay;
  final RetryDelay _delay;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final RequestOptions options = err.requestOptions;
    final int attempt = _attemptOf(options);
    if (attempt >= _maxRetries || !_isRetryable(err)) {
      handler.next(err);
      return;
    }

    final int nextAttempt = attempt + 1;
    final Duration wait = _baseDelay * (1 << attempt);
    final int? statusCode = err.response?.statusCode;
    final String reason = statusCode == null
        ? err.type.name
        : '${err.type.name} $statusCode';
    _logger.warning(
      'Retrying ${options.method} ${options.path} '
      '(attempt $nextAttempt of $_maxRetries) after $reason, '
      'in ${wait.inMilliseconds} ms',
    );

    await _delay(wait);
    options.extra[attemptKey] = nextAttempt;
    try {
      final Response<Object?> response = await _dio.fetch<Object?>(options);
      handler.resolve(response);
    } on DioException catch (retryError) {
      handler.next(retryError);
    }
  }

  int _attemptOf(RequestOptions options) {
    final Object? value = options.extra[attemptKey];
    return value is int ? value : 0;
  }

  bool _isRetryable(DioException err) {
    final String method = err.requestOptions.method.toUpperCase();
    if (!_retryableMethods.contains(method)) {
      return false;
    }
    return switch (err.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => true,
      DioExceptionType.badResponse => _retryableStatusCodes.contains(
        err.response?.statusCode,
      ),
      DioExceptionType.transformTimeout ||
      DioExceptionType.badCertificate ||
      DioExceptionType.cancel ||
      DioExceptionType.unknown => false,
    };
  }
}
