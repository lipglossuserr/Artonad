enum AuthErrorType {
  invalidRequest,
  invalidCredentials,
  network,
  timeout,
  unexpectedResponse,
  server,
  wrongRole,
  storage,
}

/// Safe, user-facing authentication failure. Never carries server internals.
class AuthException implements Exception {
  const AuthException(this.type);

  final AuthErrorType type;

  static const String genericMessage =
      'Something went wrong. Please try again.';

  String get message {
    switch (type) {
      case AuthErrorType.invalidRequest:
        return 'Please enter your username and password.';
      case AuthErrorType.invalidCredentials:
        return 'Incorrect username or password.';
      case AuthErrorType.network:
        return "Can't reach the server. Check your internet connection and try again.";
      case AuthErrorType.timeout:
        return 'The server took too long to respond. Please try again.';
      case AuthErrorType.unexpectedResponse:
        return 'Received an unexpected response from the server. Please try again.';
      case AuthErrorType.server:
        return 'The server ran into a problem. Please try again later.';
      case AuthErrorType.wrongRole:
        return 'This app is for tourist accounts only.';
      case AuthErrorType.storage:
        return "Couldn't save your sign-in securely on this device.";
    }
  }

  @override
  String toString() => 'AuthException(${type.name})';
}
