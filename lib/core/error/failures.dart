import 'package:equatable/equatable.dart';

/// Domain-facing error returned inside `Result<T>`'s `Failure` variant.
///
/// Pure Dart: safe to import from the domain layer. Produced only by
/// repositories, via `AppException.toFailure()` or as a catch-all
/// [UnexpectedFailure].
///
/// [message] is diagnostic text for logs. Presentation chooses user-facing
/// copy by failure type and never shows [message] raw.
///
/// Naming: outside this file, import it `as failures` so that an unprefixed
/// `Failure` always means the `Result` variant (CLAUDE.md §3.4, D8).
sealed class Failure extends Equatable {
  const Failure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

/// The server answered with an error status (for example 400, 429 or 5xx),
/// or the request failed for a reason that is not connectivity-related.
final class ServerFailure extends Failure {
  const ServerFailure(super.message, {this.statusCode});

  /// HTTP status code, when one was received.
  final int? statusCode;

  @override
  List<Object?> get props => <Object?>[message, statusCode];
}

/// The API rejected our credentials (HTTP 401), for example a missing,
/// invalid or disabled NewsAPI key.
final class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure(super.message);
}

/// No connection, a timeout, or a cancelled request.
final class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// Reading from or writing to local storage failed.
final class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

/// Anything not covered above, including malformed data that could not be
/// parsed into our models.
final class UnexpectedFailure extends Failure {
  const UnexpectedFailure(super.message);
}
