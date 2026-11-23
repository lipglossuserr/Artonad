// Contract v1.1 / Dev1+Dev2 backend integration, tested against mocks.
// Shapes and status codes come from the backend source (AuthController,
// IncidentController, SecurityConfig, exception handlers, openapi.yaml).
// Nothing here talks to a real backend.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coastguard360_mobile/models/incident.dart';
import 'package:coastguard360_mobile/services/auth_exception.dart';
import 'package:coastguard360_mobile/services/incident_service.dart';
import 'package:coastguard360_mobile/services/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/fakes.dart';

const _base = 'http://test.local/api/v1';

IncidentService svc(http.Client c) =>
    IncidentService(client: c, baseUrl: _base);

Future<Incident> create(
  IncidentService s, {
  String type = 'FIRE',
  int people = 1,
  String? note,
}) =>
    s.createIncident(
        type: type, peopleCount: people, note: note, location: testPoint);

Future<IncidentErrorType> incidentError(Future<Object?> Function() call) async {
  try {
    await call();
  } on IncidentException catch (e) {
    return e.type;
  }
  fail('Expected IncidentException');
}

Future<AuthErrorType> authError(Future<void> Function() call) async {
  try {
    await call();
  } on AuthException catch (e) {
    return e.type;
  }
  fail('Expected AuthException');
}

