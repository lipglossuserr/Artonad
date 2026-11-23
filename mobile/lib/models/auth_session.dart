/// Successful login response: { "token": ..., "role": ..., "userId": ... }
class AuthSession {
  const AuthSession({
    required this.token,
    required this.role,
    required this.userId,
  });

  final String token;
  final String role;
  final int userId;

  /// Throws [FormatException] if the JSON does not match the contract.
  factory AuthSession.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Login response is not a JSON object');
    }
    final token = json['token'];
    final role = json['role'];
    final userId = json['userId'];
    if (token is! String || token.isEmpty) {
      throw const FormatException('Missing token');
    }
    if (role is! String || role.isEmpty) {
      throw const FormatException('Missing role');
    }
    if (userId is! num) {
      throw const FormatException('Missing userId');
    }
    return AuthSession(token: token, role: role, userId: userId.toInt());
  }
}
