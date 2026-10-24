# project-structure.md — News Hub App Blueprint

Status: **APPROVED (2026-10-24).** Decisions recorded in §6.

---

## 1. Root Layout

```
news_hub/
├── CLAUDE.md
├── project-structure.md
├── analysis_options.yaml
├── pubspec.yaml
├── build.yaml                      # build_runner config (retrofit, json_serializable, hive_ce)
├── env/
│   ├── dev.example.json            # committed template (FLAVOR, API_BASE_URL, API_KEY, ENABLE_HTTP_LOGGING)
│   └── dev.json                    # gitignored
│                                   # staging/prod env files + native flavors: deferred (see §6 D7)
├── lib/
│   ├── main.dart                   # entry: bootstraps DI, then runApp
│   ├── app.dart                    # MaterialApp.router, theme, global BlocProviders
│   ├── bootstrap.dart              # async init: config, logger, storage, DI, error zones
│   ├── core/
│   └── features/
│       └── news_feed/
└── test/
    ├── fixtures/
    ├── helpers/
    ├── core/
    └── features/
        └── news_feed/
```

---

## 2. `lib/core/` — Shared, Feature-Agnostic Infrastructure

```
lib/core/
├── config/
│   ├── flavor.dart                 # enum Flavor — only `dev` used today; staging/prod added when D7 is revisited
│   ├── app_config.dart             # typed env values read from --dart-define (only reader of String.fromEnvironment)
│   └── app_constants.dart          # page sizes, timeouts, cache TTLs
│
├── di/
│   ├── injection_container.dart    # getIt instance + initDependencies()
│   └── core_module.dart            # registers logger, dio, storage, network info
│
├── error/
│   ├── exceptions.dart             # sealed AppException: Server, Network, Cache, Parsing, Unauthorized
│   └── failures.dart               # sealed Failure (domain-facing): ServerFailure, NetworkFailure, CacheFailure, UnexpectedFailure
│
├── result/
│   └── result.dart                 # sealed Result<T> { Success<T>, Failure<T> } + fold/map helpers (imports failures.dart `as failures`, see D8)
│
├── logging/
│   ├── log_level.dart              # our own LogLevel enum (debug/info/warning/error); keeps `logger` out of config
│   ├── app_logger.dart             # abstract AppLogger contract (mockable)
│   └── app_logger_impl.dart        # wraps `logger` package; level by flavor
│
├── network/
│   ├── dio_client.dart             # Dio factory: base options, timeouts, interceptor chain order
│   ├── network_info.dart           # abstract NetworkInfo + impl (connectivity_plus)
│   ├── api_endpoints.dart          # endpoint path constants
│   ├── cache/
│   │   └── http_cache_config.dart  # dio_cache_interceptor CacheOptions + store
│   └── interceptors/
│       ├── api_key_interceptor.dart    # injects API key header/query param
│       ├── logging_interceptor.dart    # request/response logging via AppLogger (redacts secrets)
│       ├── error_interceptor.dart      # DioException → AppException (single mapping point)
│       └── retry_interceptor.dart      # bounded retry with backoff for idempotent GETs
│
├── storage/
│   ├── local_database.dart         # abstract LocalDatabase contract (open/close/clear)
│   ├── local_database_impl.dart    # Hive.initFlutter, registerAdapters(), opens boxes
│   ├── hive_box_names.dart         # box name constants (articles_cache, bookmarks)
│   ├── hive_adapters.dart          # @GenerateAdapters([...]) — single source of type IDs
│   ├── hive_adapters.g.dart        # generated adapters (committed)
│   └── hive_registrar.g.dart       # generated registerAdapters() extension (committed)
│
├── router/
│   ├── app_router.dart             # GoRouter configuration
│   ├── route_names.dart            # typed route name/path constants
│   └── router_observer.dart        # logs navigation via AppLogger
│
├── theme/
│   ├── app_theme.dart
│   ├── app_colors.dart
│   └── app_text_styles.dart
│
├── usecase/
│   └── usecase.dart                # abstract UseCase<Type, Params> + NoParams
│
├── utils/
│   ├── date_formatter.dart
│   └── bloc_observer.dart          # AppBlocObserver → AppLogger
│
└── widgets/                        # truly shared UI only
    ├── app_error_view.dart
    ├── app_loading_indicator.dart
    └── app_network_image.dart
```

