import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coastguard360_mobile/app.dart';
import 'package:coastguard360_mobile/models/geo_point.dart';
import 'package:coastguard360_mobile/screens/home_screen.dart';
import 'package:coastguard360_mobile/screens/login_screen.dart';
import 'package:coastguard360_mobile/screens/sos_screen.dart';
import 'package:coastguard360_mobile/services/incident_service.dart';
import 'package:coastguard360_mobile/services/location_service.dart';
import 'package:coastguard360_mobile/services/session_controller.dart';
import 'package:coastguard360_mobile/services/sos_dependencies.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/fakes.dart';

class Harness {
  Harness(this.session, this.storage, this.requests);
  final SessionController session;
  final FakeTokenStorage storage;
  final List<http.Request> requests;
}

/// Pumps the full app signed in (stored token) and opens the SOS screen.
Future<Harness> openSos(
  WidgetTester tester, {
  required Future<http.Response> Function(http.Request) handler,
  LocationService? location,
  LocationService? mock,
  bool provideMock = true,
  bool showMock = false,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final storage = FakeTokenStorage(token: 'tok');
  final session = makeSession(MockClient((_) async => loginOk()), storage);
  final requests = <http.Request>[];
  final api = session.authenticatedClient(MockClient((req) {
    requests.add(req);
    return handler(req);
  }));
  final deps = SosDependencies(
    incidentService:
        IncidentService(client: api, baseUrl: 'http://test.local/api/v1'),
    locationService: location ?? FakeLocationService(),
    mockLocationService: provideMock ? (mock ?? FakeLocationService()) : null,
  );

  // Build through the real app so navigation/session behaviour is covered.
  await tester.pumpWidget(CoastGuardApp(sessionController: session, sos: deps));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open_sos_button')));
  await tester.pumpAndSettle();
  if (showMock) {
    // Rebuild the screen with the debug switch visible (kDebugMode is false
    // in some test modes, so force it through the constructor).
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pushReplacement(MaterialPageRoute<void>(
        builder: (_) =>
            SosScreen(dependencies: deps, showMockGpsSwitch: true)));
    await tester.pumpAndSettle();
  }
  return Harness(session, storage, requests);
}

Future<void> chooseAndSend(WidgetTester tester, {String type = 'Drowning'}) async {
  await tester.tap(find.text(type));
  await tester.pump();
  await tester.tap(find.byKey(const Key('sos_submit_button')));
  await tester.pumpAndSettle();
}

Future<http.Response> created(http.Request _) async =>
    jsonResponse(incidentJson(), 201);

void main() {
  testWidgets('home shows SOS entry only when SOS is wired', (tester) async {
    final session = makeSession(
        MockClient((_) async => loginOk()), FakeTokenStorage(token: 't'));
    await tester.pumpWidget(CoastGuardApp(sessionController: session));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byKey(const Key('open_sos_button')), findsNothing);
  });

  testWidgets('successful SOS shows confirmation with id, status, zone',
      (tester) async {
    final h = await openSos(tester, handler: created);

    await tester.tap(find.byKey(const Key('people_increment')));
    await tester.enterText(find.byKey(const Key('note_field')), 'Near rocks');
    await chooseAndSend(tester);

    expect(find.text('SOS sent'), findsOneWidget);
    expect(find.text('Incident ID: 101'), findsOneWidget);
    expect(find.text('Status: REPORTED'), findsOneWidget);
    expect(find.text('Zone: North Beach High-Risk'), findsOneWidget);
    // Admin-only information is never shown to the tourist.
    expect(find.textContaining('Sea Pearl'), findsNothing);
    expect(find.textContaining('Rahim'), findsNothing);

    final req = h.requests.single;
    expect(req.url.path, '/api/v1/incidents');
    expect(req.headers['Authorization'], 'Bearer tok');
    expect(jsonDecode(req.body), {
      'type': 'DROWNING',
      'peopleCount': 2,
      'note': 'Near rocks',
      'location': {'lat': 21.4272, 'lng': 92.0058},
    });
  });

  testWidgets('FIRE with blank note omits note', (tester) async {
    final h = await openSos(tester, handler: created);
    await chooseAndSend(tester, type: 'Fire');

    final body = jsonDecode(h.requests.single.body) as Map<String, dynamic>;
    expect(body['type'], 'FIRE');
    expect(body.containsKey('note'), isFalse);
  });

  testWidgets('null zone: zone line is not shown', (tester) async {
    await openSos(tester,
        handler: (_) async => jsonResponse(incidentJson(withZone: false), 201));
    await chooseAndSend(tester);

    expect(find.text('SOS sent'), findsOneWidget);
    expect(find.textContaining('Zone:'), findsNothing);
  });

  testWidgets('confirmation: back to home and send another', (tester) async {
    await openSos(tester, handler: created);
    await chooseAndSend(tester);

    await tester.tap(find.byKey(const Key('send_another_button')));
    await tester.pumpAndSettle();
    expect(find.byType(SosScreen), findsOneWidget);
    expect(find.byKey(const Key('sos_submit_button')), findsOneWidget);

    await chooseAndSend(tester, type: 'Fire');
    await tester.tap(find.byKey(const Key('back_home_button')));
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('location permission denied: message shown, nothing sent',
      (tester) async {
    final h = await openSos(tester,
        handler: created,
        location: FakeLocationService(
            error: const LocationException(LocationErrorType.permissionDenied)));
    await chooseAndSend(tester);

    expect(find.textContaining('Location permission was denied'),
        findsOneWidget);
    expect(h.requests, isEmpty);
  });

  testWidgets('location timeout: message shown, can retry', (tester) async {
    final h = await openSos(tester,
        handler: created,
        location: FakeLocationService(
            error: const LocationException(LocationErrorType.timeout)));
    await chooseAndSend(tester);

    expect(find.textContaining("Couldn't get your location"), findsOneWidget);
    expect(h.requests, isEmpty);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('sos_submit_button')))
            .onPressed,
        isNotNull);
  });

  testWidgets('mock GPS switch is hidden when showMockGpsSwitch is false',
      (tester) async {
    // Release builds get false via kDebugMode; here it is forced explicitly
    // because tests themselves run in debug mode.
    final deps = SosDependencies(
      incidentService: IncidentService(
          client: MockClient(created), baseUrl: 'http://test.local/api/v1'),
      locationService: FakeLocationService(),
      mockLocationService: FakeLocationService(),
    );
    await tester.pumpWidget(MaterialApp(
        home: SosScreen(dependencies: deps, showMockGpsSwitch: false)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mock_gps_switch')), findsNothing);
    expect(find.byKey(const Key('sos_submit_button')), findsOneWidget);
  });

  for (final type in [
    LocationErrorType.serviceDisabled,
    LocationErrorType.permissionDeniedForever,
    LocationErrorType.permissionUnavailable,
    LocationErrorType.unavailable,
    LocationErrorType.invalidCoordinates,
    LocationErrorType.stale,
  ]) {
    testWidgets('location failure ${type.name}: message shown, no request',
        (tester) async {
      final h = await openSos(tester,
          handler: created,
          location: FakeLocationService(error: LocationException(type)));
      await chooseAndSend(tester);

      expect(find.text(LocationException(type).message), findsOneWidget);
      expect(h.requests, isEmpty);
    });
  }

  testWidgets('no mock switch when no mock service is provided (release)',
      (tester) async {
    await openSos(tester, handler: created, provideMock: false);
    expect(find.byKey(const Key('mock_gps_switch')), findsNothing);
  });

  testWidgets('mock service is never consulted unless the switch is on',
      (tester) async {
    final real = FakeLocationService(point: const GeoPoint(3, 4));
    final mock = FakeLocationService(point: const GeoPoint(9, 9));
    final h = await openSos(tester, handler: created, location: real, mock: mock);

    await chooseAndSend(tester);

    expect(mock.calls, 0);
    expect(real.calls, 1);
    expect(jsonDecode(h.requests.single.body)['location'],
        {'lat': 3.0, 'lng': 4.0});
  });

  testWidgets('mock GPS with invalid coordinates: clear error, nothing sent',
      (tester) async {
    final h = await openSos(tester,
        handler: created,
        mock: const MockLocationService(latitude: '91', longitude: '2'),
        showMock: true);

    await tester.tap(find.byKey(const Key('mock_gps_switch')));
    await tester.pump();
    await chooseAndSend(tester);

    expect(find.textContaining('Mock GPS coordinates are invalid'),
        findsOneWidget);
    expect(h.requests, isEmpty);
  });

  testWidgets('mock GPS uses configured coordinates, not device GPS',
      (tester) async {
    final real = FakeLocationService();
    final h = await openSos(tester,
        handler: created,
        location: real,
        mock: const MockLocationService(latitude: '1.5', longitude: '2.5'),
        showMock: true);

    await tester.tap(find.byKey(const Key('mock_gps_switch')));
    await tester.pump();
    await chooseAndSend(tester);

    expect(real.calls, 0);
    expect(jsonDecode(h.requests.single.body)['location'],
        {'lat': 1.5, 'lng': 2.5});
  });

  testWidgets('mock GPS missing config: clear error, nothing sent',
      (tester) async {
    final h = await openSos(tester,
        handler: created,
        mock: const MockLocationService(latitude: '', longitude: ''),
        showMock: true);

    await tester.tap(find.byKey(const Key('mock_gps_switch')));
    await tester.pump();
    await chooseAndSend(tester);

    expect(find.textContaining('Mock GPS is not configured'), findsOneWidget);
    expect(h.requests, isEmpty);
  });

  testWidgets('HTTP 400 shows validation message and stays on form',
      (tester) async {
    await openSos(tester,
        handler: (_) async => jsonResponse(
            {'error': 'VALIDATION_FAILED', 'message': 'internal'}, 400));
    await chooseAndSend(tester);

    expect(find.textContaining('could not accept'), findsOneWidget);
    expect(find.textContaining('internal'), findsNothing);
    expect(find.byType(SosScreen), findsOneWidget);
  });

  testWidgets('network failure shows safe message', (tester) async {
    await openSos(tester,
        handler: (_) async => throw const SocketException('refused'));
    await chooseAndSend(tester);

    expect(find.textContaining("Can't reach the server"), findsOneWidget);
    expect(find.textContaining('refused'), findsNothing);
  });

  testWidgets('timeout shows safe message', (tester) async {
    await openSos(tester, handler: (_) async => throw TimeoutException('t'));
    await chooseAndSend(tester);

    expect(find.textContaining('took too long'), findsOneWidget);
  });

  testWidgets('HTTP 500 shows safe server message', (tester) async {
    await openSos(tester, handler: (_) async => http.Response('trace', 500));
    await chooseAndSend(tester);

    expect(find.textContaining('server ran into a problem'), findsOneWidget);
    expect(find.textContaining('trace'), findsNothing);
  });

  testWidgets('HTTP 401 clears token and returns to login', (tester) async {
    final h =
        await openSos(tester, handler: (_) async => http.Response('', 401));
    await chooseAndSend(tester);

    expect(h.storage.token, isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SosScreen), findsNothing);
  });

  testWidgets('signing out while on SOS screen removes the screen',
      (tester) async {
    final h = await openSos(tester, handler: created);
    expect(find.byType(SosScreen), findsOneWidget);

    await h.session.signOut();
    await tester.pumpAndSettle();

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(SosScreen), findsNothing);
  });

  testWidgets('rapid double tap sends only one SOS', (tester) async {
    final completer = Completer<http.Response>();
    final h = await openSos(tester, handler: (_) => completer.future);

    await tester.tap(find.text('Fire'));
    await tester.pump();
    // Two taps with no frame in between.
    await tester.tap(find.byKey(const Key('sos_submit_button')));
    await tester.tap(find.byKey(const Key('sos_submit_button')),
        warnIfMissed: false);
    await tester.pump();

    expect(h.requests.length, 1);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('sos_submit_button')))
            .onPressed,
        isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete(jsonResponse(incidentJson(), 201));
    await tester.pumpAndSettle();
    expect(find.text('SOS sent'), findsOneWidget);
    expect(h.requests.length, 1);
  });
}
