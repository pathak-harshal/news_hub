import 'package:dio/dio.dart';

/// Sends the NewsAPI key in the [headerName] header on every request.
///
/// The key never goes in a query parameter, so it stays out of URLs, logs
/// and HTTP cache keys (working agreement 6). It is first in the interceptor
/// chain, so the logging interceptor must redact [headerName].
///
/// Dio keeps request headers in a case-insensitive map, so assigning
/// [headerName] replaces a caller-supplied `x-api-key` instead of adding a
/// second header (covered by a test).
///
/// Validating the key is `AppConfig`'s job; this class only applies it.
/// Registered in Step 12 with `AppConfig.apiKey`.
final class ApiKeyInterceptor extends Interceptor {
  ApiKeyInterceptor({required this._apiKey});

  /// Header NewsAPI reads the key from; shared with log redaction.
  static const String headerName = 'X-Api-Key';

  final String _apiKey;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    options.headers[headerName] = _apiKey;
    handler.next(options);
  }
}
