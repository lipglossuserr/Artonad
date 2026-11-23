import 'package:http/http.dart' as http;

import 'token_storage.dart';

/// Wraps a client for future authenticated calls: adds
/// `Authorization: Bearer <token>` and, on HTTP 401, clears the token and
/// calls [onUnauthorized] with the token that was rejected (which returns the
/// user to login). Failed requests are never retried here.
class AuthenticatedClient extends http.BaseClient {
  AuthenticatedClient({
    required http.Client inner,
    required TokenStorage storage,
    required Future<void> Function(String? rejectedToken) onUnauthorized,
  })  : _inner = inner,
        _storage = storage,
        _onUnauthorized = onUnauthorized;

  final http.Client _inner;
  final TokenStorage _storage;
  final Future<void> Function(String? rejectedToken) _onUnauthorized;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await _storage.read();
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    final response = await _inner.send(request);
    if (response.statusCode == 401) {
      await _onUnauthorized(token);
    }
    return response;
  }

  @override
  void close() => _inner.close();
}