**Interceptor order** (defined in `dio_client.dart`):
`ApiKey → Cache → Retry → Logging → Error`
(Error last so every failure, including retried ones, is mapped once.)

---

## 3. `lib/features/news_feed/` — First Feature

```
lib/features/news_feed/
├── domain/                                   # pure Dart — no Flutter/Dio/DB imports
│   ├── entities/
│   │   ├── article.dart                      # id, title, description, content, url, imageUrl, source, author, publishedAt
│   │   ├── article_source.dart
│   │   └── paginated_articles.dart           # items, page, hasMore
│   ├── repositories/
│   │   └── news_repository.dart              # ABSTRACT contract (written first, mock target)
│   └── usecases/
│       ├── get_top_headlines.dart            # (category, page) → Result<PaginatedArticles>
│       ├── search_articles.dart              # (query, page)    → Result<PaginatedArticles>
│       ├── get_cached_articles.dart          # ()               → Result<List<Article>>
│       └── toggle_bookmark.dart              # (Article)        → Result<bool>
│
├── data/
│   ├── datasources/
│   │   ├── news_remote_data_source.dart      # ABSTRACT contract
│   │   ├── news_remote_data_source_impl.dart # delegates to Retrofit NewsApiService
│   │   ├── news_local_data_source.dart       # ABSTRACT contract
│   │   └── news_local_data_source_impl.dart  # Hive box reads & writes (keyed by article URL)
│   ├── api/
│   │   └── news_api_service.dart             # @RestApi Retrofit interface (+ .g.dart)
│   ├── models/
│   │   ├── article_model.dart                # json_serializable DTO + toEntity()
│   │   ├── article_source_model.dart
│   │   ├── news_response_model.dart          # API envelope: status, totalResults, articles
│   │   └── article_local_model.dart          # plain Dart class; adapter generated via core/storage/hive_adapters.dart
│   ├── mappers/
│   │   └── article_mapper.dart               # DTO ↔ Entity ↔ Local model
│   └── repositories/
│       └── news_repository_impl.dart         # network-first, cache fallback, returns Result<T>
│
├── presentation/
│   ├── bloc/
│   │   ├── news_feed/
│   │   │   ├── news_feed_bloc.dart
│   │   │   ├── news_feed_event.dart          # sealed: Started, Refreshed, NextPageRequested, CategoryChanged
│   │   │   └── news_feed_state.dart          # sealed: Initial, Loading, Loaded(articles, hasMore, isOffline), Failure
│   │   └── article_detail/
│   │       ├── article_detail_cubit.dart     # bookmark toggle only
│   │       └── article_detail_state.dart
│   ├── pages/
│   │   ├── news_feed_page.dart               # BlocProvider + NewsFeedView
│   │   └── article_detail_page.dart
│   └── widgets/
│       ├── news_feed_view.dart
│       ├── article_list_tile.dart
│       ├── category_chips.dart
│       └── offline_banner.dart
│
└── news_feed_injection.dart                  # registers this feature's deps in getIt
```

Search and Bookmarks start inside `news_feed` as use cases. If either grows its own screen + bloc, it is promoted to `features/search/` or `features/bookmarks/` (planned separately).

---

## 4. `test/` — Mirrors `lib/`

