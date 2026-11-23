import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'app.dart';
import 'core/config/api_config.dart';
import 'core/config/app_config.dart';
import 'screens/config_error_screen.dart';
import 'services/auth_service.dart';
import 'services/incident_service.dart';
import 'services/location_service.dart';
import 'services/session_controller.dart';
import 'services/sos_dependencies.dart';
import 'services/token_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Fail fast: a release/profile build without an https API_BASE_URL never
  // starts the app (no login, no network).
  final String baseUrl;
  try {
    baseUrl = AppConfig.apiBaseUrl;
  } on ApiConfigException catch (e) {
    runApp(ConfigErrorApp(message: e.message));
    return;
  }

  final session = SessionController(
    authService: AuthService(
      client: http.Client(),
      baseUrl: baseUrl,
    ),
    storage: SecureTokenStorage(),
  );
  // Task 02's authenticated client: Bearer header + sign-out on 401.
  final apiClient = session.authenticatedClient(http.Client());

  runApp(CoastGuardApp(
    sessionController: session,
    sos: SosDependencies(
      incidentService: IncidentService(
        client: apiClient,
        baseUrl: baseUrl,
      ),
      locationService: GeolocatorLocationService(),
      // Debug builds only; in release no mock object is created and the
      // MOCK_* values are tree-shaken out.
      mockLocationService: kDebugMode
          ? const MockLocationService(
              latitude: AppConfig.mockLatitude,
              longitude: AppConfig.mockLongitude,
            )
          : null,
    ),
  ));
}
