// End-to-end style widget tests: the real CoastGuardApp, real screens, real
// SessionController / AuthService / IncidentService, driven through a single
// in-memory fake backend (http MockClient). No network, GPS or delays.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coastguard360_mobile/app.dart';
import 'package:coastguard360_mobile/screens/home_screen.dart';
import 'package:coastguard360_mobile/screens/login_screen.dart';
import 'package:coastguard360_mobile/screens/sos_screen.dart';
import 'package:coastguard360_mobile/services/auth_service.dart';
import 'package:coastguard360_mobile/services/incident_service.dart';
import 'package:coastguard360_mobile/services/session_controller.dart';
import 'package:coastguard360_mobile/services/sos_dependencies.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/fakes.dart';

const _base = 'http://test.local/api/v1';
const _user = 'tester';
const _pass = 'secret-pass';
const _token = 'jwt-e2e';

typedef _Handler = Future<http.Response> Function(http.Request request);

/// Stands in for the backend: /auth/login and /incidents.
class _FakeBackend {
  _FakeBackend({this.onIncident, this.onLogin});

  _Handler? onIncident;
  _Handler? onLogin;
  final requests = <http.Request>[];

  List<http.Request> get incidentRequests =>
      requests.where((r) => r.url.path.endsWith('/incidents')).toList();

  Future<http.Response> handle(http.Request request) async {
    requests.add(request);
    final path = request.url.path;
    if (path.endsWith('/auth/login')) {
      if (onLogin != null) return onLogin!(request);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      if (body['username'] == _user && body['password'] == _pass) {
        return loginOk(token: _token);
      }
      return jsonResponse(
          {'error': 'UNAUTHORIZED', 'message': 'Invalid credentials'}, 401);
    }
    if (path.endsWith('/incidents')) {
      if (onIncident != null) return onIncident!(request);
      return jsonResponse(incidentJson(), 201);
    }
    return http.Response('not found', 404);
  }
}

class _Run {
  _Run(this.backend, this.storage, this.session);
  final _FakeBackend backend;
  final FakeTokenStorage storage;
  final SessionController session;
}

/// Starts the real app signed OUT, wired to [backend].
Future<_Run> startApp(WidgetTester tester, _FakeBackend backend) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final client = MockClient(backend.handle);
  final storage = FakeTokenStorage();
  final session = SessionController(
    authService: AuthService(client: client, baseUrl: _base),
    storage: storage,
  );
  final deps = SosDependencies(
    incidentService: IncidentService(
      client: session.authenticatedClient(client),
      baseUrl: _base,
    ),
    locationService: FakeLocationService(),
    // No mock GPS: behaves like a release build.
  );

  await tester.pumpWidget(CoastGuardApp(sessionController: session, sos: deps));
  await tester.pumpAndSettle();
  return _Run(backend, storage, session);
}

Future<void> logIn(WidgetTester tester,
    {String username = _user, String password = _pass}) async {
  await tester.enterText(find.byKey(const Key('username_field')), username);
  await tester.enterText(find.byKey(const Key('password_field')), password);
  await tester.tap(find.byKey(const Key('sign_in_button')));
  await tester.pumpAndSettle();
}

Future<void> openSos(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open_sos_button')));
  await tester.pumpAndSettle();
}

Future<void> chooseType(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
}

Future<void> tapSend(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('sos_submit_button')));
  await tester.pumpAndSettle();
}

