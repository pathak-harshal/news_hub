import 'package:dio/dio.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:news_hub/core/config/app_config.dart';
import 'package:news_hub/core/config/flavor.dart';
import 'package:news_hub/core/di/core_module.dart';
import 'package:news_hub/core/logging/app_logger.dart';
import 'package:news_hub/core/logging/app_logger_impl.dart';
import 'package:news_hub/core/logging/log_level.dart';
import 'package:news_hub/core/network/interceptors/logging_interceptor.dart';
import 'package:news_hub/core/network/network_info.dart';
import 'package:news_hub/core/network/network_info_impl.dart';

const String _baseUrl = 'https://newsapi.test/v2';

AppConfig _config({bool enableHttpLogging = false}) => AppConfig(
  flavor: Flavor.dev,
  apiBaseUrl: Uri.parse(_baseUrl),
  apiKey: 'test-api-key',
  enableHttpLogging: enableHttpLogging,
  logLevel: LogLevel.info,
);

bool _hasLoggingInterceptor(Dio dio) =>
    dio.interceptors.any((Interceptor i) => i is LoggingInterceptor);

void main() {
  late GetIt getIt;

  setUp(() {
    // A private container per test; the global `getIt` is never touched.
    getIt = GetIt.asNewInstance();
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('registerCoreModule', () {
    test('registers the given AppConfig instance itself', () {
      final AppConfig config = _config();

      registerCoreModule(getIt, config: config);

      expect(getIt<AppConfig>(), same(config));
    });

    test('resolves AppLogger to AppLoggerImpl', () {
      registerCoreModule(getIt, config: _config());

      expect(getIt<AppLogger>(), isA<AppLoggerImpl>());
    });

    test('resolves NetworkInfo to NetworkInfoImpl', () {
      registerCoreModule(getIt, config: _config());

      expect(getIt<NetworkInfo>(), isA<NetworkInfoImpl>());
    });

    test('resolves CacheOptions from createHttpCacheOptions', () {
      registerCoreModule(getIt, config: _config());

      expect(getIt<CacheOptions>().policy, CachePolicy.forceCache);
    });

    test('resolves Dio with the configured base URL', () {
      registerCoreModule(getIt, config: _config());

      expect(getIt<Dio>().options.baseUrl, _baseUrl);
    });

    test('Dio includes LoggingInterceptor when HTTP logging is on', () {
      registerCoreModule(getIt, config: _config(enableHttpLogging: true));

      expect(_hasLoggingInterceptor(getIt<Dio>()), isTrue);
    });

    test('Dio leaves out LoggingInterceptor when HTTP logging is off', () {
      registerCoreModule(getIt, config: _config());

      expect(_hasLoggingInterceptor(getIt<Dio>()), isFalse);
    });

    test('returns the same instance on every lookup', () {
      registerCoreModule(getIt, config: _config());

      expect(getIt<AppLogger>(), same(getIt<AppLogger>()));
      expect(getIt<NetworkInfo>(), same(getIt<NetworkInfo>()));
      expect(getIt<CacheOptions>(), same(getIt<CacheOptions>()));
      expect(getIt<Dio>(), same(getIt<Dio>()));
    });
  });
}
