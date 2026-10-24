# CLAUDE.md — News Hub App

Rules for any AI assistant (or human) contributing to this repository.
**These rules override default behaviour. Read fully before every session.**

---

## 1. Project Snapshot

| Item | Decision |
|---|---|
| App | News Hub: browse headlines, view article detail, read offline |
| Language | Dart 3.x (null-safe, sealed classes, records, patterns) |
| Architecture | Feature-First Clean Architecture (Presentation / Domain / Data per feature) |
| State management | `flutter_bloc` (Bloc for event-driven flows, Cubit only for trivial UI state) |
| Routing | `go_router` (declarative, typed route constants, no `Navigator.push`) |
| Networking | `dio` + `retrofit` (generated API clients) + `dio_cache_interceptor` |
| Local storage | Hive CE (`hive_ce`, `hive_ce_flutter`, `hive_ce_generator`), the community continuation of Hive v2 |
| News source | NewsAPI.org (`/v2/top-headlines`, `/v2/everything`) |
| Result type | Custom sealed `Result<T>` in `core/result/` (no `fpdart`) |
| DI | `get_it` service locator with manual registration, one module per feature (no `injectable`) |
| Environments | `dev` only for now (`--dart-define-from-file=env/dev.json`). Staging/prod deferred until development is complete. |
| Logging | `logger` package behind an `AppLogger` abstraction |
| Equality | `equatable` for entities, states, events |
| Testing | `flutter_test`, `bloc_test`, `mocktail` |

---

## 2. Workflow Protocol (mandatory)

Every task follows this loop. No step may be skipped.

1. **PLAN** — Before writing code, post an implementation plan containing:
   - Goal of the task in one sentence.
   - Exact files to be created/modified (full paths).
   - Contracts/interfaces introduced and their signatures.
   - Tests to be written and what each asserts.
   - New dependencies (name + reason).
   - Risks / open questions.
2. **WAIT FOR APPROVAL** — Do not proceed until the owner replies with explicit approval. Silence is not approval.
3. **IMPLEMENT ONE FILE (OR ONE LAYER) AT A TIME** — One file per response by default. Never dump multi-file snippets. Each file is delivered complete, never as fragments with "…rest unchanged".
4. **TEST FIRST WHERE APPLICABLE** — For domain and data logic: write the failing test, then the implementation (Red → Green → Refactor).
5. **VERIFY** — After each file, state the command to verify it (`flutter analyze`, `flutter test path/to/test.dart`, `dart run build_runner build`).
6. **CHECKPOINT** — Summarise what changed and name the next file. Wait for go-ahead.

If a plan must change mid-task, stop and re-plan. Do not silently deviate.

---

## 3. Architecture Rules

### 3.1 Layer dependency rule
```
presentation ──► domain ◄── data
                   ▲
                 core (shared, framework-agnostic utilities)
```
- **Domain** is pure Dart. No imports of `flutter`, `dio`, `hive_ce`, `retrofit`, `json_annotation`.
- **Data** depends on Domain (implements its contracts). Never imported by Presentation.
- **Presentation** depends only on Domain (use cases + entities) and `core/`.
- Features never import another feature's internals. Cross-feature needs go through `core/` or a shared domain contract.

### 3.2 Contracts before concretions
Order of creation for any feature:
1. Domain entity
2. Abstract repository (domain)
3. Use case(s) + tests (with mocked repository)
4. Abstract data source contracts (remote + local)
5. Models/DTOs + mappers + tests
6. Concrete data sources + tests
7. Repository implementation + tests
8. BLoC (events, states, bloc) + `bloc_test` tests
9. Widgets / pages + widget tests
10. DI registration + route registration

### 3.3 Models vs Entities
- **Entities** (domain): immutable, `Equatable`, no serialization logic.
- **Models/DTOs** (data): JSON / persistence annotations, `toEntity()` / `fromEntity()` mappers.
- Never leak a Model into Presentation.

### 3.4 Error handling
- Data layer **throws** typed `AppException` subclasses (`ServerException`, `NetworkException`, `CacheException`, `ParsingException`).
- Repository implementations **catch** exceptions and return `Result<T>` (sealed: `Success<T>` / `Failure<T>`) carrying a domain `Failure` object.
- **Naming clash rule:** `Result<T>`'s error variant and the domain error base class are both called `Failure`, by design. Any file that needs both imports the domain failures with the prefix `failures`:
  ```dart
  import 'package:news_hub/core/error/failures.dart' as failures;
  import 'package:news_hub/core/result/result.dart';

  return Failure<PaginatedArticles>(failures.ServerFailure(message));
  ```
  Unprefixed `Failure` therefore always means the `Result` variant. `result.dart` itself follows the same rule.
- Use cases and BLoCs never use `try/catch` for flow control; they pattern-match on `Result`.
- `DioException` is converted to `AppException` exclusively in `ErrorInterceptor`. No other file inspects `DioException`.

### 3.5 Offline strategy
- Repository decides source: **network-first with cache fallback** for the feed; **cache-first** for saved/bookmarked articles.
- Every successful remote fetch is persisted locally before being returned.
- Connectivity is checked through an injected `NetworkInfo` contract (mockable).

---

## 4. Coding Standards

