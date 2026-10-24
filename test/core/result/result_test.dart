import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/core/error/failures.dart' as failures;
import 'package:news_hub/core/result/result.dart';

/// Instances are built at runtime on purpose: `const` instances with equal
/// arguments are canonicalised (identical), so equality assertions on them
/// would pass even if `Equatable` were missing.
Success<T> _success<T>(T value) => Success<T>(value);

Failure<T> _failure<T>(failures.Failure failure) => Failure<T>(failure);

failures.Failure _network(String message) => failures.NetworkFailure(message);

failures.Failure _server(String message) => failures.ServerFailure(message);

/// Exhaustive switch with no default branch. Adding a `Result` variant
/// without updating this switch is a compile error.
String _label(Result<int> result) => switch (result) {
  Success<int>() => 'success',
  Failure<int>() => 'failure',
};

void main() {
  group('Success', () {
    test('is equal when values are equal', () {
      final Success<int> a = _success<int>(1);
      final Success<int> b = _success<int>(1);

      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('is not equal when values differ', () {
      expect(_success<int>(1), isNot(equals(_success<int>(2))));
    });

    test('props are [value]', () {
      expect(_success<int>(1).props, equals(<Object?>[1]));
    });

    test('compares List values by contents', () {
      final Success<List<int>> a = _success<List<int>>(<int>[1, 2]);
      final Success<List<int>> b = _success<List<int>>(<int>[1, 2]);

      expect(identical(a.value, b.value), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(_success<List<int>>(<int>[2, 1]))));
    });

    test('supports a nullable value', () {
      final Success<String?> a = _success<String?>(null);

      expect(a.value, isNull);
      expect(a, equals(_success<String?>(null)));
    });
  });

  group('Failure', () {
    test('is equal when failures are equal', () {
      final Failure<int> a = _failure<int>(_network('offline'));
      final Failure<int> b = _failure<int>(_network('offline'));

      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('is not equal when the failure type differs', () {
      expect(
        _failure<int>(_network('boom')),
        isNot(equals(_failure<int>(_server('boom')))),
      );
    });

    test('is not equal when the failure message differs', () {
      expect(
        _failure<int>(_network('boom')),
        isNot(equals(_failure<int>(_network('bang')))),
      );
    });

    test('props are [failure]', () {
      expect(
        _failure<int>(_network('offline')).props,
        equals(<Object?>[_network('offline')]),
      );
    });
  });

  group('equality across variants', () {
    test('Success and Failure are never equal', () {
      expect(_success<int>(1), isNot(equals(_failure<int>(_network('x')))));
    });

    test('the type argument is part of equality', () {
      // Sharp edge for mocks: stubs must return the exact Result<T> type.
      expect(_success<int>(1), isNot(equals(_success<num>(1))));
    });
  });

  group('fold', () {
    test('on Success calls only onSuccess, with the value', () {
      int successCalls = 0;
      int failureCalls = 0;

      final String out = _success<int>(42).fold<String>(
        onSuccess: (int value) {
          successCalls++;
          return 'value:$value';
        },
        onFailure: (failures.Failure failure) {
          failureCalls++;
          return 'failure';
        },
      );

      expect(out, equals('value:42'));
      expect(successCalls, equals(1));
      expect(failureCalls, equals(0));
    });

    test('on Failure calls only onFailure, with the failure', () {
      int successCalls = 0;
      int failureCalls = 0;
      failures.Failure? received;

      final String out = _failure<int>(_network('offline')).fold<String>(
        onSuccess: (int value) {
          successCalls++;
          return 'value:$value';
        },
        onFailure: (failures.Failure failure) {
          failureCalls++;
          received = failure;
          return 'failure';
        },
      );

      expect(out, equals('failure'));
      expect(successCalls, equals(0));
      expect(failureCalls, equals(1));
      expect(received, equals(_network('offline')));
    });
  });

  group('map', () {
    test('on Success transforms the value into Success<R>', () {
      final Result<String> mapped = _success<int>(2)
          .map<String>((int value) => 'n$value');

      expect(mapped, isA<Success<String>>());
      expect(mapped, equals(_success<String>('n2')));
    });

    test('on Failure skips transform and keeps the failure as Failure<R>', () {
      int calls = 0;

      final Result<String> mapped = _failure<int>(_network('offline'))
          .map<String>((int value) {
            calls++;
            return 'n$value';
          });

      expect(calls, equals(0));
      expect(mapped, isA<Failure<String>>());
      expect(mapped, equals(_failure<String>(_network('offline'))));
    });
  });

  group('Result hierarchy', () {
    test('every variant is covered by an exhaustive switch', () {
      expect(_label(_success<int>(1)), equals('success'));
      expect(_label(_failure<int>(_network('x'))), equals('failure'));
    });
  });
}
