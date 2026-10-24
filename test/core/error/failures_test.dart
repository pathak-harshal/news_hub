import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/core/error/failures.dart' as failures;

/// Instances are built at runtime on purpose: `const` instances with equal
/// arguments are canonicalised (identical), so equality assertions on them
/// would pass even if `Equatable` were missing.
failures.ServerFailure _server(String message, {int? statusCode}) =>
    failures.ServerFailure(message, statusCode: statusCode);

/// Exhaustive switch with no default branch. Adding a `Failure` subtype
/// without updating this switch is a compile error, which keeps the
/// hierarchy's sealedness under test.
String _label(failures.Failure failure) => switch (failure) {
  failures.ServerFailure() => 'server',
  failures.UnauthorizedFailure() => 'unauthorized',
  failures.NetworkFailure() => 'network',
  failures.CacheFailure() => 'cache',
  failures.UnexpectedFailure() => 'unexpected',
};

void main() {
  const Map<String, failures.Failure Function(String)> messageOnly =
      <String, failures.Failure Function(String)>{
        'UnauthorizedFailure': failures.UnauthorizedFailure.new,
        'NetworkFailure': failures.NetworkFailure.new,
        'CacheFailure': failures.CacheFailure.new,
        'UnexpectedFailure': failures.UnexpectedFailure.new,
      };

  group('ServerFailure', () {
    test('is a Failure', () {
      expect(_server('boom'), isA<failures.Failure>());
    });

    test('statusCode defaults to null', () {
      expect(_server('boom').statusCode, isNull);
    });

    test('is equal when message and statusCode match', () {
      final failures.ServerFailure a = _server('boom', statusCode: 500);
      final failures.ServerFailure b = _server('boom', statusCode: 500);

      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('is not equal when statusCode differs', () {
      expect(
        _server('boom', statusCode: 500),
        isNot(equals(_server('boom', statusCode: 503))),
      );
    });

    test('is not equal when message differs', () {
      expect(
        _server('boom', statusCode: 500),
        isNot(equals(_server('bang', statusCode: 500))),
      );
    });

    test('props are [message, statusCode]', () {
      expect(
        _server('boom', statusCode: 429).props,
        equals(<Object?>['boom', 429]),
      );
      expect(_server('boom').props, equals(<Object?>['boom', null]));
    });
  });

  for (final MapEntry<String, failures.Failure Function(String)> entry
      in messageOnly.entries) {
    final failures.Failure Function(String) build = entry.value;

    group(entry.key, () {
      test('is a Failure', () {
        expect(build('boom'), isA<failures.Failure>());
      });

      test('is equal when message matches', () {
        final failures.Failure a = build('boom');
        final failures.Failure b = build('boom');

        expect(identical(a, b), isFalse);
        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('is not equal when message differs', () {
        expect(build('boom'), isNot(equals(build('bang'))));
      });

      test('props are [message]', () {
        expect(build('boom').props, equals(<Object?>['boom']));
      });

      test('exposes message', () {
        expect(build('boom').message, equals('boom'));
      });
    });
  }

  group('Failure hierarchy', () {
    test('different subtypes with the same message are not equal', () {
      final List<failures.Failure> all = <failures.Failure>[
        _server('same'),
        ...messageOnly.values.map(
          (failures.Failure Function(String) build) => build('same'),
        ),
      ];

      for (int i = 0; i < all.length; i++) {
        for (int j = 0; j < all.length; j++) {
          if (i != j) {
            expect(all[i], isNot(equals(all[j])));
          }
        }
      }
    });

    test('every subtype is covered by an exhaustive switch', () {
      expect(_label(_server('x')), equals('server'));
      expect(
        _label(messageOnly['UnauthorizedFailure']!('x')),
        equals('unauthorized'),
      );
      expect(_label(messageOnly['NetworkFailure']!('x')), equals('network'));
      expect(_label(messageOnly['CacheFailure']!('x')), equals('cache'));
      expect(
        _label(messageOnly['UnexpectedFailure']!('x')),
        equals('unexpected'),
      );
    });
  });
}
