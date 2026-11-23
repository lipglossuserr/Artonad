import 'package:coastguard360_mobile/models/geo_point.dart';
import 'package:coastguard360_mobile/services/location_service.dart';
import 'package:flutter_test/flutter_test.dart';

Future<LocationErrorType> errorOf(MockLocationService s) async {
  try {
    await s.getCurrentLocation();
  } on LocationException catch (e) {
    return e.type;
  }
  fail('Expected LocationException');
}

void main() {
  group('GeoPoint', () {
    test('validates ranges', () {
      expect(const GeoPoint(0, 0).isValid, isTrue);
      expect(const GeoPoint(90, 180).isValid, isTrue);
      expect(const GeoPoint(-90, -180).isValid, isTrue);
      expect(const GeoPoint(90.1, 0).isValid, isFalse);
      expect(const GeoPoint(0, 180.1).isValid, isFalse);
      expect(GeoPoint(double.nan, 0).isValid, isFalse);
    });

    test('toJson uses lat/lng keys', () {
      expect(const GeoPoint(1.5, 2.5).toJson(), {'lat': 1.5, 'lng': 2.5});
    });
  });

  group('MockLocationService', () {
    test('returns configured coordinates', () async {
      final p = await const MockLocationService(latitude: '1.5', longitude: ' 2.5 ')
          .getCurrentLocation();
      expect(p.lat, 1.5);
      expect(p.lng, 2.5);
    });

    test('missing values -> mockNotConfigured', () async {
      expect(await errorOf(const MockLocationService(latitude: '', longitude: '')),
          LocationErrorType.mockNotConfigured);
      expect(await errorOf(const MockLocationService(latitude: '1', longitude: '')),
          LocationErrorType.mockNotConfigured);
    });

    test('whitespace-only values count as missing', () async {
      expect(await errorOf(const MockLocationService(latitude: '  ', longitude: '2')),
          LocationErrorType.mockNotConfigured);
    });

    test('non-numeric or out-of-range -> mockInvalid (never a default)',
        () async {
      for (final pair in const [
        ['abc', '2'],
        ['1', 'xyz'],
        ['91', '2'],
        ['-91', '2'],
        ['1', '181'],
        ['1', '-181'],
        ['NaN', '2'],
        ['1', 'Infinity'],
      ]) {
        expect(
            await errorOf(
                MockLocationService(latitude: pair[0], longitude: pair[1])),
            LocationErrorType.mockInvalid,
            reason: pair.join(','));
      }
    });

    test('boundary values are accepted', () async {
      final p = await const MockLocationService(latitude: '-90', longitude: '180')
          .getCurrentLocation();
      expect(p.lat, -90);
      expect(p.lng, 180);
    });

    test('missing and invalid have different messages', () {
      expect(const LocationException(LocationErrorType.mockNotConfigured).message,
          isNot(const LocationException(LocationErrorType.mockInvalid).message));
    });
  });

  test('every location error has a user-facing message', () {
    for (final t in LocationErrorType.values) {
      expect(LocationException(t).message, isNotEmpty);
    }
  });
}
