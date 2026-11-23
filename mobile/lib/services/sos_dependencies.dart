import 'incident_service.dart';
import 'location_service.dart';

/// Everything the SOS screen needs, injected so it can be faked in tests.
class SosDependencies {
  const SosDependencies({
    required this.incidentService,
    required this.locationService,
    this.mockLocationService,
  });

  final IncidentService incidentService;
  final LocationService locationService;

  /// Developer-only mock GPS. Null in release builds: no mock object exists
  /// and the screen never offers the mock switch.
  final LocationService? mockLocationService;
}
