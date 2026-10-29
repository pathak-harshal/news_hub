import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:news_hub/core/config/app_config.dart';
import 'package:news_hub/core/config/app_constants.dart';
import 'package:news_hub/core/logging/app_logger.dart';
import 'package:news_hub/core/network/interceptors/api_key_interceptor.dart';
import 'package:news_hub/core/network/interceptors/error_interceptor.dart';
import 'package:news_hub/core/network/interceptors/logging_interceptor.dart';
import 'package:news_hub/core/network/interceptors/retry_interceptor.dart';

/// Builds the `Dio` used for every NewsAPI call (Retrofit client, Step 18).
///
/// Interceptor order, which every other network file relies on:
///
/// 1. [ApiKeyInterceptor] adds `X-Api-Key` before anything else runs.
/// 2. [DioCacheInterceptor] answers repeated GETs from [cacheOptions]
///    (`createHttpCacheOptions()` in production; never on failure).
/// 3. [RetryInterceptor] retries temporary failures through this same `Dio`.
/// 4. [LoggingInterceptor], only when [AppConfig.enableHttpLogging] is true.
/// 5. [ErrorInterceptor] last, so every failure is mapped to an
///    `AppException` exactly once (D10).
///
/// [retryDelay] exists for tests only (no real clock, CLAUDE.md §5);
/// production leaves it out and gets the real backoff.
///
/// Registered in Step 12.
Dio createDioClient({
  required AppConfig config,
  required AppLogger logger,
  required CacheOptions cacheOptions,
  RetryDelay? retryDelay,
}) {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: config.apiBaseUrl.toString(),
      connectTimeout: AppConstants.connectTimeout,
      sendTimeout: AppConstants.sendTimeout,
      receiveTimeout: AppConstants.receiveTimeout,
      receiveDataWhenStatusError: true,
    ),
  );
  dio.interceptors.addAll(<Interceptor>[
    ApiKeyInterceptor(apiKey: config.apiKey),
    DioCacheInterceptor(options: cacheOptions),
    RetryInterceptor(dio: dio, logger: logger, delay: retryDelay),
    if (config.enableHttpLogging) LoggingInterceptor(logger: logger),
    ErrorInterceptor(),
  ]);
  return dio;
}
