import 'dart:convert';

import 'package:coastguard360_mobile/services/auth_exception.dart';
import 'package:coastguard360_mobile/services/jwt_utils.dart';
import 'package:coastguard360_mobile/services/session_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/fakes.dart';

String jwtWithExp(DateTime expiry) {
  String enc(Object o) =>
      base64Url.encode(utf8.encode(jsonEncode(o))).replaceAll('=', '');
  final exp = expiry.millisecondsSinceEpoch ~/ 1000;
  return '${enc({'alg': 'HS256'})}.${enc({'sub': '1', 'exp': exp})}.sig';
}

void main() {
  group('restore', () {
    test('no token -> unauthenticated', () async {
      final s = makeSession(MockClient((_) async => loginOk()), FakeTokenStorage());
      await s.restore();
      expect(s.status, SessionStatus.unauthenticated);
    });

    test('stored token -> authenticated', () async {
      final s = makeSession(
          MockClient((_) async => loginOk()), FakeTokenStorage(token: 'opaque'));
      await s.restore();
      expect(s.status, SessionStatus.authenticated);
    });

    test('expired JWT is cleared -> unauthenticated', () async {
      final storage = FakeTokenStorage(
          token: jwtWithExp(DateTime.now().subtract(const Duration(hours: 1))));
      final s = makeSession(MockClient((_) async => loginOk()), storage);
      await s.restore();
      expect(s.status, SessionStatus.unauthenticated);
      expect(storage.token, isNull);
    });

    test('unexpired JWT is kept', () async {
      final storage = FakeTokenStorage(
          token: jwtWithExp(DateTime.now().add(const Duration(hours: 1))));
      final s = makeSession(MockClient((_) async => loginOk()), storage);
      await s.restore();
      expect(s.status, SessionStatus.authenticated);
    });
  });

  test('isJwtExpired is false for undecodable tokens', () {
    expect(isJwtExpired('not-a-jwt'), isFalse);
    expect(isJwtExpired('a.b.c'), isFalse);
  });

  test('secure-storage write failure -> storage error, not signed in',
      () async {
    final s = makeSession(MockClient((_) async => loginOk()),
        FakeTokenStorage(failOnWrite: true));
    await expectLater(
      s.login(username: 'u', password: 'p'),
      throwsA(isA<AuthException>()
          .having((e) => e.type, 'type', AuthErrorType.storage)),
    );
    expect(s.status, isNot(SessionStatus.authenticated));
  });

  group('authenticated client', () {
    test('adds Bearer token header', () async {
      late http.BaseRequest captured;
      final storage = FakeTokenStorage(token: 'tok');
      final s = makeSession(MockClient((_) async => loginOk()), storage);
      final client = s.authenticatedClient(MockClient((req) async {
        captured = req;
        return http.Response('{}', 200);
      }));

      await client.get(Uri.parse('http://test.local/api/v1/anything'));

      expect(captured.headers['Authorization'], 'Bearer tok');
    });

    test('401 clears token and returns session to unauthenticated', () async {
      final storage = FakeTokenStorage(token: 'tok');
      final s = makeSession(MockClient((_) async => loginOk()), storage);
      await s.restore();
      expect(s.status, SessionStatus.authenticated);

      final client = s.authenticatedClient(
          MockClient((_) async => http.Response('', 401)));
      await client.get(Uri.parse('http://test.local/api/v1/anything'));

      expect(storage.token, isNull);
      expect(s.status, SessionStatus.unauthenticated);
    });
  });
}
