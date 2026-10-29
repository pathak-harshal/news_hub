import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:mocktail/mocktail.dart';
import 'package:news_hub/core/logging/app_logger.dart';

/// Shared mocktail mocks for every abstract contract and external
/// dependency (CLAUDE.md §5). Add new mocks here as contracts appear,
/// grouped by layer and kept in alphabetical order within each group.
///
/// Fallback values for `any()` matchers are registered in each test's
/// `setUpAll`, not here, so every test states what it relies on.

// ---- core ----

class MockAppLogger extends Mock implements AppLogger {}

// ---- external packages ----

class MockConnectivity extends Mock implements Connectivity {}
