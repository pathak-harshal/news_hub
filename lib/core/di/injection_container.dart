import 'package:get_it/get_it.dart';
import 'package:news_hub/core/config/app_config.dart';
import 'package:news_hub/core/di/core_module.dart';

/// The app-wide service locator.
final GetIt getIt = GetIt.instance;

/// Registers every dependency into [container], or into the global [getIt]
/// when no container is given.
///
/// Async because storage initialisation (Step 17a) will be awaited here.
/// [AppConfig.fromEnvironment] is called by `bootstrap.dart`, never here.
Future<void> initDependencies({
  required AppConfig config,
  GetIt? container,
}) async {
  registerCoreModule(container ?? getIt, config: config);
}
