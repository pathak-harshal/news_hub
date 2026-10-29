import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:news_hub/core/config/app_constants.dart';

/// HTTP cache settings for the NewsAPI `Dio` (Step 10b adds the
/// `DioCacheInterceptor` second in the chain, after `ApiKeyInterceptor`).
///
/// - [CachePolicy.forceCache] saves every successful GET whatever NewsAPI's
///   cache headers say; entries expire after
///   [AppConstants.httpCacheMaxStale]. This keeps repeated identical
///   requests off the free daily quota. Pull-to-refresh must ask for
///   [CachePolicy.refreshForceCache] per request (Step 19).
/// - Failed requests are never answered from this cache. Offline reading is
///   the repository's Hive fallback (CLAUDE.md §3.5), so the repository can
///   tell it is offline and `RetryInterceptor` still runs.
/// - The default key builder hashes the URL only, so the API key (sent as a
///   header) never reaches a cache key.
/// - The default store is in memory and is cleared on restart.
CacheOptions createHttpCacheOptions({CacheStore? store}) {
  return CacheOptions(
    store: store ?? MemCacheStore(),
    policy: CachePolicy.forceCache,
    maxStale: AppConstants.httpCacheMaxStale,
    // Package defaults today; set explicitly so an upstream default change
    // cannot silently turn the HTTP cache into an offline fallback.
    hitCacheOnNetworkFailure: false,
    hitCacheOnErrorCodes: const <int>[],
  );
}