void main() {
  group('login', () {
    testWidgets('tourist logs in and reaches the home screen', (tester) async {
      final run = await startApp(tester, _FakeBackend());
      expect(find.byType(LoginScreen), findsOneWidget);

      await logIn(tester);

      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      expect(find.byKey(const Key('open_sos_button')), findsOneWidget);
      expect(run.storage.token, _token);
      expect(jsonDecode(run.backend.requests.single.body),
          {'username': _user, 'password': _pass});
    });

    testWidgets('failed login shows an error and does not open home',
        (tester) async {
      final run = await startApp(tester, _FakeBackend());

      await logIn(tester, password: 'wrong');

      expect(find.text('Incorrect username or password.'), findsOneWidget);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsNothing);
      expect(run.storage.token, isNull);
    });

    testWidgets('server error on login shows a safe error, no home',
        (tester) async {
      final run = await startApp(
          tester,
          _FakeBackend(
              onLogin: (_) async => http.Response('stack trace', 500)));

      await logIn(tester);

      expect(find.textContaining('server ran into a problem'), findsOneWidget);
      expect(find.textContaining('stack trace'), findsNothing);
      expect(find.byType(HomeScreen), findsNothing);
      expect(run.storage.token, isNull);
    });
  });

  group('SOS', () {
    testWidgets(
        'FIRE with people count and note: request is correct and the '
        'confirmation shows id, status and zone', (tester) async {
      final run = await startApp(tester, _FakeBackend());
      await logIn(tester);
      await openSos(tester);

      await chooseType(tester, 'Fire');
      await tester.tap(find.byKey(const Key('people_increment')));
      await tester.tap(find.byKey(const Key('people_increment')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('note_field')), 'Smoke at kiosk');
      await tapSend(tester);

      // Confirmation screen.
      expect(find.text('SOS sent'), findsOneWidget);
      expect(find.text('Incident ID: 101'), findsOneWidget);
      expect(find.text('Status: REPORTED'), findsOneWidget);
      expect(find.text('Zone: North Beach High-Risk'), findsOneWidget);
      expect(find.byType(SosScreen), findsNothing);
      // Admin-only details never reach the tourist.
      expect(find.textContaining('Sea Pearl'), findsNothing);
      expect(find.textContaining('Rahim'), findsNothing);

      // Request on the wire.
      final req = run.backend.incidentRequests.single;
      expect(req.method, 'POST');
      expect(req.url.path, '/api/v1/incidents');
      expect(req.headers['Authorization'], 'Bearer $_token');
      expect(jsonDecode(req.body), {
        'type': 'FIRE',
        'peopleCount': 3,
        'note': 'Smoke at kiosk',
        'location': {'lat': testPoint.lat, 'lng': testPoint.lng},
      });
    });

    testWidgets('DROWNING with defaults omits the note', (tester) async {
      final run = await startApp(
          tester,
          _FakeBackend(
              onIncident: (_) async =>
                  jsonResponse(incidentJson(id: 202), 201)));
      await logIn(tester);
      await openSos(tester);

      await chooseType(tester, 'Drowning');
      await tapSend(tester);

      expect(find.text('Incident ID: 202'), findsOneWidget);
      final body =
          jsonDecode(run.backend.incidentRequests.single.body) as Map;
      expect(body['type'], 'DROWNING');
      expect(body['peopleCount'], 1);
      expect(body.containsKey('note'), isFalse);
    });

    testWidgets('null zone is handled: confirmation without a zone line',
        (tester) async {
      await startApp(
          tester,
          _FakeBackend(
              onIncident: (_) async =>
                  jsonResponse(incidentJson(withZone: false), 201)));
      await logIn(tester);
      await openSos(tester);

      await chooseType(tester, 'Drowning');
      await tapSend(tester);

      expect(find.text('SOS sent'), findsOneWidget);
      expect(find.text('Incident ID: 101'), findsOneWidget);
      expect(find.text('Status: REPORTED'), findsOneWidget);
      expect(find.textContaining('Zone:'), findsNothing);
    });

    final failures = <String, ({_Handler handler, String expected})>{
      'HTTP 500': (
        handler: (_) async => http.Response('stack trace', 500),
        expected: 'server ran into a problem',
      ),
      'HTTP 400': (
        handler: (_) async =>
            jsonResponse({'error': 'VALIDATION_FAILED', 'message': 'x'}, 400),
        expected: 'could not accept',
      ),
      'HTTP 403': (
        handler: (_) async =>
            jsonResponse({'error': 'FORBIDDEN', 'message': 'Access denied'}, 403),
        expected: 'not allowed to send SOS',
      ),
      'network failure': (
        handler: (_) async => throw const SocketException('refused'),
        expected: "Can't reach the server",
      ),
      'timeout': (
        handler: (_) async => throw TimeoutException('slow'),
        expected: 'took too long',
      ),
    };
    failures.forEach((name, failure) {
      testWidgets('failed SOS ($name): error shown, no confirmation, no '
          'automatic retry', (tester) async {
        final run = await startApp(
            tester, _FakeBackend(onIncident: failure.handler));
        await logIn(tester);
        await openSos(tester);

        await chooseType(tester, 'Fire');
        await tapSend(tester);

        expect(find.textContaining(failure.expected), findsOneWidget);
        expect(find.text('SOS sent'), findsNothing);
        expect(find.byType(SosScreen), findsOneWidget);
        expect(find.textContaining('stack trace'), findsNothing);
        expect(run.backend.incidentRequests.length, 1); // nothing retried
        expect(
            tester
                .widget<FilledButton>(find.byKey(const Key('sos_submit_button')))
                .onPressed,
            isNotNull); // user can try again manually
      });
    });

    testWidgets('after a failure the tourist can retry manually and succeed',
        (tester) async {
      final backend = _FakeBackend(
          onIncident: (_) async => http.Response('', 500));
      await startApp(tester, backend);
      await logIn(tester);
      await openSos(tester);
      await chooseType(tester, 'Fire');
      await tapSend(tester);
      expect(find.text('SOS sent'), findsNothing);

      backend.onIncident = null; // backend recovers
      await tapSend(tester);

      expect(find.text('SOS sent'), findsOneWidget);
      expect(backend.incidentRequests.length, 2); // one per user action
    });

    testWidgets('rapid repeated taps submit exactly one incident',
        (tester) async {
      final gate = Completer<http.Response>();
      final backend = _FakeBackend(onIncident: (_) => gate.future);
      await startApp(tester, backend);
      await logIn(tester);
      await openSos(tester);
      await chooseType(tester, 'Drowning');

      // Three taps with no frame in between.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byKey(const Key('sos_submit_button')),
            warnIfMissed: false);
      }
      await tester.pump();

      expect(backend.incidentRequests.length, 1);
      expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('sos_submit_button')))
              .onPressed,
          isNull);

      gate.complete(jsonResponse(incidentJson(), 201));
      await tester.pumpAndSettle();

      expect(find.text('SOS sent'), findsOneWidget);
      expect(backend.incidentRequests.length, 1);
    });
  });
}
