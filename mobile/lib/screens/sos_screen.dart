import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/geo_point.dart';
import '../models/incident.dart';
import '../services/incident_service.dart';
import '../services/location_service.dart';
import '../services/sos_dependencies.dart';
// N1's SOS form component (agreed interface).
import '../widgets/sos_form_widget.dart';
import 'sos_confirmation_screen.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({
    super.key,
    required this.dependencies,
    this.showMockGpsSwitch = kDebugMode,
  });

  final SosDependencies dependencies;

  /// Developer-only mock GPS switch; defaults to debug builds only.
  final bool showMockGpsSwitch;

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  bool _isSubmitting = false;
  bool _useMock = false;
  String? _errorMessage;

  Future<void> _submit(SosFormData data) async {
    // Synchronous guard: rapid repeated taps can never start two submissions.
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final deps = widget.dependencies;
    final showMock = widget.showMockGpsSwitch;
    // Mock GPS only when the debug switch is shown, switched on, AND a mock
    // service was provided (main.dart provides none in release builds).
    final mock = deps.mockLocationService;
    final LocationService source =
        (_useMock && showMock && mock != null) ? mock : deps.locationService;

    String? error;
    Incident? incident;
    try {
      final GeoPoint location = await source.getCurrentLocation();
      incident = await deps.incidentService.createIncident(
        type: data.type.trim().toUpperCase(),
        peopleCount: data.peopleCount,
        note: data.note,
        location: location,
      );
    } on LocationException catch (e) {
      error = e.message;
    } on IncidentException catch (e) {
      // On 401 the session handler returns the user to login with its own
      // message; a second, differently worded one here would duplicate it.
      error = e.type == IncidentErrorType.unauthorized ? null : e.message;
    } catch (_) {
      error = 'Something went wrong. Please try again.';
    }

    if (!mounted) return;
    if (incident != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => SosConfirmationScreen(
            incident: incident!,
            onSendAnother: (ctx) => Navigator.of(ctx).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) =>
                    SosScreen(dependencies: deps, showMockGpsSwitch: showMock),
              ),
            ),
          ),
        ),
      );
      return;
    }
    setState(() {
      _isSubmitting = false;
      _errorMessage = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    final mockAvailable = widget.showMockGpsSwitch &&
        widget.dependencies.mockLocationService != null;
    final usingMock = _useMock && mockAvailable;
    // While sending, back navigation is blocked: leaving would hide the
    // result and make a delivered SOS look like it failed.
    return PopScope(
      canPop: !_isSubmitting,
      child: Scaffold(
      appBar: AppBar(
        title: const Text('Send SOS'),
        automaticallyImplyLeading: !_isSubmitting,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _LocationModeBanner(usingMock: usingMock),
              const SizedBox(height: 8),
              if (mockAvailable)
                SwitchListTile(
                  key: const Key('mock_gps_switch'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Use mock GPS (debug only)'),
                  subtitle: const Text(
                      'Sends the fixed MOCK_LATITUDE / MOCK_LONGITUDE from --dart-define instead of your real position.'),
                  value: _useMock,
                  onChanged: _isSubmitting
                      ? null
                      : (v) => setState(() => _useMock = v),
                ),
              const SizedBox(height: 8),
              SosFormWidget(
                onSubmit: _submit,
                isSubmitting: _isSubmitting,
                errorMessage: _errorMessage,
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

/// Always visible: tells the user which position the SOS will carry.
class _LocationModeBanner extends StatelessWidget {
  const _LocationModeBanner({required this.usingMock});

  final bool usingMock;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final background =
        usingMock ? scheme.tertiaryContainer : scheme.secondaryContainer;
    final foreground =
        usingMock ? scheme.onTertiaryContainer : scheme.onSecondaryContainer;
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const Key('location_mode'),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(usingMock ? Icons.science_outlined : Icons.my_location,
                color: foreground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                usingMock
                    ? 'Location: MOCK GPS (debug build). Fixed test coordinates, not your real position.'
                    : "Location: your phone's GPS. It will be sent with your SOS.",
                style: Theme.of(context)
                    .textTheme
                    .bodyLarge
                    ?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
