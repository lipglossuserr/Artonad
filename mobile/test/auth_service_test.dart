import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:coastguard360_mobile/services/auth_exception.dart';
import 'package:coastguard360_mobile/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers/fakes.dart';

AuthService serviceWith(MockClient client) =>
    AuthService(client: client, baseUrl: 'http://test.local/api/v1/');

Future<AuthErrorType> errorOf(AuthService service) async {
  try {
    await service.login(username: 'u', password: 'p');
  } on AuthException catch (e) {
    return e.type;
  }
  fail('Expected AuthException');
}

void main() {
  test('sends exact JSON contract to POST /auth/login and parses response',
      () async {
    late http.Request captured;
    final service = serviceWith(MockClient((req) async {
      captured = req;
      return loginOk(token: 'abc');
    }));

    final session = await service.login(username: 'u', password: 'p');

    expect(captured.method, 'POST');
    expect(captured.url.toString(), 'http://test.local/api/v1/auth/login');
    expect(captured.headers['Content-Type'], startsWith('application/json'));
    expect(captured.headers.containsKey('Authorization'), isFalse);
    expect(jsonDecode(captured.body), {'username': 'u', 'password': 'p'});
    expect(session.token, 'abc');
    expect(session.role, 'TOURIST');
    expect(session.userId, 1);
  });

  test('401 -> invalidCredentials', () async {
    final service =
        serviceWith(MockClient((_) async => http.Response('', 401)));
    expect(await errorOf(service), AuthErrorType.invalidCredentials);
  });

  test('400 -> invalidRequest', () async {
    final service =
        serviceWith(MockClient((_) async => http.Response('', 400)));
    expect(await errorOf(service), AuthErrorType.invalidRequest);
  });

  test('403, 5xx and other non-200 -> server', () async {
    for (final code in [403, 500, 503]) {
      final service =
          serviceWith(MockClient((_) async => http.Response('', code)));
      expect(await errorOf(service), AuthErrorType.server, reason: '$code');
    }
  });

  test('malformed or incomplete 200 body -> unexpectedResponse', () async {
    for (final body in ['not json', '[]', '{"role":"TOURIST","userId":1}']) {
      final service =
          serviceWith(MockClient((_) async => http.Response(body, 200)));
      expect(await errorOf(service), AuthErrorType.unexpectedResponse,
          reason: body);
    }
  });

  test('connection failures -> network', () async {
    expect(
        await errorOf(serviceWith(
            MockClient((_) async => throw const SocketException('x')))),
        AuthErrorType.network);
    expect(
        await errorOf(serviceWith(
            MockClient((_) async => throw http.ClientException('x')))),
        AuthErrorType.network);
  });

  test('timeout -> timeout', () async {
    final service = AuthService(
      client: MockClient((_) => Completer<http.Response>().future),
      baseUrl: 'http://test.local/api/v1',
      timeout: const Duration(milliseconds: 10),
    );
    expect(await errorOf(service), AuthErrorType.timeout);
  });
}
