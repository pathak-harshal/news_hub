import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/config/app_constants.dart';
import 'package:news_hub/core/network/cache/http_cache_config.dart';

/// A store that cannot be confused with the default [MemCacheStore].
class _MockCacheStore extends Mock implements CacheStore {}

void main() {
  group('createHttpCacheOptions', () {
    late CacheOptions options;

    setUp(() {
      options = createHttpCacheOptions();
    });

    test('caches every successful GET (forceCache)', () {
      expect(options.policy, CachePolicy.forceCache);
    });

    test('expires entries after AppConstants.httpCacheMaxStale', () {
      expect(options.maxStale, AppConstants.httpCacheMaxStale);
    });

    test('never answers a network failure from the cache', () {
      expect(options.hitCacheOnNetworkFailure, isFalse);
    });

    test('never answers an error status code from the cache', () {
      expect(options.hitCacheOnErrorCodes, isEmpty);
    });

    test('never caches POST requests', () {
      expect(options.allowPostMethod, isFalse);
    });

    test('defaults to an in-memory store', () {
      expect(options.store, isA<MemCacheStore>());
    });

    test('uses the store it is given', () {
      final _MockCacheStore store = _MockCacheStore();

      expect(createHttpCacheOptions(store: store).store, same(store));
    });

    test('builds the cache key from the URL only, never the API key', () {
      final Uri url = Uri.parse(
        'https://newsapi.test/v2/top-headlines?country=us',
      );

      final String keyA = options.keyBuilder(
        url: url,
        headers: <String, String>{'X-Api-Key': 'key-a'},
      );
      final String keyB = options.keyBuilder(
        url: url,
        headers: <String, String>{'X-Api-Key': 'key-b'},
      );

      expect(keyA, keyB);
      expect(keyA, isNot(contains('key-a')));
    });
  });
}
