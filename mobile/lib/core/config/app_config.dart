import 'package:flutter/foundation.dart' show kDebugMode;

import 'api_config.dart';

/// Build-time configuration.
///
/// API_BASE_URL (--dart-define):
///   * Debug builds: optional. Default is the laptop backend over the hotspot
///     (http://172.20.10.2:8080/api/v1). Plain http is allowed.
///   * Release AND profile builds: REQUIRED and must be https://. Otherwise
///     the app shows a configuration-error screen and never contacts a server.
/// Emulator, debug build:
///   --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1
/// Physical phone: use its host laptop's reachable hotspot address. Debug
/// cleartext is allowed only to 10.0.2.2 and 172.20.10.2.
///
/// Mock GPS (debug builds only) uses coordinates supplied at build time:
/// --dart-define=MOCK_LATITUDE=<lat> --dart-define=MOCK_LONGITUDE=<lng>
/// No default is provided on purpose; the team confirms the demo point.
class AppConfig {
  AppConfig._();

  static const String _rawApiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Validated base URL. Throws [ApiConfigException] when it is missing or
  /// not https outside debug builds.
  static String get apiBaseUrl => ApiConfig.resolve(
        rawValue: _rawApiBaseUrl,
        allowLocalHttp: kDebugMode,
      );

  static const String mockLatitude = String.fromEnvironment('MOCK_LATITUDE');
  static const String mockLongitude = String.fromEnvironment('MOCK_LONGITUDE');
}
