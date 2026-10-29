/// Reports whether the device currently has a network connection
/// (CLAUDE.md §3.5).
///
/// Repositories use it as a fast-path hint: when [isConnected] is `false`
/// they go straight to the cache instead of waiting for a request to time
/// out. A `true` result does not guarantee the internet is reachable (for
/// example behind a captive portal); a failed request still falls back to
/// the cache (D9).
///
/// Pure Dart with no imports, so tests mock it with mocktail.
abstract interface class NetworkInfo {
  /// Freshly checked on every read; never cached.
  Future<bool> get isConnected;
}
