import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/network/network_info.dart';
import 'package:news_hub/core/network/network_info_impl.dart';

// Test helpers live outside lib/, so they can only be imported relatively.
// always_use_package_imports only flags relative imports into lib/.
import '../../helpers/mocks.dart';

void main() {
  late MockConnectivity connectivity;
  late MockAppLogger logger;
  late NetworkInfo networkInfo;

  void stubResults(List<ConnectivityResult> results) {
    when(() => connectivity.checkConnectivity())
        .thenAnswer((_) async => results);
  }

  setUp(() {
    connectivity = MockConnectivity();
    logger = MockAppLogger();
    networkInfo = NetworkInfoImpl(connectivity: connectivity, logger: logger);
  });

  group('isConnected is true', () {
    // Loops over the plugin's enum so a value added in a future version is
    // covered automatically.
    for (final ConnectivityResult result in ConnectivityResult.values.where(
      (ConnectivityResult r) => r != ConnectivityResult.none,
    )) {
      test('for [${result.name}]', () async {
        stubResults(<ConnectivityResult>[result]);

        expect(await networkInfo.isConnected, isTrue);
      });
    }

    test('for a mixed list [none, wifi]', () async {
      stubResults(<ConnectivityResult>[
        ConnectivityResult.none,
        ConnectivityResult.wifi,
      ]);

      expect(await networkInfo.isConnected, isTrue);
    });
  });

  group('isConnected is false', () {
    test('for [none]', () async {
      stubResults(<ConnectivityResult>[ConnectivityResult.none]);

      expect(await networkInfo.isConnected, isFalse);
    });

    test('for an empty list', () async {
      stubResults(<ConnectivityResult>[]);

      expect(await networkInfo.isConnected, isFalse);
    });
  });

  group('when the platform call throws', () {
    test('returns true and logs one warning with the error', () async {
      final StateError error = StateError('platform channel failed');
      when(() => connectivity.checkConnectivity()).thenThrow(error);

      expect(await networkInfo.isConnected, isTrue);
      verify(
        () => logger.warning(
          any(),
          error: any(named: 'error', that: same(error)),
          stackTrace: any(named: 'stackTrace', that: isNotNull),
        ),
      ).called(1);
      verifyNoMoreInteractions(logger);
    });
  });

  group('freshness', () {
    test('checks connectivity again on every read', () async {
      stubResults(<ConnectivityResult>[ConnectivityResult.wifi]);

      await networkInfo.isConnected;
      await networkInfo.isConnected;

      verify(() => connectivity.checkConnectivity()).called(2);
    });

    test('does not log when the check succeeds', () async {
      stubResults(<ConnectivityResult>[ConnectivityResult.wifi]);

      await networkInfo.isConnected;

      verifyNoMoreInteractions(logger);
    });
  });
}
