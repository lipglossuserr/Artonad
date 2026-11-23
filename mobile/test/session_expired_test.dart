import 'dart:async';
import 'dart:convert';

import 'package:coastguard360_mobile/app.dart';
import 'package:coastguard360_mobile/screens/home_screen.dart';
import 'package:coastguard360_mobile/screens/login_screen.dart';
import 'package:coastguard360_mobile/screens/sos_screen.dart';
import 'package:coastguard360_mobile/services/incident_service.dart';
import 'package:coastguard360_mobile/services/session_controller.dart';
import 'package:coastguard360_mobile/services/sos_dependencies.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/fakes.dart';

const _expiredText = 'Your session expired. Please log in again.';
final _apiUri = Uri.parse('http://test.local/api/v1/anything');

String _jwtWithExp(DateTime expiry) {
  String enc(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  final exp = expiry.millisecondsSinceEpoch ~/ 1000;
  return '${enc({'alg': 'HS256'})}.${enc({'sub': '1', 'exp': exp})}.sig';
}

http.Response _unauthorized() => http.Response('', 401);

class _App {
  _App(this.session, this.storage, this.apiRequests);
  final SessionController session;
  final FakeTokenStorage storage;
  final List<http.Request> apiRequests;
}

/// Pumps the whole app. Login (plain client) and API (authenticated client)
/// both answer 401 unless overridden.
Future<_App> pumpApp(
  WidgetTester tester, {
  String? token = 'tok',
  Future<http.Response> Function(http.Request)? loginHandler,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final storage = FakeTokenStorage(token: token);
  final session = makeSession(
      MockClient(loginHandler ?? (_) async => _unauthorized()), storage);
  final apiRequests = <http.Request>[];
  final api = session.authenticatedClient(MockClient((req) async {
    apiRequests.add(req);
    return _unauthorized();
  }));
  final deps = SosDependencies(
    incidentService:
        IncidentService(client: api, baseUrl: 'http://test.local/api/v1'),
    locationService: FakeLocationService(),
    mockLocationService: FakeLocationService(),
  );
  await tester.pumpWidget(CoastGuardApp(sessionController: session, sos: deps));
  await tester.pumpAndSettle();
  return _App(session, storage, apiRequests);
}

Future<void> submitSos(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('open_sos_button')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Drowning'));
  await tester.pump();
  await tester.tap(find.byKey(const Key('sos_submit_button')));
  await tester.pumpAndSettle();
}

Future<void> signIn(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('username_field')), 'someuser');
  await tester.enterText(find.byKey(const Key('password_field')), 'wrongpass');
  await tester.tap(find.byKey(const Key('sign_in_button')));
  await tester.pumpAndSettle();
}

