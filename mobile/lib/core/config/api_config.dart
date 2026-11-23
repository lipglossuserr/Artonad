/// Thrown when API_BASE_URL is unusable for the current build mode.
class ApiConfigException implements Exception {
  const ApiConfigException(this.message);

  final String message;

  @override
  String toString() => 'ApiConfigException: $message';
}

/// Validates the API base URL. Pure (no Flutter, no environment access) so
/// every rule can be unit-tested.
class ApiConfig {
  ApiConfig._();

  /// Development default: the backend on the laptop's hotspot interface.
  static const String devDefault = 'http://172.20.10.2:8080/api/v1';

  /// [rawValue] is the --dart-define=API_BASE_URL value ('' when not given).
  ///
  /// [allowLocalHttp] is true ONLY in debug builds. Outside debug (release and
  /// profile) the URL must be given explicitly and must be https.
  static String resolve({
    required String rawValue,
    required bool allowLocalHttp,
  }) {
    final value = rawValue.trim();

    if (value.isEmpty) {
      if (allowLocalHttp) return devDefault;
      throw const ApiConfigException(
          'API_BASE_URL is not set. Build with '
          '--dart-define=API_BASE_URL=https://<host>/api/v1');
    }

    final uri = Uri.tryParse(value);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const ApiConfigException(
          'API_BASE_URL is not a valid absolute URL.');
    }
    final scheme = uri.scheme.toLowerCase();
    if (scheme != 'https' && scheme != 'http') {
      throw const ApiConfigException(
          'API_BASE_URL must start with https:// (http:// is allowed in '
          'debug builds only).');
    }
    if (scheme == 'http' && !allowLocalHttp) {
      throw const ApiConfigException(
          'API_BASE_URL must use https:// in release and profile builds.');
    }
    if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
      throw const ApiConfigException(
          'API_BASE_URL must not contain credentials, a query or a fragment.');
    }
    return value.replaceAll(RegExp(r'/+$'), '');
  }
}
