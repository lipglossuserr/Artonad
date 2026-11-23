import 'dart:convert';

/// Best-effort local check of the standard `exp` claim.
///
/// Returns false when the token cannot be decoded or has no `exp`
/// (e.g. opaque mock tokens); the server's 401 remains the authority.
bool isJwtExpired(String token, {DateTime? now}) {
  final parts = token.split('.');
  if (parts.length != 3) return false;
  try {
    final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
    final claims = jsonDecode(payload);
    if (claims is! Map<String, dynamic>) return false;
    final exp = claims['exp'];
    if (exp is! num) return false;
    final expiry =
        DateTime.fromMillisecondsSinceEpoch(exp.toInt() * 1000, isUtc: true);
    return !(now ?? DateTime.now().toUtc()).isBefore(expiry);
  } catch (_) {
    return false;
  }
}
