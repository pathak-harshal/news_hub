import 'package:equatable/equatable.dart';
import 'package:news_hub/core/error/failures.dart' as failures;

/// Typed error thrown by the data layer (data sources, interceptors).
///
/// Never crosses into domain or presentation: repositories catch it and
/// return `Result<T>` carrying [AppExceptionMapping.toFailure].
///
/// `DioException` is converted into these only in `error_interceptor.dart`
/// (CLAUDE.md §3.4, D10). Config errors use `FormatException` instead.
///
/// [message] is diagnostic text for logs and must never contain secrets.
sealed class AppException extends Equatable implements Exception {
  const AppException(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}

/// The server answered with an error status (for example 400, 429 or 5xx),
/// or the request failed for a reason that is not connectivity-related.
final class ServerException extends AppException {
  const ServerException({required String message, this.statusCode, this.code})
    : super(message);

  /// HTTP status code, when one was received.
  final int? statusCode;

  /// NewsAPI error code from the response body, e.g. `rateLimited`.
  final String? code;

  @override
  List<Object?> get props => <Object?>[message, statusCode, code];
}

/// The API rejected our credentials (HTTP 401).
final class UnauthorizedException extends AppException {
  const UnauthorizedException({required String message, this.code})
    : super(message);

  /// NewsAPI error code, e.g. `apiKeyInvalid`, `apiKeyMissing`.
  final String? code;

  @override
  List<Object?> get props => <Object?>[message, code];
}

/// No connection, a timeout, a bad certificate, or a cancelled request.
final class NetworkException extends AppException {
  const NetworkException(super.message);
}

/// Reading from or writing to local storage (Hive) failed.
final class CacheException extends AppException {
  const CacheException(super.message);
}

/// A response or stored record could not be parsed into our models.
final class ParsingException extends AppException {
  const ParsingException(super.message);
}

/// The single mapping point from data-layer exceptions to domain failures.
///
/// The switch is exhaustive with no default branch, so a new [AppException]
/// subtype does not compile until it is mapped here. HTTP and NewsAPI
/// details (`code`) deliberately stay in the data layer.
extension AppExceptionMapping on AppException {
  failures.Failure toFailure() => switch (this) {
    ServerException(:final int? statusCode) => failures.ServerFailure(
      message,
      statusCode: statusCode,
    ),
    UnauthorizedException() => failures.UnauthorizedFailure(message),
    NetworkException() => failures.NetworkFailure(message),
    CacheException() => failures.CacheFailure(message),
    ParsingException() => failures.UnexpectedFailure(message),
  };
}
