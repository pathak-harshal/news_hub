import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/core/error/failures.dart' as failures;
import 'package:news_hub/core/result/result.dart';
import 'package:news_hub/core/usecase/usecase.dart';

/// Test-only use cases proving the contract's shape: callable like a
/// function, returning `Future<Result<T>>`.
final class _Double implements UseCase<int, int> {
  @override
  Future<Result<int>> call(int params) async => Success<int>(params * 2);
}

final class _Fails implements UseCase<int, int> {
  @override
  Future<Result<int>> call(int params) async =>
      Failure<int>(failures.NetworkFailure('offline: $params'));
}

final class _Answer implements UseCase<String, NoParams> {
  @override
  Future<Result<String>> call(NoParams params) async =>
      const Success<String>('ok');
}

void main() {
  group('NoParams', () {
    // Built through a tear-off so instances are created at runtime and are
    // not the single canonical `const NoParams()`.
    const NoParams Function() build = NoParams.new;

    test('instances are equal', () {
      final NoParams a = build();
      final NoParams b = build();

      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('props are empty', () {
      expect(build().props, isEmpty);
    });
  });

  group('UseCase contract', () {
    test('is callable like a function and completes with Success', () async {
      final UseCase<int, int> useCase = _Double();

      expect(await useCase(21), equals(const Success<int>(42)));
    });

    test('can complete with a Failure carrying a domain failure', () async {
      final UseCase<int, int> useCase = _Fails();

      expect(
        await useCase(1),
        equals(const Failure<int>(failures.NetworkFailure('offline: 1'))),
      );
    });

    test('accepts NoParams for use cases without input', () async {
      final UseCase<String, NoParams> useCase = _Answer();

      expect(
        await useCase(const NoParams()),
        equals(const Success<String>('ok')),
      );
    });
  });
}
