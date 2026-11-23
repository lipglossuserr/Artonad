import 'dart:async';
import 'dart:io';

import 'package:coastguard360_mobile/app.dart';
import 'package:coastguard360_mobile/screens/home_screen.dart';
import 'package:coastguard360_mobile/screens/login_screen.dart';
import 'package:coastguard360_mobile/services/session_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/fakes.dart';

Future<void> pumpApp(WidgetTester tester, SessionController session) async {
  await tester.pumpWidget(CoastGuardApp(sessionController: session));
  await tester.pumpAndSettle();
}

Future<void> enterCredentials(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('username_field')), 'someuser');
  await tester.enterText(find.byKey(const Key('password_field')), 'somepass');
}

Future<void> tapSignIn(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('sign_in_button')));
}

void main() {
  testWidgets('renders empty login form (no prefilled credentials)',
      (tester) async {
    final session = makeSession(
        MockClient((_) async => loginOk()), FakeTokenStorage());
    await pumpApp(tester, session);

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    final username = tester.widget<TextFormField>(
        find.byKey(const Key('username_field')));
    final password = tester.widget<TextFormField>(
        find.byKey(const Key('password_field')));
    expect(username.controller!.text, isEmpty);
    expect(password.controller!.text, isEmpty);
  });

  testWidgets('validates empty fields and sends no request', (tester) async {
    var calls = 0;
    final session = makeSession(
        MockClient((_) async {
          calls++;
          return loginOk();
        }),
        FakeTokenStorage());
    await pumpApp(tester, session);

    await tapSignIn(tester);
    await tester.pump();

    expect(find.text('Enter your username'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
    expect(calls, 0);
  });

  testWidgets('password visibility toggle works', (tester) async {
    final session = makeSession(
        MockClient((_) async => loginOk()), FakeTokenStorage());
    await pumpApp(tester, session);

    EditableText field() => tester.widget<EditableText>(find.descendant(
        of: find.byKey(const Key('password_field')),
        matching: find.byType(EditableText)));

    expect(field().obscureText, isTrue);
    await tester.tap(find.byKey(const Key('toggle_password_visibility')));
    await tester.pump();
    expect(field().obscureText, isFalse);
  });

  testWidgets('successful login stores token and shows home placeholder',
      (tester) async {
    final storage = FakeTokenStorage();
    final session =
        makeSession(MockClient((_) async => loginOk(token: 'jwt-1')), storage);
    await pumpApp(tester, session);

    await enterCredentials(tester);
    await tapSignIn(tester);
    await tester.pumpAndSettle();

    expect(storage.token, 'jwt-1');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(LoginScreen), findsNothing);
  });

  testWidgets('401 shows invalid-credentials message, stores no token',
      (tester) async {
    final storage = FakeTokenStorage();
    final session = makeSession(
        MockClient((_) async => jsonResponse(
            {'error': 'UNAUTHORIZED', 'message': 'internal detail'}, 401)),
        storage);
    await pumpApp(tester, session);

    await enterCredentials(tester);
    await tapSignIn(tester);
    await tester.pumpAndSettle();

    expect(find.text('Incorrect username or password.'), findsOneWidget);
    expect(find.textContaining('internal detail'), findsNothing);
    expect(storage.token, isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
  });

  testWidgets('network failure shows safe message', (tester) async {
    final storage = FakeTokenStorage();
    final session = makeSession(
        MockClient((_) async => throw const SocketException('refused')),
        storage);
    await pumpApp(tester, session);

    await enterCredentials(tester);
    await tapSignIn(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining("Can't reach the server"), findsOneWidget);
    expect(find.textContaining('refused'), findsNothing);
    expect(storage.token, isNull);
  });

  testWidgets('HTTP 500 shows safe server error message', (tester) async {
    final storage = FakeTokenStorage();
    final session = makeSession(
        MockClient((_) async => http.Response('stack trace here', 500)),
        storage);
    await pumpApp(tester, session);

    await enterCredentials(tester);
    await tapSignIn(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('server ran into a problem'), findsOneWidget);
    expect(find.textContaining('stack trace'), findsNothing);
    expect(storage.token, isNull);
  });

  testWidgets('non-tourist role is rejected and token not stored',
      (tester) async {
    final storage = FakeTokenStorage();
    final session = makeSession(
        MockClient((_) async => loginOk(role: 'ADMIN')), storage);
    await pumpApp(tester, session);

    await enterCredentials(tester);
    await tapSignIn(tester);
    await tester.pumpAndSettle();

    expect(find.text('This app is for tourist accounts only.'),
        findsOneWidget);
    expect(storage.token, isNull);
  });

  testWidgets('loading state disables button; no duplicate requests',
      (tester) async {
    final completer = Completer<http.Response>();
    var calls = 0;
    final session = makeSession(
        MockClient((_) {
          calls++;
          return completer.future;
        }),
        FakeTokenStorage());
    await pumpApp(tester, session);

    await enterCredentials(tester);
    await tapSignIn(tester);
    await tester.pump();

    final button = tester
        .widget<FilledButton>(find.byKey(const Key('sign_in_button')));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await tester.tap(find.byKey(const Key('sign_in_button')),
        warnIfMissed: false);
    await tester.pump();
    expect(calls, 1);

    completer.complete(jsonResponse({'error': 'UNAUTHORIZED'}, 401));
    await tester.pumpAndSettle();
    expect(find.text('Incorrect username or password.'), findsOneWidget);
  });
}
