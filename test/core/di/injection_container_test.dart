import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:news_hub/core/config/app_config.dart';
import 'package:news_hub/core/di/injection_container.dart';

void main() {
  late AppConfig config;

  setUp(() {
    config = AppConfig.fromMap(const <String, String>{
      'FLAVOR': 'dev',
      'API_BASE_URL': 'https://newsapi.org/v2',
      'API_KEY': 'test-api-key',
      'ENABLE_HTTP_LOGGING': 'false',
      'LOG_LEVEL': 'debug',
    });
  });

  group('initDependencies', () {
    group('with an explicit container', () {
      late GetIt container;

      setUp(() {
        container = GetIt.asNewInstance();
      });

      tearDown(() async {
        await container.reset();
      });

      test('registers the core module into the given container '
          'and leaves the global getIt untouched', () async {
        await initDependencies(config: config, container: container);

        expect(container.isRegistered<Dio>(), isTrue);
        expect(getIt.isRegistered<Dio>(), isFalse);
      });
    });

    group('without a container', () {
      tearDown(() async {
        await getIt.reset();
      });

      test('registers the core module into the global getIt', () async {
        await initDependencies(config: config);

        expect(identical(getIt, GetIt.instance), isTrue);
        expect(getIt.isRegistered<Dio>(), isTrue);
      });
    });
  });
}
