import 'package:equatable/equatable.dart';
import 'package:news_hub/core/result/result.dart';

/// Shared shape of every use case: a callable class taking [P] and
/// completing with a `Result<T>`.
///
/// ```dart
/// final class GetTopHeadlines
///     implements UseCase<PaginatedArticles, GetTopHeadlinesParams> { ... }
///
/// final Result<PaginatedArticles> result = await getTopHeadlines(params);
/// ```
///
/// Use cases pass the repository's `Result` through. They never use
/// `try/catch` for flow control (CLAUDE.md §3.4). Each use case's params
/// class lives in the same file as the use case (CLAUDE.md §4.4).
///
/// Type parameters are `T`/`P` rather than `Type`/`Params` so that
/// `dart:core`'s `Type` is not shadowed.
abstract interface class UseCase<T, P> {
  Future<Result<T>> call(P params);
}

/// Parameter value for use cases that take no input.
final class NoParams extends Equatable {
  const NoParams();

  @override
  List<Object?> get props => const <Object?>[];
}
