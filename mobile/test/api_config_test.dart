import 'package:coastguard360_mobile/core/config/api_config.dart';
import 'package:coastguard360_mobile/screens/config_error_screen.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

String debug(String raw) =>
    ApiConfig.resolve(rawValue: raw, allowLocalHttp: true);
String release(String raw) =>
    ApiConfig.resolve(rawValue: raw, allowLocalHttp: false);

void main() {
  group('debug builds (local http allowed)', () {
    test('missing API_BASE_URL uses the laptop backend default', () {
      expect(debug(''), 'http://172.20.10.2:8080/api/v1');
      expect(debug('   '), ApiConfig.devDefault);
    });

    test('emulator backend and https URLs are accepted', () {
      expect(
          debug('http://10.0.2.2:8080/api/v1'), 'http://10.0.2.2:8080/api/v1');
      expect(debug('https://api.example.test/api/v1'),
          'https://api.example.test/api/v1');
    });

    test('whitespace and trailing slashes are normalised', () {
      expect(debug('  http://10.0.2.2:8080/api/v1//  '),
          'http://10.0.2.2:8080/api/v1');
      expect(debug('HTTPS://api.example.test/api/v1/'),
          'HTTPS://api.example.test/api/v1');
    });
  });

  group('release and profile builds (https required)', () {
    test('a missing API_BASE_URL fails and never uses the mock', () {
      for (final raw in ['', '   ']) {
        expect(
            () => release(raw),
            throwsA(isA<ApiConfigException>()
                .having((e) => e.message, 'message', contains('API_BASE_URL'))
                .having((e) => e.message, 'message', contains('https'))),
            reason: "'$raw'");
      }
    });

    test('the dev mock default and any http:// URL are rejected', () {
      for (final raw in [
        ApiConfig.devDefault,
        'http://10.0.2.2:8080/api/v1',
        'http://localhost:8080/api/v1',
        'http://192.168.1.20:8080/api/v1',
        'http://api.example.test/api/v1',
      ]) {
        expect(() => release(raw), throwsA(isA<ApiConfigException>()),
            reason: raw);
      }
    });

    test('an explicit https URL is accepted', () {
      expect(release('https://api.example.test/api/v1'),
          'https://api.example.test/api/v1');
      expect(release('https://api.example.test:8443/api/v1/'),
          'https://api.example.test:8443/api/v1');
    });
  });

  group('malformed values are rejected in every mode', () {
    for (final raw in [
      'not a url',
      'host/api/v1',
      '//host/api/v1',
      'localhost:8080/api',
      'https://',
      'ftp://host/api/v1',
      'https://user:secret@host/api/v1',
      'https://host/api/v1?x=1',
      'https://host/api/v1#frag',
    ]) {
      test('"$raw"', () {
        expect(() => debug(raw), throwsA(isA<ApiConfigException>()));
        expect(() => release(raw), throwsA(isA<ApiConfigException>()));
      });
    }
  });

  testWidgets('ConfigErrorApp explains the problem and offers no app flow',
      (tester) async {
    await tester.pumpWidget(const ConfigErrorApp(
        message:
            'API_BASE_URL must use https:// in release and profile builds.'));

    expect(find.text('App configuration error'), findsOneWidget);
    expect(find.textContaining('API_BASE_URL must use https'), findsOneWidget);
    expect(find.text('Sign In'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });
}
