import 'package:equatable/equatable.dart';
import 'package:news_hub/core/error/failures.dart' as failures;

/// Outcome of a repository call: either a [Success] carrying a value or a
/// [Failure] carrying a domain `failures.Failure` (D3).
///
/// Repositories return it; use cases pass it through; BLoCs consume it with
/// pattern matching, for example:
///
/// ```dart
/// switch (result) {
///   Success(:final value) => ...,
///   Failure(:final failure) => ...,
/// }
/// ```
///
/// Naming: the error variant is called `Failure`, like the domain base class.
/// Domain failures are always imported `as failures` (CLAUDE.md §3.4, D8).
///
/// Equality includes the type argument, so `Success<int>(1)` is not equal to
/// `Success<num>(1)`. Mock stubs must return the exact `Result<T>` type.
sealed class Result<T> extends Equatable {
  const Result();

  /// Collapses both variants into one value. Exactly one callback runs.
  R fold<R>({
    required R Function(T value) onSuccess,
    required R Function(failures.Failure failure) onFailure,
  }) => switch (this) {
    Success<T>(:final T value) => onSuccess(value),
    Failure<T>(:final failures.Failure failure) => onFailure(failure),
  };

  /// Transforms a success value. A [Failure] passes through unchanged as
  /// `Failure<R>`, and [transform] is not called.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
    Success<T>(:final T value) => Success<R>(transform(value)),
    Failure<T>(:final failures.Failure failure) => Failure<R>(failure),
  };
}

/// The call succeeded with [value].
final class Success<T> extends Result<T> {
  const Success(this.value);

  final T value;

  @override
  List<Object?> get props => <Object?>[value];
}

/// The call failed with a domain [failure].
final class Failure<T> extends Result<T> {
  const Failure(this.failure);

  final failures.Failure failure;

  @override
  List<Object?> get props => <Object?>[failure];
}
