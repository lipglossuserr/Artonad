import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/auth_session.dart';
import 'auth_exception.dart';

/// Calls POST /auth/login. Uses a plain (non-authenticated) client.
class AuthService {
  AuthService({
    required http.Client client,
    required String baseUrl,
    Duration timeout = const Duration(seconds: 10),
  })  : _client = client,
        _baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _timeout = timeout;

  final http.Client _client;
  final String _baseUrl;
  final Duration _timeout;

  Future<AuthSession> login({
    required String username,
    required String password,
  }) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl/auth/login'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const AuthException(AuthErrorType.timeout);
    } on http.ClientException {
      throw const AuthException(AuthErrorType.network);
    } on IOException {
      throw const AuthException(AuthErrorType.network);
    }

    if (response.statusCode == 400) {
      throw const AuthException(AuthErrorType.invalidRequest);
    }
    if (response.statusCode == 401) {
      throw const AuthException(AuthErrorType.invalidCredentials);
    }
    if (response.statusCode != 200) {
      throw const AuthException(AuthErrorType.server);
    }

    try {
      return AuthSession.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } on FormatException {
      throw const AuthException(AuthErrorType.unexpectedResponse);
    }
  }
}