```
test/
├── fixtures/
│   ├── fixture_reader.dart                   # String fixture(String name)
│   ├── top_headlines_response.json
│   ├── empty_response.json
│   └── error_response.json
├── helpers/
│   ├── mocks.dart                            # mocktail mocks for every abstract contract
│   └── pump_app.dart                         # widget-test harness (theme, router, providers)
├── core/
│   ├── network/interceptors/error_interceptor_test.dart
│   ├── network/network_info_test.dart
│   └── result/result_test.dart
└── features/news_feed/
    ├── domain/usecases/
    │   ├── get_top_headlines_test.dart
    │   ├── search_articles_test.dart
    │   ├── get_cached_articles_test.dart
    │   └── toggle_bookmark_test.dart
    ├── data/
    │   ├── models/article_model_test.dart
    │   ├── mappers/article_mapper_test.dart
    │   ├── datasources/news_remote_data_source_impl_test.dart
    │   ├── datasources/news_local_data_source_impl_test.dart
    │   └── repositories/news_repository_impl_test.dart   # online / offline / server error / cache error
    └── presentation/
        ├── bloc/news_feed_bloc_test.dart
        ├── bloc/article_detail_cubit_test.dart
        └── widgets/article_list_tile_test.dart
```

---

## 5. Build Order (one file per step, each behind an approval gate)

**Phase 0 — Scaffold**
1. ✅ `pubspec.yaml` (dependencies only) — closed 2026-10-24 (Flutter 3.47.7 / Dart 3.13.5)
2. ✅ `analysis_options.yaml` — closed 2026-10-24
3. ✅ `.gitignore` + `env/dev.example.json` — closed 2026-10-24
3a. ✅ `core/config/flavor.dart` → `core/logging/log_level.dart` → `core/config/app_config.dart` + tests — closed 2026-10-24 (Phase 0 complete)

**Phase 1 — Core primitives (TDD)**
4. `core/error/exceptions.dart`, `core/error/failures.dart`
5. `core/result/result.dart` + test
6. `core/logging/app_logger.dart` → `app_logger_impl.dart`
7. `core/usecase/usecase.dart`

**Phase 2 — Core infrastructure**
8. `core/network/network_info.dart` + test
9. Interceptors (one per step), `error_interceptor` test-first
10. `core/network/dio_client.dart`
11. `core/storage/local_database.dart` → impl
12. `core/router/*`, `core/di/*`

**Phase 3 — news_feed (contracts before concretions)**
13. Entities → 14. `news_repository.dart` (abstract) → 15. Use cases + tests
16. Data source contracts → 17. Models + mappers + fixtures + tests
18. Retrofit service → 19. Remote/local data source impls + tests
20. `news_repository_impl.dart` + tests
21. Bloc events/states → bloc + `bloc_test`
22. Widgets → pages → widget tests
23. `news_feed_injection.dart` + route registration → app runs end-to-end

---

## 6. Decisions Log

| # | Decision | Outcome | Consequence for the codebase |
|---|---|---|---|
| D1 | Local storage | **Hive CE** (`hive_ce` + `hive_ce_flutter` + `hive_ce_generator`) | Adapters generated from one `@GenerateAdapters` list in `core/storage/`. Articles keyed by URL, because NewsAPI articles have no ID field. |
| D2 | News API | **NewsAPI.org** | Free key is dev-only, so staging/prod need a paid key or a backend proxy. `apiBaseUrl` is configurable per flavor. |
| D3 | Result type | **Custom sealed `Result<T>`** | No `fpdart` dependency. |
| D4 | DI | **`get_it`, manual registration** | `core_module.dart` + one `*_injection.dart` per feature. |
| D5 | Equality | **`equatable`** | Hand-written `copyWith` where needed. No `freezed`. |
| D6 | Generated files | **Committed** | `*.g.dart` is not in `.gitignore`. Analyzer still excludes it. |
| D7 | Environments | **dev only for now; staging/prod revisited after development** | No native flavors in Phase 0. When revisited: add env files, Android `productFlavors`, iOS schemes, and resolve the NewsAPI licensing question (paid key or backend proxy). |
| D8 | `Result` vs domain `Failure` name clash | **Keep both names; resolve with import aliases** | `Result<T>` = `Success<T>` / `Failure<T>`. Domain failures are imported `as failures` wherever both are used (`failures.ServerFailure`). Unprefixed `Failure` always means the `Result` variant. Rule recorded in CLAUDE.md §3.4. |