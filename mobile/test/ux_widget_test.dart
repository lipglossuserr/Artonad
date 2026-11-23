// Focused widget tests for the UX pass: labels, hierarchy, touch targets,
// states and small-screen / large-text layout. Behaviour (API, auth, GPS) is
// covered by the other test files.
import 'dart:async';

import 'package:coastguard360_mobile/core/theme/app_theme.dart';
import 'package:coastguard360_mobile/screens/home_screen.dart';
import 'package:coastguard360_mobile/screens/login_screen.dart';
import 'package:coastguard360_mobile/screens/sos_screen.dart';
import 'package:coastguard360_mobile/services/incident_service.dart';
import 'package:coastguard360_mobile/services/sos_dependencies.dart';
import 'package:coastguard360_mobile/widgets/sos_form_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/fakes.dart';

/// Small phone, optionally with large system text.
void useSmallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget app(Widget home, {double textScale = 1.0}) => MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: home,
    );

SosDependencies deps({bool withMock = true}) => SosDependencies(
      incidentService: IncidentService(
        client: MockClient((_) async => jsonResponse(incidentJson(), 201)),
        baseUrl: 'http://test.local/api/v1',
      ),
      locationService: FakeLocationService(),
      mockLocationService: withMock ? FakeLocationService() : null,
    );

