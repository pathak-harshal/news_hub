import 'package:equatable/equatable.dart';
import 'package:news_hub/core/config/flavor.dart';
import 'package:news_hub/core/logging/log_level.dart';

/// Typed, validated, immutable app configuration.
///
/// Values come from `--dart-define-from-file=env/<flavor>.json` and are read
/// exactly once, at startup, via [AppConfig.fromEnvironment]. This is the
/// only place in the codebase that reads compile-time environment values
/// (CLAUDE.md §7).
///
/// Invalid or missing values throw a [FormatException] immediately, so a bad
/// config stops the app at launch instead of failing later with a 401.
final class AppConfig extends Equatable {
  const AppConfig({
    required this.flavor,
    required this.apiBaseUrl,
    required this.apiKey,
    required this.enableHttpLogging,
    required this.logLevel,
  });

  /// Reads the compile-time values passed with `--dart-define-from-file`.
  ///
  /// Only keys that were actually defined are forwarded, so optional keys
  /// that are absent fall back to their defaults in [AppConfig.fromMap].
  /// All parsing and validation lives in [AppConfig.fromMap], because
  /// compile-time values cannot be changed in tests.
  factory AppConfig.fromEnvironment() {
    const Map<String, String> values = <String, String>{
      if (bool.hasEnvironment(_flavorKey))
        _flavorKey: String.fromEnvironment(_flavorKey),
      if (bool.hasEnvironment(_apiBaseUrlKey))
        _apiBaseUrlKey: String.fromEnvironment(_apiBaseUrlKey),
      if (bool.hasEnvironment(_apiKeyKey))
        _apiKeyKey: String.fromEnvironment(_apiKeyKey),
      if (bool.hasEnvironment(_enableHttpLoggingKey))
        _enableHttpLoggingKey: String.fromEnvironment(_enableHttpLoggingKey),
      if (bool.hasEnvironment(_logLevelKey))
        _logLevelKey: String.fromEnvironment(_logLevelKey),
    };
    return AppConfig.fromMap(values);
  }

  /// Parses and validates raw environment [values].
  ///
  /// Throws a [FormatException] naming the offending key when a required
  /// value is missing or any value is invalid.
  factory AppConfig.fromMap(Map<String, String> values) {
    final Flavor flavor = Flavor.fromName(_require(values, _flavorKey));
    final Uri apiBaseUrl = _parseBaseUrl(_require(values, _apiBaseUrlKey));
    final String apiKey = _parseApiKey(_require(values, _apiKeyKey), flavor);

    final String? rawLogging = values[_enableHttpLoggingKey];
    final bool enableHttpLogging =
        rawLogging != null && _parseBool(_enableHttpLoggingKey, rawLogging);

    final String? rawLevel = values[_logLevelKey];
    final LogLevel logLevel = rawLevel == null
        ? LogLevel.info
        : LogLevel.fromName(rawLevel);

    return AppConfig(
      flavor: flavor,
      apiBaseUrl: apiBaseUrl,
      apiKey: apiKey,
      enableHttpLogging: enableHttpLogging,
      logLevel: logLevel,
    );
  }

  static const String _flavorKey = 'FLAVOR';
  static const String _apiBaseUrlKey = 'API_BASE_URL';
  static const String _apiKeyKey = 'API_KEY';
  static const String _enableHttpLoggingKey = 'ENABLE_HTTP_LOGGING';
  static const String _logLevelKey = 'LOG_LEVEL';

  /// The placeholder shipped in `env/*.example.json`.
  static const String _apiKeyPlaceholder = 'YOUR_NEWSAPI_KEY';

  final Flavor flavor;
  final Uri apiBaseUrl;
  final String apiKey;
  final bool enableHttpLogging;
  final LogLevel logLevel;

  @override
  List<Object?> get props => <Object?>[
    flavor,
    apiBaseUrl,
    apiKey,
    enableHttpLogging,
    logLevel,
  ];

  /// Safe to log: the API key is always redacted.
  @override
  String toString() =>
      'AppConfig(flavor: ${flavor.name}, apiBaseUrl: $apiBaseUrl, '
      'apiKey: <redacted>, enableHttpLogging: $enableHttpLogging, '
      'logLevel: ${logLevel.name})';

  static String _require(Map<String, String> values, String key) {
    final String? value = values[key];
    if (value == null) {
      throw FormatException(
        'Missing required config value $key. Add it to your env/<flavor>.json '
        '(see env/dev.example.json) and run with --dart-define-from-file.',
      );
    }
    return value;
  }

  static Uri _parseBaseUrl(String raw) {
    final Uri? uri = Uri.tryParse(raw);
    if (uri == null ||
        !uri.isAbsolute ||
        uri.scheme != 'https' ||
        uri.host.isEmpty) {
      throw FormatException(
        '$_apiBaseUrlKey must be an absolute https URL, got "$raw".',
      );
    }
    return uri;
  }

  static String _parseApiKey(String raw, Flavor flavor) {
    final String key = raw.trim();
    if (key.isEmpty) {
      throw FormatException(
        '$_apiKeyKey is empty. Put your NewsAPI key in '
        'env/${flavor.name}.json.',
      );
    }
    if (key == _apiKeyPlaceholder) {
      throw FormatException(
        '$_apiKeyKey is still the example placeholder. Replace it with your '
        'real NewsAPI key in env/${flavor.name}.json.',
      );
    }
    return key;
  }

  static bool _parseBool(String key, String raw) => switch (raw) {
    'true' => true,
    'false' => false,
    _ => throw FormatException('$key must be "true" or "false", got "$raw".'),
  };
}
