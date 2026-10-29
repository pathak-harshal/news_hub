import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:news_hub/core/logging/app_logger.dart';
import 'package:news_hub/core/network/network_info.dart';

/// [NetworkInfo] backed by `connectivity_plus`.
///
/// Registered in Step 12 with `Connectivity()` and the app's [AppLogger].
///
/// Connected means at least one interface other than
/// [ConnectivityResult.none] is up. If the platform check itself fails, this
/// logs a warning and reports `true`: the request then decides, and a real
/// failure still falls back to the cache (D9).
final class NetworkInfoImpl implements NetworkInfo {
  NetworkInfoImpl({required this._connectivity, required this._logger});

  final Connectivity _connectivity;
  final AppLogger _logger;

  @override
  Future<bool> get isConnected async {
    try {
      final List<ConnectivityResult> results = await _connectivity
          .checkConnectivity();
      return results.any(
        (ConnectivityResult result) => result != ConnectivityResult.none,
      );
    } on Object catch (error, stackTrace) {
      _logger.warning(
        'Connectivity check failed; assuming connected',
        error: error,
        stackTrace: stackTrace,
      );
      return true;
    }
  }
}