void main() {
  group('Home screen', () {
    testWidgets('makes the SOS action and both emergency types obvious',
        (tester) async {
      var opened = 0;
      await tester.pumpWidget(app(HomeScreen(
          onOpenSos: () => opened++, onSignOut: () {})));

      expect(find.text('SEND SOS'), findsOneWidget);
      expect(find.text('Fire emergency'), findsOneWidget);
      expect(find.text('Drowning emergency'), findsOneWidget);
      expect(find.textContaining('choose Fire or Drowning'), findsOneWidget);
      expect(find.textContaining('being initialized'), findsNothing);

      await tester.tap(find.byKey(const Key('open_sos_button')));
      expect(opened, 1);
    });

    testWidgets('SOS button is large and full width; sign-out is a 48dp target',
        (tester) async {
      await tester.pumpWidget(app(HomeScreen(
          onOpenSos: () {}, onSignOut: () {})));

      final sos = tester.getSize(find.byKey(const Key('open_sos_button')));
      expect(sos.height, greaterThanOrEqualTo(72));
      expect(sos.width, greaterThan(300));
      final signOut = tester.getSize(find.byKey(const Key('sign_out_button')));
      expect(signOut.height, greaterThanOrEqualTo(48));
    });

    testWidgets('SOS stays reachable on a small screen with large text',
        (tester) async {
      useSmallScreen(tester);
      await tester.pumpWidget(app(
          HomeScreen(onOpenSos: () {}, onSignOut: () {}),
          textScale: 1.5));

      expect(tester.takeException(), isNull); // no overflow
      final rect = tester.getRect(find.byKey(const Key('open_sos_button')));
      expect(rect.bottom, lessThanOrEqualTo(568)); // fully on screen
      expect(find.byKey(const Key('sign_out_button')), findsOneWidget);
    });

    testWidgets('without SOS wired, no SOS button or guidance is shown',
        (tester) async {
      await tester.pumpWidget(app(HomeScreen(onSignOut: () {})));
      expect(find.byKey(const Key('open_sos_button')), findsNothing);
      expect(find.textContaining('choose Fire or Drowning'), findsNothing);
    });
  });

  group('SOS form', () {
    Future<void> pumpForm(WidgetTester tester,
        {bool busy = false, String? error, double textScale = 1.0}) async {
      await tester.pumpWidget(app(
        Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: SosFormWidget(
                onSubmit: (_) {}, isSubmitting: busy, errorMessage: error),
          ),
        ),
        textScale: textScale,
      ));
    }

    testWidgets('type choices are large and show an unmistakable selection',
        (tester) async {
      await pumpForm(tester);

      expect(find.text('1. What is the emergency?'), findsOneWidget);
      for (final label in ['Fire', 'Drowning']) {
        final size = tester.getSize(find
            .ancestor(of: find.text(label), matching: find.byType(InkWell))
            .first);
        expect(size.height, greaterThanOrEqualTo(96), reason: label);
      }
      expect(find.byIcon(Icons.check_circle), findsNothing);

      await tester.tap(find.text('Fire'));
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsOneWidget);

      await tester.tap(find.text('Drowning'));
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsOneWidget); // only one
    });

    testWidgets('people count has big buttons and a person/people label',
        (tester) async {
      await pumpForm(tester);

      for (final key in ['people_decrement', 'people_increment']) {
        final size = tester.getSize(find.byKey(Key(key)));
        expect(size.width, greaterThanOrEqualTo(48), reason: key);
        expect(size.height, greaterThanOrEqualTo(48), reason: key);
      }
      Text unit() => tester.widget<Text>(find.byKey(const Key('people_count_unit')));
      expect(unit().data, 'person');

      await tester.tap(find.byKey(const Key('people_increment')));
      await tester.pump();
      expect(unit().data, 'people');
    });

    testWidgets('note field is clearly labelled optional', (tester) async {
      await pumpForm(tester);
      expect(find.text('3. Add details (optional)'), findsOneWidget);
      expect(find.text('Note (optional)'), findsOneWidget);
      expect(find.textContaining('helps responders'), findsOneWidget);
    });

    testWidgets('submit button is large and labelled SEND SOS', (tester) async {
      await pumpForm(tester);
      expect(find.text('SEND SOS'), findsOneWidget);
      final size = tester.getSize(find.byKey(const Key('sos_submit_button')));
      expect(size.height, greaterThanOrEqualTo(64));
    });

    testWidgets('submitting: button says Sending, inputs locked, status shown',
        (tester) async {
      await pumpForm(tester, busy: true);

      expect(find.text('Sending SOS…'), findsOneWidget);
      expect(find.text('SEND SOS'), findsNothing);
      expect(find.byKey(const Key('sos_sending_status')), findsOneWidget);
      expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('sos_submit_button')))
              .onPressed,
          isNull);

      // Type cards, stepper and note cannot be changed while sending.
      await tester.tap(find.text('Fire'));
      await tester.pump();
      expect(find.byIcon(Icons.check_circle), findsNothing);
      expect(
          tester
              .widget<IconButton>(find.byKey(const Key('people_increment')))
              .onPressed,
          isNull);
      expect(tester.widget<TextField>(find.byKey(const Key('note_field'))).enabled,
          isFalse);
    });

    testWidgets('idle state shows no sending status', (tester) async {
      await pumpForm(tester);
      expect(find.byKey(const Key('sos_sending_status')), findsNothing);
    });

    testWidgets('error state shows an icon and the message', (tester) async {
      await pumpForm(tester, error: 'Something failed');
      expect(find.text('Something failed'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('fits a 320dp-wide screen at 1.5x text without overflow',
        (tester) async {
      useSmallScreen(tester);
      await pumpForm(tester, error: 'Something failed', textScale: 1.5);
      expect(tester.takeException(), isNull);
      // Everything is reachable by scrolling.
      await tester.scrollUntilVisible(
          find.byKey(const Key('sos_submit_button')), 200,
          scrollable: find.byType(Scrollable).first);
      expect(find.byKey(const Key('sos_submit_button')), findsOneWidget);
    });
  });

  group('SOS screen location mode', () {
    testWidgets('shows real GPS by default and MOCK GPS when switched on',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(
          SosScreen(dependencies: deps(), showMockGpsSwitch: true)));

      expect(find.textContaining("your phone's GPS"), findsOneWidget);
      expect(find.textContaining('MOCK GPS'), findsNothing);

      await tester.tap(find.byKey(const Key('mock_gps_switch')));
      await tester.pump();

      expect(find.textContaining('MOCK GPS (debug build)'), findsOneWidget);
      expect(find.textContaining("your phone's GPS"), findsNothing);

      await tester.tap(find.byKey(const Key('mock_gps_switch')));
      await tester.pump();
      expect(find.textContaining("your phone's GPS"), findsOneWidget);
    });

    testWidgets('without a mock service only real GPS is shown, no switch',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(SosScreen(
          dependencies: deps(withMock: false), showMockGpsSwitch: true)));

      expect(find.byKey(const Key('mock_gps_switch')), findsNothing);
      expect(find.textContaining("your phone's GPS"), findsOneWidget);
    });
  });

  group('Login screen', () {
    Future<LoginScreen> screen({Future<http.Response> Function()? login}) async {
      final session = makeSession(
          MockClient((_) => login != null ? login() : Future.value(loginOk())),
          FakeTokenStorage());
      return LoginScreen(sessionController: session);
    }

    testWidgets('has labelled fields, a visibility toggle and no visible demo '
        'credentials', (tester) async {
      await tester.pumpWidget(app(await screen()));

      expect(find.text('Username'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.byTooltip('Show password'), findsOneWidget);
      expect(find.textContaining('tourist1'), findsNothing);
      expect(find.textContaining('tourist123'), findsNothing);
      expect(find.textContaining('admin'), findsNothing);
      expect(
          tester.getSize(find.byKey(const Key('sign_in_button'))).height,
          greaterThanOrEqualTo(56));
      expect(
          tester
              .getSize(find.byKey(const Key('toggle_password_visibility')))
              .shortestSide,
          greaterThanOrEqualTo(48));
    });

    testWidgets('validation feedback appears as the user edits, not before',
        (tester) async {
      await tester.pumpWidget(app(await screen()));
      expect(find.text('Enter your username'), findsNothing);

      await tester.enterText(find.byKey(const Key('username_field')), 'a');
      await tester.pump();
      await tester.enterText(find.byKey(const Key('username_field')), '');
      await tester.pump();

      expect(find.text('Enter your username'), findsOneWidget);
    });

    testWidgets('loading state is explicit and blocks resubmission',
        (tester) async {
      final gate = Completer<http.Response>();
      await tester.pumpWidget(app(await screen(login: () => gate.future)));

      await tester.enterText(find.byKey(const Key('username_field')), 'u');
      await tester.enterText(find.byKey(const Key('password_field')), 'p');
      await tester.tap(find.byKey(const Key('sign_in_button')));
      await tester.pump();

      expect(find.text('Signing in…'), findsOneWidget);
      expect(find.text('Sign In'), findsNothing);
      expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('sign_in_button')))
              .onPressed,
          isNull);

      gate.complete(http.Response('', 401)); // settle: no pending timers
      await tester.pumpAndSettle();
    });

    testWidgets('failed login shows an icon and the invalid-credentials text',
        (tester) async {
      await tester.pumpWidget(
          app(await screen(login: () async => http.Response('', 401))));

      await tester.enterText(find.byKey(const Key('username_field')), 'u');
      await tester.enterText(find.byKey(const Key('password_field')), 'p');
      await tester.tap(find.byKey(const Key('sign_in_button')));
      await tester.pumpAndSettle();

      expect(find.text('Incorrect username or password.'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('fits a 320dp-wide screen at 1.5x text without overflow',
        (tester) async {
      useSmallScreen(tester);
      await tester.pumpWidget(app(await screen(), textScale: 1.5));
      expect(tester.takeException(), isNull);
    });
  });
}
