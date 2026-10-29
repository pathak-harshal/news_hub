import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:get_it/get_it.dart';
import 'package:news_hub/core/config/app_config.dart';
import 'package:news_hub/core/logging/app_logger.dart';
import 'package:news_hub/core/logging/app_logger_impl.dart';
import 'package:news_hub/core/network/cache/http_cache_config.dart';
import 'package:news_hub/core/network/dio_client.dart';
import 'package:news_hub/core/network/network_info.dart';
import 'package:news_hub/core/network/network_info_impl.dart';

/// Registers the shared, feature-agnostic services in [getIt].
///
/// [config] is read once in `bootstrap.dart` (Step 23) with
/// `AppConfig.fromEnvironment()` and passed in, so this function never reads
/// compile-time values and stays testable.
///
/// Everything except [config] is a lazy singleton: nothing is built until it
/// is first requested, and every lookup returns the same instance.
/// Hive storage is added here at Step 17a.
void registerCoreModule(GetIt getIt, {required AppConfig config}) {
  getIt
    ..registerSingleton<AppConfig>(config)
    ..registerLazySingleton<AppLogger>(
      () => AppLoggerImpl(minLevel: config.logLevel),
    )
    ..registerLazySingleton<NetworkInfo>(
      () => NetworkInfoImpl(
        connectivity: Connectivity(),
        logger: getIt<AppLogger>(),
      ),
    )
    ..registerLazySingleton<CacheOptions>(createHttpCacheOptions)
    ..registerLazySingleton<Dio>(
      () => createDioClient(
        config: getIt<AppConfig>(),
        logger: getIt<AppLogger>(),
        cacheOptions: getIt<CacheOptions>(),
      ),
    );
}
