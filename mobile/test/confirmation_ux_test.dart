// Post-submission experience: confirmation content, small screens / large
// text, navigation back home, and sending / success / failure feedback.
import 'dart:async';

import 'package:coastguard360_mobile/app.dart';
import 'package:coastguard360_mobile/core/theme/app_theme.dart';
import 'package:coastguard360_mobile/models/incident.dart';
import 'package:coastguard360_mobile/screens/home_screen.dart';
import 'package:coastguard360_mobile/screens/sos_confirmation_screen.dart';
import 'package:coastguard360_mobile/screens/sos_screen.dart';
import 'package:coastguard360_mobile/services/incident_service.dart';
import 'package:coastguard360_mobile/services/sos_dependencies.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/fakes.dart';

void setScreen(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget host(Incident incident, {double textScale = 1.0}) => MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: SosConfirmationScreen(incident: incident, onSendAnother: (_) {}),
    );

const _zoned =
    Incident(id: 101, status: 'REPORTED', zoneName: 'North Beach High-Risk');

class _Flow {
  _Flow(this.requests);
  final List<http.Request> requests;
}

/// Real app, signed in, SOS screen open. [handler] answers POST /incidents.
Future<_Flow> openSos(
  WidgetTester tester, {
  required Future<http.Response> Function(http.Request) handler,
  Size size = const Size(800, 1600),
}) async {
  setScreen(tester, size);
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
    locationService: FakeLocationService(),
  );
  await tester.pumpWidget(CoastGuardApp(sessionController: session, sos: deps));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('open_sos_button')));
  await tester.pumpAndSettle();
  return _Flow(requests);
}

Future<void> send(WidgetTester tester, {String type = 'Fire'}) async {
  await tester.tap(find.text(type));
  await tester.pump();
  await tester.ensureVisible(find.byKey(const Key('sos_submit_button')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('sos_submit_button')));
  await tester.pumpAndSettle();
}

Future<http.Response> created(http.Request _) async =>
    jsonResponse(incidentJson(), 201);
Future<http.Response> failed(http.Request _) async =>
    http.Response('stack trace', 500);

