import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coastguard360_mobile/models/geo_point.dart';
import 'package:coastguard360_mobile/services/incident_service.dart';
import 'package:coastguard360_mobile/services/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/fakes.dart';

const _base = 'http://test.local/api/v1';

IncidentService serviceWith(http.Client c) =>
    IncidentService(client: c, baseUrl: _base);

Future<IncidentErrorType> errorOf(IncidentService s,
    {String type = 'FIRE',
    int people = 1,
    GeoPoint point = testPoint}) async {
  try {
    await s.createIncident(type: type, peopleCount: people, location: point);
  } on IncidentException catch (e) {
    return e.type;
  }
  fail('Expected IncidentException');
}

void main() {
  test('sends POST /incidents with Bearer token and exact JSON', () async {
    late http.Request captured;
    final storage = FakeTokenStorage(token: 'tok');
    final session = makeSession(MockClient((_) async => loginOk()), storage);
    final client = session.authenticatedClient(MockClient((req) async {
      captured = req;
      return jsonResponse(incidentJson(), 201);
    }));

    final incident = await serviceWith(client).createIncident(
      type: 'DROWNING',
      peopleCount: 2,
      note: '  Child in water near rocks ',
      location: testPoint,
    );

    expect(captured.method, 'POST');
    expect(captured.url.toString(), '$_base/incidents');
    expect(captured.headers['Authorization'], 'Bearer tok');
    expect(captured.headers['Content-Type'], startsWith('application/json'));
    expect(jsonDecode(captured.body), {
      'type': 'DROWNING',
      'peopleCount': 2,
      'note': 'Child in water near rocks',
      'location': {'lat': 21.4272, 'lng': 92.0058},
    });
    expect(incident.id, 101);
    expect(incident.status, 'REPORTED');
    expect(incident.zoneName, 'North Beach High-Risk');
  });

  test('omits blank or null note; never sends reporter identity', () async {
    final bodies = <Map<String, dynamic>>[];
    final service = serviceWith(MockClient((req) async {
      bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
      return jsonResponse(incidentJson(), 201);
    }));

    await service.createIncident(
        type: 'FIRE', peopleCount: 1, note: '   ', location: testPoint);
    await service.createIncident(
        type: 'FIRE', peopleCount: 1, location: testPoint);

    for (final b in bodies) {
      expect(b.containsKey('note'), isFalse);
      expect(b.keys.toSet(), {'type', 'peopleCount', 'location'});
    }
  });

  test('null zone is handled', () async {
    final incident = await serviceWith(MockClient(
            (_) async => jsonResponse(incidentJson(withZone: false), 201)))
        .createIncident(type: 'FIRE', peopleCount: 1, location: testPoint);
    expect(incident.zoneName, isNull);
  });

  test('rejects invalid input locally without sending a request', () async {
    var calls = 0;
    final s = serviceWith(MockClient((_) async {
      calls++;
      return jsonResponse(incidentJson(), 201);
    }));
    expect(await errorOf(s, people: 0), IncidentErrorType.invalidInput);
    expect(await errorOf(s, people: 101), IncidentErrorType.invalidInput);
    expect(await errorOf(s, type: 'MEDICAL'), IncidentErrorType.invalidInput);
    expect(await errorOf(s, point: const GeoPoint(91, 0)),
        IncidentErrorType.invalidInput);
    expect(calls, 0);
  });

  test('accepts the boundary counts 1 and 100', () async {
    final s = serviceWith(
        MockClient((_) async => jsonResponse(incidentJson(), 201)));
    await s.createIncident(type: 'FIRE', peopleCount: 1, location: testPoint);
    await s.createIncident(type: 'FIRE', peopleCount: 100, location: testPoint);
  });

  test('HTTP errors map to safe error types', () async {
    Future<IncidentErrorType> forStatus(int code) => errorOf(
        serviceWith(MockClient((_) async => http.Response('boom', code))));
    expect(await forStatus(400), IncidentErrorType.validation);
    expect(await forStatus(401), IncidentErrorType.unauthorized);
    expect(await forStatus(500), IncidentErrorType.server);
    expect(await forStatus(200), IncidentErrorType.server);
  });

  test('malformed 201 body -> unexpectedResponse', () async {
    for (final body in ['nope', '[]', '{"status":"REPORTED"}']) {
      final s = serviceWith(MockClient((_) async => http.Response(body, 201)));
      expect(await errorOf(s), IncidentErrorType.unexpectedResponse,
          reason: body);
    }
  });

  test('network failure and timeout', () async {
    expect(
        await errorOf(serviceWith(
            MockClient((_) async => throw const SocketException('x')))),
        IncidentErrorType.network);
    expect(
        await errorOf(
            serviceWith(MockClient((_) async => throw TimeoutException('x')))),
        IncidentErrorType.timeout);
    final slow = IncidentService(
      client: MockClient((_) => Completer<http.Response>().future),
      baseUrl: _base,
      timeout: const Duration(milliseconds: 10),
    );
    expect(await errorOf(slow), IncidentErrorType.timeout);
  });

  test('401 through the authenticated client clears the session', () async {
    final storage = FakeTokenStorage(token: 'tok');
    final session = makeSession(MockClient((_) async => loginOk()), storage);
    await session.restore();
    final client = session
        .authenticatedClient(MockClient((_) async => http.Response('', 401)));

    expect(await errorOf(serviceWith(client)), IncidentErrorType.unauthorized);
    expect(storage.token, isNull);
    expect(session.status, SessionStatus.unauthenticated);
  });

  test('every error type has a user-facing message', () {
    for (final t in IncidentErrorType.values) {
      expect(IncidentException(t).message, isNotEmpty);
    }
  });
}