void main() {
  group('SessionController', () {
    test('401 on an authenticated request clears token and flags expiry',
        () async {
      final storage = FakeTokenStorage(token: 'tok');
      final session = makeSession(MockClient((_) async => loginOk()), storage);
      await session.restore();
      final client =
          session.authenticatedClient(MockClient((_) async => _unauthorized()));

      await client.get(_apiUri);

      expect(storage.token, isNull);
      expect(session.status, SessionStatus.unauthenticated);
      expect(session.takeSessionExpiredNotice(), isTrue);
      expect(session.takeSessionExpiredNotice(), isFalse); // shown once
    });

    test('parallel 401s change state and set the notice only once', () async {
      final storage = FakeTokenStorage(token: 'tok');
      final session = makeSession(MockClient((_) async => loginOk()), storage);
      await session.restore();
      var notifications = 0;
      session.addListener(() => notifications++);
      final client =
          session.authenticatedClient(MockClient((_) async => _unauthorized()));

      await Future.wait([
        client.get(_apiUri),
        client.get(_apiUri),
        client.get(_apiUri),
      ]);

      expect(notifications, 1);
      expect(storage.token, isNull);
      expect(session.takeSessionExpiredNotice(), isTrue);
      expect(session.takeSessionExpiredNotice(), isFalse);
    });

    test('stale 401 from a previous session does not end the new session',
        () async {
      final storage = FakeTokenStorage(token: 'old');
      final session = makeSession(
          MockClient((_) async => loginOk(token: 'new')), storage);
      await session.restore();
      final gate = Completer<http.Response>();
      final client = session.authenticatedClient(MockClient((_) => gate.future));

      final inFlight = client.get(_apiUri); // sent with token 'old'
      await Future<void>.delayed(Duration.zero);

      await session.signOut();
      await session.login(username: 'u', password: 'p'); // token 'new'
      gate.complete(_unauthorized()); // late 401 for the old session
      await inFlight;

      expect(session.status, SessionStatus.authenticated);
      expect(storage.token, 'new');
      expect(session.takeSessionExpiredNotice(), isFalse);
    });

    test('manual sign-out does not flag expiry', () async {
      final session = makeSession(
          MockClient((_) async => loginOk()), FakeTokenStorage(token: 'tok'));
      await session.restore();

      await session.signOut();

      expect(session.status, SessionStatus.unauthenticated);
      expect(session.takeSessionExpiredNotice(), isFalse);
    });

    test('wrong-credentials login (401) does not flag expiry', () async {
      final session = makeSession(
          MockClient((_) async => _unauthorized()), FakeTokenStorage());
      await session.restore();

      await expectLater(
          session.login(username: 'u', password: 'p'), throwsA(anything));

      expect(session.status, SessionStatus.unauthenticated);
      expect(session.takeSessionExpiredNotice(), isFalse);
    });

    test('successful login clears a pending expiry notice', () async {
      final storage = FakeTokenStorage(token: 'tok');
      final session = makeSession(MockClient((_) async => loginOk()), storage);
      await session.restore();
      await session.handleUnauthorized();

      await session.login(username: 'u', password: 'p');

      expect(session.status, SessionStatus.authenticated);
      expect(session.takeSessionExpiredNotice(), isFalse);
    });

    test('expired stored JWT at startup flags expiry', () async {
      final storage = FakeTokenStorage(
          token: _jwtWithExp(DateTime.now().subtract(const Duration(hours: 1))));
      final session = makeSession(MockClient((_) async => loginOk()), storage);

      await session.restore();

      expect(session.status, SessionStatus.unauthenticated);
      expect(storage.token, isNull);
      expect(session.takeSessionExpiredNotice(), isTrue);
    });

    test('no token at startup does not flag expiry', () async {
      final session =
          makeSession(MockClient((_) async => loginOk()), FakeTokenStorage());
      await session.restore();
      expect(session.takeSessionExpiredNotice(), isFalse);
    });
  });

  group('SOS screen', () {
    testWidgets('401 shows no inline message (login screen owns it)',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final deps = SosDependencies(
        incidentService: IncidentService(
            client: MockClient((_) async => _unauthorized()),
            baseUrl: 'http://test.local/api/v1'),
        locationService: FakeLocationService(),
        mockLocationService: FakeLocationService(),
      );
      await tester.pumpWidget(MaterialApp(
          home: SosScreen(dependencies: deps, showMockGpsSwitch: false)));

      await tester.tap(find.text('Drowning'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sos_submit_button')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('sos_error')), findsNothing);
      expect(find.textContaining('session has expired'), findsNothing);
    });
  });

  group('Login screen', () {
    testWidgets('SOS 401 returns to login with one expiry message, no retry',
        (tester) async {
      final app = await pumpApp(tester);

      await submitSos(tester);

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(SosScreen), findsNothing);
      expect(find.text(_expiredText), findsOneWidget);
      expect(app.storage.token, isNull);
      expect(app.apiRequests.length, 1); // SOS was not retried
    });

    testWidgets('expiry message disappears on a wrong-password attempt',
        (tester) async {
      await pumpApp(tester);
      await submitSos(tester);
      expect(find.text(_expiredText), findsOneWidget);

      await signIn(tester);

      expect(find.text(_expiredText), findsNothing);
      expect(find.text('Incorrect username or password.'), findsOneWidget);
    });

    testWidgets('ordinary wrong-password login never shows the expiry message',
        (tester) async {
      await pumpApp(tester, token: null);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(_expiredText), findsNothing);

      await signIn(tester);

      expect(find.text('Incorrect username or password.'), findsOneWidget);
      expect(find.text(_expiredText), findsNothing);
    });

    testWidgets('manual sign-out shows no expiry message', (tester) async {
      await pumpApp(tester);
      expect(find.byType(HomeScreen), findsOneWidget);

      await tester.tap(find.byKey(const Key('sign_out_button')));
      await tester.pumpAndSettle();

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(_expiredText), findsNothing);
    });

    testWidgets('expired stored token at startup shows the expiry message',
        (tester) async {
      await pumpApp(tester,
          token:
              _jwtWithExp(DateTime.now().subtract(const Duration(hours: 1))));

      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text(_expiredText), findsOneWidget);
    });

    testWidgets('empty-field validation keeps the expiry message visible',
        (tester) async {
      await pumpApp(tester);
      await submitSos(tester);

      await tester.tap(find.byKey(const Key('sign_in_button')));
      await tester.pump();

      expect(find.text('Enter your username'), findsOneWidget);
      expect(find.text(_expiredText), findsOneWidget);
    });
  });
}