### 4.1 Typing — zero tolerance for `dynamic`
- No `dynamic` anywhere in hand-written code. Use explicit types, generics, or `Object?` when genuinely unknown, then narrow with pattern matching.
- JSON maps are typed `Map<String, Object?>`.
- Every public function, method, field, and parameter has an explicit type. No `var` for public fields; `final` with explicit type preferred.
- Generated code (`*.g.dart`) is exempt but excluded from manual edits.

### 4.2 `analysis_options.yaml` (enforced)
The file at the project root is the source of truth. Summary:
- Base: `package:flutter_lints/flutter.yaml`.
- Language: `strict-casts`, `strict-inference`, `strict-raw-types`.
- **Errors (fail analysis):** `avoid_dynamic_calls`, `avoid_annotating_with_dynamic`, `avoid_print`, `always_declare_return_types`, `type_annotate_public_apis`, `unawaited_futures`, `discarded_futures`.
- Also on: `prefer_final_fields`, `prefer_final_locals`, `prefer_const_*`, `sort_constructors_first`, `directives_ordering`, `always_use_package_imports`.
- Off on purpose: `require_trailing_commas` (owned by `dart format`), `omit_local_variable_types` (locals may be inferred or explicit).
- Excluded: `**/*.g.dart`.

Run `dart format .` before `flutter analyze`. `flutter analyze` must report **zero issues** before a file is considered done.

### 4.3 Logging
- `print()` and `debugPrint()` are forbidden.
- Use the injected `AppLogger` (wrapping `logger`). Levels: `debug` (dev diagnostics), `info` (lifecycle), `warning` (recoverable), `error` (with error + stackTrace).
- Never log secrets, API keys, or full response bodies in release builds.

### 4.4 Naming & files
- Files: `snake_case.dart`. One public class per file (sealed-class families may share a file with `part`).
- Entities use plain nouns with no suffix (`article.dart`). Other files use suffixes: `*_model.dart`, `*_repository.dart`, `*_repository_impl.dart`, `*_remote_data_source.dart`, `*_local_data_source.dart`, `*_bloc.dart`, `*_event.dart`, `*_state.dart`, `*_page.dart`, `*_view.dart`, `*_widget.dart` only when ambiguous.
- Use cases are verbs: `GetTopHeadlines`, `SearchArticles`, `BookmarkArticle`. Each exposes a single `call()`.
- Abstract contracts carry the clean name (`NewsRepository`); implementations add `Impl`.

### 4.5 BLoC conventions
- Events and states are `sealed` classes extending `Equatable`.
- States represent the screen, e.g. `NewsFeedInitial`, `NewsFeedLoading`, `NewsFeedLoaded`, `NewsFeedFailure`.
- Use event transformers (`bloc_concurrency`) for debounce/drop/restartable where relevant (search, pagination).
- BLoCs receive use cases via constructor; never construct dependencies internally.
- No `BuildContext` inside BLoCs. No business logic inside widgets.

### 4.6 Widgets & performance
- Prefer `const` constructors; extract widgets instead of helper methods returning widgets.
- Use `BlocSelector` / `buildWhen` to limit rebuilds.
- Lists use `ListView.builder` / slivers with stable `Key`s.
- Images via `cached_network_image` with sized placeholders.

---

## 5. Testing Rules

- `test/` mirrors `lib/` exactly.
- Mocks with `mocktail`; register fallback values in `setUpAll`.
- Minimum per feature: use case tests, mapper/model tests (with JSON fixtures in `test/fixtures/`), data source tests, repository tests (online/offline/error branches), bloc tests, key widget tests.
- Tests must be deterministic: no real network, no real clock (inject `Clock`/time provider where needed).
- Coverage target: ≥ 90% for domain and data, ≥ 80% for presentation logic.

---

## 6. Dependencies Policy

- No new package without listing it in the plan with justification.
- Pin versions with caret constraints in `pubspec.yaml`; verify latest stable on pub.dev at scaffold time.
- Add packages with `flutter pub add` so the resolver picks the latest compatible versions; never hand-type version numbers from memory.
- Code generation: `dart run build_runner build --delete-conflicting-outputs`. **Generated files (`*.g.dart`) are committed.** Regenerate and commit them in the same change as the source file they belong to. Never edit them by hand.

---

## 7. Secrets & Config

- **Current scope: development only.** One environment file, `env/dev.json` (gitignored), with a committed `env/dev.example.json` template.
- Run with `flutter run --dart-define-from-file=env/dev.json`.
- No native flavors (Android `productFlavors`, iOS schemes) until staging/prod are planned. To keep that later step cheap, `AppConfig` still carries a `flavor` value and the base URL is config, not code.
- Values are read once into a typed, immutable `AppConfig` (`flavor`, `apiBaseUrl`, `apiKey`, `enableHttpLogging`, log level). No other file reads `String.fromEnvironment`.
- **NewsAPI licensing:** the free Developer key is licensed for development only and may not be used in staging or production. Staging and prod need a paid key or, preferably, our own backend proxy that holds the key. `AppConfig.apiBaseUrl` is configurable per flavor so prod can point at a proxy without code changes.
- Anything compiled into the app can be extracted from the binary, so a NewsAPI key in a prod build is not a secret.

---

## 8. Definition of Done (per file)

- [ ] Plan approved
- [ ] Test written first (domain/data) and passing
- [ ] `flutter analyze` → 0 issues
- [ ] No `dynamic`, no `print`
- [ ] Explicit types on all public APIs
- [ ] Owner approved before moving to the next file