void main() {
  group('POST /incidents request', () {
    for (final type in ['FIRE', 'DROWNING']) {
      test('$type is sent uppercase with path, Bearer token and exact body',
          () async {
        final storage = FakeTokenStorage(token: 'jwt-1');
        final session = makeSession(MockClient((_) async => loginOk()), storage);
        late http.Request sent;
        final client = session.authenticatedClient(MockClient((req) async {
          sent = req;
          return jsonResponse(incidentJson(), 201);
        }));

        await create(svc(client), type: type, people: 2, note: 'Near rocks');

        expect(sent.method, 'POST');
        expect(sent.url.toString(), '$_base/incidents');
        expect(sent.headers['Authorization'], 'Bearer jwt-1');
        expect(jsonDecode(sent.body), {
          'type': type,
          'peopleCount': 2,
          'note': 'Near rocks',
          'location': {'lat': testPoint.lat, 'lng': testPoint.lng},
        });
      });
    }

    test('peopleCount 1 and 100 are sent; 0 and 101 are rejected locally',
        () async {
      final bodies = <Map<String, dynamic>>[];
      final s = svc(MockClient((req) async {
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        return jsonResponse(incidentJson(), 201);
      }));

      await create(s, people: 1);
      await create(s, people: 100);
      expect(bodies.map((b) => b['peopleCount']), [1, 100]);

      for (final bad in [0, 101, -5]) {
        expect(await incidentError(() => create(s, people: bad)),
            IncidentErrorType.invalidInput,
            reason: '$bad');
      }
      expect(bodies.length, 2); // nothing sent for invalid counts
    });

    test('note: 1 to 500 characters is sent, longer is rejected locally',
        () async {
      final bodies = <Map<String, dynamic>>[];
      final s = svc(MockClient((req) async {
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        return jsonResponse(incidentJson(), 201);
      }));

      await create(s, note: 'a'); // 1 char
      await create(s, note: 'b' * 500); // limit
      await create(s, note: '  ${'c' * 500}  '); // padding is trimmed first
      await create(s, note: 'é' * 500); // multi-byte, 500 characters

      expect(bodies[0]['note'], 'a');
      expect((bodies[1]['note'] as String).length, 500);
      expect((bodies[2]['note'] as String).length, 500);
      expect((bodies[3]['note'] as String).length, 500);

      expect(await incidentError(() => create(s, note: 'd' * 501)),
          IncidentErrorType.noteTooLong);
      expect(bodies.length, 4); // the 501-char note never left the phone
    });

    test('blank note is omitted entirely', () async {
      final bodies = <Map<String, dynamic>>[];
      final s = svc(MockClient((req) async {
        bodies.add(jsonDecode(req.body) as Map<String, dynamic>);
        return jsonResponse(incidentJson(), 201);
      }));

      await create(s, note: '');
      await create(s, note: '   \n ');
      await create(s);

      for (final b in bodies) {
        expect(b.containsKey('note'), isFalse);
      }
    });
  });

  group('HTTP 201 response parsing', () {
    test('backend-shaped response: id, status and zone name are read',
        () async {
      final i = await create(
          svc(MockClient((_) async => jsonResponse(incidentJson(), 201))));
      expect(i.id, 101);
      expect(i.status, 'REPORTED');
      expect(i.zoneName, 'North Beach High-Risk');
    });

    test('null nearestResort and empty recommendedResponders are fine',
        () async {
      final json = incidentJson(withZone: false)
        ..['nearestResort'] = null
        ..['recommendedResponders'] = <dynamic>[];
      final i = await create(
          svc(MockClient((_) async => jsonResponse(json, 201))));
      expect(i.zoneName, isNull);
      expect(i.status, 'REPORTED');
    });

    test('missing or null optional fields and unknown fields are tolerated',
        () async {
      final base = incidentJson();
      final variants = <Map<String, dynamic>>[
        Map.of(base)..remove('zone')..remove('nearestResort')..remove('recommendedResponders'),
        Map.of(base)..['recommendedResponders'] = null,
        Map.of(base)..['note'] = null,
        Map.of(base)..['somethingNew'] = {'a': 1},
        Map.of(base)..['zone'] = 'not-an-object',
        Map.of(base)..['zone'] = {'id': 3, 'name': null},
        Map.of(base)..['zone'] = {'id': 3, 'name': '   '},
        Map.of(base)..['id'] = 101.0,
      ];
      for (final json in variants) {
        final i = await create(
            svc(MockClient((_) async => jsonResponse(json, 201))));
        expect(i.id, 101);
        expect(i.status, 'REPORTED');
      }
    });

    test('non-ASCII zone names survive a JSON response without a charset',
        () async {
      final json = incidentJson()..['zone'] = {'id': 3, 'name': 'উত্তর সৈকত Café'};
      final response = http.Response.bytes(
          utf8.encode(jsonEncode(json)), 201,
          headers: {'content-type': 'application/json'});
      final i = await create(svc(MockClient((_) async => response)));
      expect(i.zoneName, 'উত্তর সৈকত Café');
    });

    test('malformed 201 bodies -> unexpectedResponse', () async {
      for (final body in [
        '',
        'not json',
        '[]',
        '{}',
        '{"id":"x","status":"REPORTED"}',
        '{"id":101,"status":""}',
        '{"id":101}',
      ]) {
        final s = svc(MockClient((_) async => http.Response(body, 201)));
        expect(await incidentError(() => create(s)),
            IncidentErrorType.unexpectedResponse,
            reason: body);
      }
    });
  });

  group('POST /incidents error handling', () {
    Future<IncidentErrorType> forStatus(int code, {String body = ''}) =>
        incidentError(() => create(
            svc(MockClient((_) async => http.Response(body, code)))));

    test('400 -> validation, without showing server text', () async {
      final s = svc(MockClient((_) async => jsonResponse(
          {'error': 'VALIDATION_FAILED', 'message': 'peopleCount must be at least 1'},
          400)));
      try {
        await create(s);
        fail('expected exception');
      } on IncidentException catch (e) {
        expect(e.type, IncidentErrorType.validation);
        expect(e.message, isNot(contains('peopleCount')));
      }
    });

    test('401 -> unauthorized, and the session is ended', () async {
      final storage = FakeTokenStorage(token: 'tok');
      final session = makeSession(MockClient((_) async => loginOk()), storage);
      await session.restore();
      final client =
          session.authenticatedClient(MockClient((_) async => http.Response('', 401)));

      expect(await incidentError(() => create(svc(client))),
          IncidentErrorType.unauthorized);
      expect(storage.token, isNull);
      expect(session.status, SessionStatus.unauthenticated);
      expect(session.takeSessionExpiredNotice(), isTrue);
    });

    test('403 -> forbidden, and the session is NOT ended', () async {
      final storage = FakeTokenStorage(token: 'tok');
      final session = makeSession(MockClient((_) async => loginOk()), storage);
      await session.restore();
      final client = session.authenticatedClient(MockClient((_) async =>
          jsonResponse({'error': 'FORBIDDEN', 'message': 'Access denied'}, 403)));

      expect(await incidentError(() => create(svc(client))),
          IncidentErrorType.forbidden);
      expect(storage.token, 'tok');
      expect(session.status, SessionStatus.authenticated);
      expect(session.takeSessionExpiredNotice(), isFalse);
    });

    test('500 and 503 -> server, internals not exposed', () async {
      for (final code in [500, 503]) {
        final s = svc(MockClient(
            (_) async => http.Response('java.lang.NullPointerException', code)));
        try {
          await create(s);
          fail('expected exception');
        } on IncidentException catch (e) {
          expect(e.type, IncidentErrorType.server);
          expect(e.message, isNot(contains('NullPointer')));
        }
      }
    });

    test('other unexpected statuses (200, 404, 409) -> server', () async {
      for (final code in [200, 404, 409]) {
        expect(await forStatus(code), IncidentErrorType.server, reason: '$code');
      }
    });

    test('network failures -> network; slow server -> timeout', () async {
      for (final error in <Object>[
        const SocketException('refused'),
        http.ClientException('reset'),
      ]) {
        expect(
            await incidentError(() => create(svc(MockClient((_) async => throw error)))),
            IncidentErrorType.network);
      }
      expect(
          await incidentError(() =>
              create(svc(MockClient((_) async => throw TimeoutException('x'))))),
          IncidentErrorType.timeout);
      final slow = IncidentService(
        client: MockClient((_) => Completer<http.Response>().future),
        baseUrl: _base,
        timeout: const Duration(milliseconds: 10),
      );
      expect(await incidentError(() => create(slow)), IncidentErrorType.timeout);
    });

    test('a failed or uncertain request is never retried', () async {
      var calls = 0;
      final s = svc(MockClient((_) async {
        calls++;
        throw TimeoutException('x');
      }));
      await incidentError(() => create(s));
      expect(calls, 1);
    });
  });

  group('POST /auth/login (backend contract)', () {
    test('200 {token, role, userId} signs a tourist in; token then sent as Bearer',
        () async {
      final storage = FakeTokenStorage();
      late http.Request loginReq;
      final session = makeSession(MockClient((req) async {
        loginReq = req;
        return jsonResponse({'token': 'jwt-9', 'role': 'TOURIST', 'userId': 1}, 200);
      }), storage);

      await session.login(username: 'tourist1', password: 'tourist123');

      expect(loginReq.url.toString(), '$_base/auth/login');
      expect(jsonDecode(loginReq.body),
          {'username': 'tourist1', 'password': 'tourist123'});
      expect(loginReq.headers.containsKey('Authorization'), isFalse);
      expect(session.status, SessionStatus.authenticated);
      expect(storage.token, 'jwt-9');

      late http.BaseRequest next;
      final client = session.authenticatedClient(MockClient((req) async {
        next = req;
        return http.Response('{}', 200);
      }));
      await client.get(Uri.parse('$_base/anything'));
      expect(next.headers['Authorization'], 'Bearer jwt-9');
    });

    test('401 {UNAUTHORIZED} -> invalid credentials, not session expiry',
        () async {
      final storage = FakeTokenStorage();
      final session = makeSession(
          MockClient((_) async => jsonResponse(
              {'error': 'UNAUTHORIZED', 'message': 'Invalid credentials'}, 401)),
          storage);
      expect(await authError(() => session.login(username: 'u', password: 'p')),
          AuthErrorType.invalidCredentials);
      expect(storage.token, isNull);
      expect(session.takeSessionExpiredNotice(), isFalse);
    });

    test('400 {VALIDATION_FAILED} -> invalidRequest message', () async {
      final session = makeSession(
          MockClient((_) async => jsonResponse(
              {'error': 'VALIDATION_FAILED', 'message': 'Invalid request data'}, 400)),
          FakeTokenStorage());
      try {
        await session.login(username: 'u', password: 'p');
        fail('expected exception');
      } on AuthException catch (e) {
        expect(e.type, AuthErrorType.invalidRequest);
        expect(e.message, 'Please enter your username and password.');
      }
    });

    test('500 -> server; connection failure -> network; ADMIN role rejected',
        () async {
      expect(
          await authError(() => makeSession(
                  MockClient((_) async => http.Response('boom', 500)),
                  FakeTokenStorage())
              .login(username: 'u', password: 'p')),
          AuthErrorType.server);
      expect(
          await authError(() => makeSession(
                  MockClient((_) async => throw const SocketException('x')),
                  FakeTokenStorage())
              .login(username: 'u', password: 'p')),
          AuthErrorType.network);

      final storage = FakeTokenStorage();
      final admin = makeSession(
          MockClient((_) async => loginOk(role: 'ADMIN')), storage);
      expect(await authError(() => admin.login(username: 'u', password: 'p')),
          AuthErrorType.wrongRole);
      expect(storage.token, isNull);
    });
  });
}
