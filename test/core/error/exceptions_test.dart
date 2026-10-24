import 'package:flutter_test/flutter_test.dart';
import 'package:news_hub/core/error/exceptions.dart';
import 'package:news_hub/core/error/failures.dart' as failures;

/// Instances are built at runtime on purpose: `const` instances with equal
/// arguments are canonicalised (identical), so equality assertions on them
/// would pass even if `Equatable` were missing.
ServerException _server({
  String message = 'boom',
  int? statusCode,
  String? code,
}) => ServerException(message: message, statusCode: statusCode, code: code);

UnauthorizedException _unauthorized({String message = 'boom', String? code}) =>
    UnauthorizedException(message: message, code: code);

/// Exhaustive switch with no default branch. Adding an `AppException`
/// subtype without updating this switch is a compile error.
String _label(AppException exception) => switch (exception) {
  ServerException() => 'server',
  UnauthorizedException() => 'unauthorized',
  NetworkException() => 'network',
  CacheException() => 'cache',
  ParsingException() => 'parsing',
};

void main() {
  const Map<String, AppException Function(String)> messageOnly =
      <String, AppException Function(String)>{
        'NetworkException': NetworkException.new,
        'CacheException': CacheException.new,
        'ParsingException': ParsingException.new,
      };

  group('ServerException', () {
    test('is an AppException and an Exception', () {
      expect(_server(), isA<AppException>());
      expect(_server(), isA<Exception>());
    });

    test('statusCode and code default to null', () {
      final ServerException e = _server();

      expect(e.statusCode, isNull);
      expect(e.code, isNull);
    });

    test('is equal when all fields match', () {
      final ServerException a = _server(statusCode: 429, code: 'rateLimited');
      final ServerException b = _server(statusCode: 429, code: 'rateLimited');

      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('is not equal when message differs', () {
      expect(_server(message: 'boom'), isNot(equals(_server(message: 'bang'))));
    });

    test('is not equal when statusCode differs', () {
      expect(_server(statusCode: 500), isNot(equals(_server(statusCode: 503))));
    });

    test('is not equal when code differs', () {
      expect(
        _server(code: 'rateLimited'),
        isNot(equals(_server(code: 'parameterInvalid'))),
      );
    });

    test('props are [message, statusCode, code]', () {
      expect(
        _server(statusCode: 429, code: 'rateLimited').props,
        equals(<Object?>['boom', 429, 'rateLimited']),
      );
    });

    test('toFailure maps to ServerFailure keeping message and statusCode', () {
      expect(
        _server(statusCode: 503, code: 'unexpectedError').toFailure(),
        equals(const failures.ServerFailure('boom', statusCode: 503)),
      );
    });

    test('toFailure keeps a null statusCode', () {
      expect(
        _server().toFailure(),
        equals(const failures.ServerFailure('boom')),
      );
    });
  });

  group('UnauthorizedException', () {
    test('is an AppException and an Exception', () {
      expect(_unauthorized(), isA<AppException>());
      expect(_unauthorized(), isA<Exception>());
    });

    test('code defaults to null', () {
      expect(_unauthorized().code, isNull);
    });

    test('is equal when all fields match', () {
      final UnauthorizedException a = _unauthorized(code: 'apiKeyInvalid');
      final UnauthorizedException b = _unauthorized(code: 'apiKeyInvalid');

      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('is not equal when message differs', () {
      expect(
        _unauthorized(message: 'boom'),
        isNot(equals(_unauthorized(message: 'bang'))),
      );
    });

    test('is not equal when code differs', () {
      expect(
        _unauthorized(code: 'apiKeyInvalid'),
        isNot(equals(_unauthorized(code: 'apiKeyMissing'))),
      );
    });

    test('props are [message, code]', () {
      expect(
        _unauthorized(code: 'apiKeyMissing').props,
        equals(<Object?>['boom', 'apiKeyMissing']),
      );
    });

    test('toFailure maps to UnauthorizedFailure keeping message', () {
      expect(
        _unauthorized(code: 'apiKeyInvalid').toFailure(),
        equals(const failures.UnauthorizedFailure('boom')),
      );
    });
  });

  for (final MapEntry<String, AppException Function(String)> entry
      in messageOnly.entries) {
    final AppException Function(String) build = entry.value;

    group(entry.key, () {
      test('is an AppException and an Exception', () {
        expect(build('boom'), isA<AppException>());
        expect(build('boom'), isA<Exception>());
      });

      test('is equal when message matches', () {
        final AppException a = build('boom');
        final AppException b = build('boom');

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
    });
  }

  group('toFailure for message-only exceptions', () {
    test('NetworkException maps to NetworkFailure', () {
      expect(
        messageOnly['NetworkException']!('boom').toFailure(),
        equals(const failures.NetworkFailure('boom')),
      );
    });

    test('CacheException maps to CacheFailure', () {
      expect(
        messageOnly['CacheException']!('boom').toFailure(),
        equals(const failures.CacheFailure('boom')),
      );
    });

    test('ParsingException maps to UnexpectedFailure', () {
      expect(
        messageOnly['ParsingException']!('boom').toFailure(),
        equals(const failures.UnexpectedFailure('boom')),
      );
    });
  });

  group('AppException hierarchy', () {
    test('different subtypes with the same message are not equal', () {
      final List<AppException> all = <AppException>[
        _server(message: 'same'),
        _unauthorized(message: 'same'),
        ...messageOnly.values.map(
          (AppException Function(String) build) => build('same'),
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
      expect(_label(_server()), equals('server'));
      expect(_label(_unauthorized()), equals('unauthorized'));
      expect(_label(messageOnly['NetworkException']!('x')), equals('network'));
      expect(_label(messageOnly['CacheException']!('x')), equals('cache'));
      expect(_label(messageOnly['ParsingException']!('x')), equals('parsing'));
    });
  });
}
