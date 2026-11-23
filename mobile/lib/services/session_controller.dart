import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_exception.dart';
import 'auth_service.dart';
import 'authenticated_client.dart';
import 'jwt_utils.dart';
import 'token_storage.dart';

enum SessionStatus { unknown, unauthenticated, authenticated }

/// Holds the signed-in state. Only the JWT is persisted (secure storage).
class SessionController extends ChangeNotifier {
  SessionController({
    required AuthService authService,
    required TokenStorage storage,
  })  : _authService = authService,
        _storage = storage;

  static const String touristRole = 'TOURIST';

  final AuthService _authService;
  final TokenStorage _storage;
  SessionStatus _status = SessionStatus.unknown;
  bool _sessionExpired = false;

  /// The JWT of the current session, used to ignore late 401s that belong to
  /// an earlier session (e.g. a slow request sent before sign-out/re-login).
  String? _activeToken;

  SessionStatus get status => _status;

  /// True once after the session ended because the server rejected the JWT
  /// (401) or the stored JWT had expired. Reading it resets it, so the login
  /// screen shows the notice exactly once. Never set by wrong-password
  /// login attempts or by a manual sign-out.
  bool takeSessionExpiredNotice() {
    final value = _sessionExpired;
    _sessionExpired = false;
    return value;
  }

  /// Startup check: restore the signed-in state if a usable token exists.
  Future<void> restore() async {
    String? token;
    try {
      token = await _storage.read();
    } catch (_) {
      token = null;
    }
    if (token == null || token.isEmpty) {
      _setStatus(SessionStatus.unauthenticated);
    } else if (isJwtExpired(token)) {
      await _clearToken();
      _sessionExpired = true;
      _setStatus(SessionStatus.unauthenticated);
    } else {
      _activeToken = token;
      _setStatus(SessionStatus.authenticated);
    }
  }

  /// Throws [AuthException] on failure; no token is stored in that case.
  Future<void> login({
    required String username,
    required String password,
  }) async {
    final session =
        await _authService.login(username: username, password: password);
    if (session.role != touristRole) {
      throw const AuthException(AuthErrorType.wrongRole);
    }
    try {
      await _storage.write(session.token);
    } catch (_) {
      throw const AuthException(AuthErrorType.storage);
    }
    _sessionExpired = false;
    _activeToken = session.token;
    _setStatus(SessionStatus.authenticated);
  }

  Future<void> signOut() async {
    await _clearToken();
    _activeToken = null;
    _sessionExpired = false;
    _setStatus(SessionStatus.unauthenticated);
  }

  /// Called when an authenticated request receives 401: clears the token and
  /// returns to login with an "expired" notice. Safe to call many times at
  /// once; only the first call while signed in changes state or sets the
  /// notice. A 401 for a token that is no longer the current one (a stale
  /// response from an earlier session) is ignored. Nothing is retried here.
  Future<void> handleUnauthorized([String? rejectedToken]) async {
    if (rejectedToken != null &&
        _activeToken != null &&
        rejectedToken != _activeToken) {
      return; // stale: belongs to a previous session
    }
    if (_status != SessionStatus.authenticated) {
      return; // a parallel request already ended the session
    }
    _sessionExpired = true;
    _activeToken = null;
    _setStatus(SessionStatus.unauthenticated);
    await _clearToken();
  }

  /// For future tasks: a client that adds the Bearer token and signs the
  /// user out on 401.
  http.Client authenticatedClient(http.Client inner) => AuthenticatedClient(
        inner: inner,
        storage: _storage,
        onUnauthorized: handleUnauthorized,
      );

  Future<void> _clearToken() async {
    try {
      await _storage.delete();
    } catch (_) {
      // Nothing more we can do; state is still reset by the caller.
    }
  }

  void _setStatus(SessionStatus status) {
    _status = status;
    notifyListeners();
  }
}