void main() {
  group('Confirmation content', () {
    testWidgets('shows SOS sent, prominent incident ID, status and zone',
        (tester) async {
      await tester.pumpWidget(host(_zoned));

      expect(find.text('SOS sent'), findsOneWidget);
      expect(find.text('Incident ID: 101'), findsOneWidget);
      expect(find.text('Status: REPORTED'), findsOneWidget);
      expect(find.text('Zone: North Beach High-Risk'), findsOneWidget);
      expect(find.text('Back to home'), findsOneWidget);
    });

    testWidgets('incident ID is large and selectable', (tester) async {
      await tester.pumpWidget(host(_zoned));

      expect(tester.getSize(find.text('Incident ID: 101')).height,
          greaterThanOrEqualTo(45));
      expect(find.byType(SelectionArea), findsOneWidget);
    });

    testWidgets('never shows resort or responder data from the response',
        (tester) async {
      await tester.pumpWidget(host(Incident.fromJson(incidentJson())));

      expect(find.textContaining('Sea Pearl'), findsNothing);
      expect(find.textContaining('Rahim'), findsNothing);
      expect(find.textContaining('LIFEGUARD'), findsNothing);
      expect(find.textContaining('420'), findsNothing);
    });

    testWidgets('null, missing or blank zone shows no zone line',
        (tester) async {
      final json = incidentJson();
      final withoutKey = Map<String, dynamic>.of(json)..remove('zone');
      final blank = Map<String, dynamic>.of(json)..['zone'] = {'id': 3, 'name': '  '};
      for (final incident in [
        const Incident(id: 101, status: 'REPORTED'),
        Incident.fromJson(incidentJson(withZone: false)),
        Incident.fromJson(withoutKey),
        Incident.fromJson(blank),
      ]) {
        await tester.pumpWidget(host(incident));
        expect(find.text('SOS sent'), findsOneWidget);
        expect(find.text('Incident ID: 101'), findsOneWidget);
        expect(find.text('Status: REPORTED'), findsOneWidget);
        expect(find.textContaining('Zone:'), findsNothing);
        expect(find.byKey(const Key('incident_zone')), findsNothing);
      }
    });
  });

  group('Confirmation layout', () {
    testWidgets('fits a 320x568 phone at 2x text; the home action stays visible',
        (tester) async {
      setScreen(tester, const Size(320, 568));
      await tester.pumpWidget(host(
          const Incident(
              id: 123456,
              status: 'REPORTED',
              zoneName: 'North Beach High-Risk Swimming Area'),
          textScale: 2.0));

      expect(tester.takeException(), isNull); // no overflow
      final home = tester.getRect(find.byKey(const Key('back_home_button')));
      expect(home.bottom, lessThanOrEqualTo(568));
      expect(home.height, greaterThanOrEqualTo(56));
      // The content is reachable by scrolling.
      expect(find.text('SOS sent'), findsOneWidget);
    });

    testWidgets('the home action is the primary, full-width button',
        (tester) async {
      await tester.pumpWidget(host(_zoned));
      final size = tester.getSize(find.byKey(const Key('back_home_button')));
      expect(size.height, greaterThanOrEqualTo(64));
      expect(size.width, greaterThan(300));
      expect(find.byType(FilledButton), findsOneWidget); // only one primary
    });
  });

  group('Navigation from the confirmation', () {
    Future<GlobalKey<NavigatorState>> pumpPushed(WidgetTester tester) async {
      final navKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(
        navigatorKey: navKey,
        theme: AppTheme.light(),
        home: const Scaffold(body: Text('HOME')),
      ));
      navKey.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => SosConfirmationScreen(
              incident: _zoned, onSendAnother: (_) {})));
      await tester.pumpAndSettle();
      return navKey;
    }

    testWidgets('Back to home returns to the first screen', (tester) async {
      await pumpPushed(tester);
      await tester.tap(find.byKey(const Key('back_home_button')));
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
      expect(find.byType(SosConfirmationScreen), findsNothing);
    });

    testWidgets('system back also returns home (not to a stale form)',
        (tester) async {
      await pumpPushed(tester);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(find.text('HOME'), findsOneWidget);
    });
  });

  group('Submission feedback', () {
    testWidgets('sending, then success: confirmation replaces the form',
        (tester) async {
      final gate = Completer<http.Response>();
      final flow = await openSos(tester, handler: (_) => gate.future);

      // Idle
      expect(find.text('SEND SOS'), findsOneWidget);
      expect(find.byKey(const Key('sos_sending_status')), findsNothing);
      expect(find.byKey(const Key('sos_error')), findsNothing);

      await tester.tap(find.text('Fire'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sos_submit_button')));
      await tester.pump();

      // Sending: clear, locked, no result yet.
      expect(find.text('Sending SOS…'), findsOneWidget);
      expect(find.byKey(const Key('sos_sending_status')), findsOneWidget);
      expect(find.byKey(const Key('sos_error')), findsNothing);
      expect(find.text('SOS sent'), findsNothing);

      gate.complete(jsonResponse(incidentJson(), 201));
      await tester.pumpAndSettle();

      // Success
      expect(find.text('SOS sent'), findsOneWidget);
      expect(find.byType(SosScreen), findsNothing);
      expect(flow.requests.length, 1);
    });

    testWidgets('failure: clear error, not confirmed, can retry manually',
        (tester) async {
      var succeed = false;
      final flow = await openSos(tester,
          handler: (r) async {
            if (succeed) {
              return jsonResponse(incidentJson(), 201);
            }
            return failed(r);
          });

      await send(tester);

      expect(find.byKey(const Key('sos_error_title')), findsOneWidget);
      expect(find.text('SOS not confirmed'), findsOneWidget);
      expect(find.textContaining('server ran into a problem'), findsOneWidget);
      expect(find.text('Tap SEND SOS to try again.'), findsOneWidget);
      expect(find.textContaining('stack trace'), findsNothing); // no internals
      expect(find.text('SOS sent'), findsNothing);
      expect(find.text('Sending SOS…'), findsNothing);
      expect(flow.requests.length, 1); // nothing retried automatically

      succeed = true;
      await tester.tap(find.byKey(const Key('sos_submit_button')));
      await tester.pumpAndSettle();

      expect(find.text('SOS sent'), findsOneWidget);
      expect(flow.requests.length, 2); // one per user action
    });

    testWidgets('the failure message is scrolled into view on a small phone',
        (tester) async {
      await openSos(tester, handler: failed, size: const Size(320, 568));

      await send(tester);

      final rect = tester.getRect(find.byKey(const Key('sos_error')));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(568));
    });
  });

  group('Accidental navigation', () {
    testWidgets('back is blocked while sending; the result is not lost',
        (tester) async {
      final gate = Completer<http.Response>();
      await openSos(tester, handler: (_) => gate.future);
      expect(find.byType(BackButton), findsOneWidget); // idle: back available

      await tester.tap(find.text('Drowning'));
      await tester.pump();
      await tester.tap(find.byKey(const Key('sos_submit_button')));
      await tester.pump();

      expect(find.byType(BackButton), findsNothing);
      await tester.binding.handlePopRoute(); // Android back
      await tester.pump();
      expect(find.byType(SosScreen), findsOneWidget); // still here

      gate.complete(jsonResponse(incidentJson(), 201));
      await tester.pumpAndSettle();

      expect(find.text('SOS sent'), findsOneWidget); // success is shown
    });

    testWidgets('back works again after a failure', (tester) async {
      await openSos(tester, handler: failed);
      await send(tester);

      expect(find.byType(BackButton), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });

  group('Returning home leaves no stale state', () {
    Future<void> expectCleanForm(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('open_sos_button')));
      await tester.pumpAndSettle();
      expect(find.byType(SosScreen), findsOneWidget);
      expect(find.byKey(const Key('sos_error')), findsNothing);
      expect(find.byKey(const Key('sos_sending_status')), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing); // nothing selected
      expect(tester.widget<Text>(find.byKey(const Key('people_count_value'))).data,
          '1');
      expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('sos_submit_button')))
              .onPressed,
          isNotNull);
    }

    testWidgets('after a successful SOS', (tester) async {
      await openSos(tester, handler: created);
      await send(tester);
      expect(find.text('SOS sent'), findsOneWidget);

      await tester.tap(find.byKey(const Key('back_home_button')));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);

      await expectCleanForm(tester);
    });

    testWidgets('after a failed SOS', (tester) async {
      await openSos(tester, handler: failed);
      await send(tester);
      expect(find.byKey(const Key('sos_error')), findsOneWidget);

      await tester.pageBack();
      await tester.pumpAndSettle();

      await expectCleanForm(tester);
    });

    testWidgets('Send another SOS opens a fresh form', (tester) async {
      await openSos(tester, handler: created);
      await send(tester);

      await tester.tap(find.byKey(const Key('send_another_button')));
      await tester.pumpAndSettle();

      expect(find.byType(SosScreen), findsOneWidget);
      expect(find.byKey(const Key('sos_error')), findsNothing);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });
  });
}
