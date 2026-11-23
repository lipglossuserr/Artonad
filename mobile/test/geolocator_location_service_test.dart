import 'dart:async';

import 'package:coastguard360_mobile/services/location_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Scriptable stand-in for the geolocator plugin. Coordinates are test data.
class FakeGpsGateway implements GpsGateway {
  FakeGpsGateway({
    this.enabled = true,
    this.current = DevicePermission.granted,
    this.afterRequest,
    this.fix = const DeviceFix(latitude: 10.0, longitude: 20.0),
    this.fixError,
    this.hang = false,
  });

  bool enabled;
  DevicePermission current;
  DevicePermission? afterRequest;
  DeviceFix fix;
  Object? fixError;
  bool hang;

  int permissionChecks = 0;
  int permissionRequests = 0;
  int fixCalls = 0;
  Duration? lastTimeLimit;

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;

  @override
  Future<DevicePermission> checkPermission() async {
    permissionChecks++;
    return current;
  }

  @override
  Future<DevicePermission> requestPermission() async {
    permissionRequests++;
    return afterRequest ?? current;
  }

  @override
  Future<DeviceFix> getCurrentFix({required Duration timeLimit}) {
    fixCalls++;
    lastTimeLimit = timeLimit;
    if (hang) return Completer<DeviceFix>().future;
    if (fixError != null) return Future<DeviceFix>.error(fixError!);
    return Future.value(fix);
  }
}

final _now = DateTime.utc(2026, 1, 1, 12, 0, 0);

GeolocatorLocationService serviceWith(
  FakeGpsGateway gateway, {
  Duration timeout = const Duration(seconds: 15),
}) =>
    GeolocatorLocationService(
      gateway: gateway,
      timeout: timeout,
      maxFixAge: const Duration(minutes: 2),
      now: () => _now,
    );

Future<LocationErrorType> errorOf(GeolocatorLocationService s) async {
  try {
    await s.getCurrentLocation();
  } on LocationException catch (e) {
    return e.type;
  }
  fail('Expected LocationException');
}

void main() {
  group('happy path', () {
    test('granted permission returns the fresh fix as lat/lng', () async {
      final gateway = FakeGpsGateway();
      final point = await serviceWith(gateway).getCurrentLocation();

      expect(point.lat, 10.0);
      expect(point.lng, 20.0);
      expect(gateway.permissionRequests, 0);
      expect(gateway.fixCalls, 1);
    });

    test('requests the fix with the configured timeout', () async {
      final gateway = FakeGpsGateway();
      await serviceWith(gateway, timeout: const Duration(seconds: 7))
          .getCurrentLocation();
      expect(gateway.lastTimeLimit, const Duration(seconds: 7));
    });
  });

  group('location services', () {
    test('disabled GPS -> serviceDisabled, no permission check or fix',
        () async {
      final gateway = FakeGpsGateway(enabled: false);
      expect(await errorOf(serviceWith(gateway)),
          LocationErrorType.serviceDisabled);
      expect(gateway.permissionChecks, 0);
      expect(gateway.fixCalls, 0);
    });
  });

  group('permissions', () {
    test('denied, then granted when asked -> succeeds after one request',
        () async {
      final gateway = FakeGpsGateway(
          current: DevicePermission.denied,
          afterRequest: DevicePermission.granted);
      await serviceWith(gateway).getCurrentLocation();
      expect(gateway.permissionRequests, 1);
      expect(gateway.fixCalls, 1);
    });

    test('denied and refused -> permissionDenied, no fix', () async {
      final gateway = FakeGpsGateway(
          current: DevicePermission.denied,
          afterRequest: DevicePermission.denied);
      expect(await errorOf(serviceWith(gateway)),
          LocationErrorType.permissionDenied);
      expect(gateway.permissionRequests, 1);
      expect(gateway.fixCalls, 0);
    });

    test('denied, then permanently denied on request', () async {
      final gateway = FakeGpsGateway(
          current: DevicePermission.denied,
          afterRequest: DevicePermission.deniedForever);
      expect(await errorOf(serviceWith(gateway)),
          LocationErrorType.permissionDeniedForever);
      expect(gateway.fixCalls, 0);
    });

    test('permanently denied -> no new request is made', () async {
      final gateway = FakeGpsGateway(current: DevicePermission.deniedForever);
      expect(await errorOf(serviceWith(gateway)),
          LocationErrorType.permissionDeniedForever);
      expect(gateway.permissionRequests, 0);
      expect(gateway.fixCalls, 0);
    });

    test('undetermined permission -> permissionUnavailable', () async {
      final gateway = FakeGpsGateway(current: DevicePermission.undetermined);
      expect(await errorOf(serviceWith(gateway)),
          LocationErrorType.permissionUnavailable);
      expect(gateway.fixCalls, 0);
    });
  });

  group('timeout and failures', () {
    test('a fix that never arrives -> timeout', () async {
      final gateway = FakeGpsGateway(hang: true);
      expect(
          await errorOf(serviceWith(gateway,
              timeout: const Duration(milliseconds: 20))),
          LocationErrorType.timeout);
    });

    test('TimeoutException from the platform -> timeout', () async {
      final gateway = FakeGpsGateway(fixError: TimeoutException('slow'));
      expect(await errorOf(serviceWith(gateway)), LocationErrorType.timeout);
    });

    test('LocationException from the gateway passes through unchanged',
        () async {
      final gateway = FakeGpsGateway(
          fixError: const LocationException(LocationErrorType.serviceDisabled));
      expect(await errorOf(serviceWith(gateway)),
          LocationErrorType.serviceDisabled);
    });

    test('any other platform error -> unavailable (no internals leaked)',
        () async {
      final gateway = FakeGpsGateway(fixError: StateError('secret detail'));
      expect(await errorOf(serviceWith(gateway)),
          LocationErrorType.unavailable);
    });
  });

  group('coordinate validation', () {
    Future<LocationErrorType> forFix(double lat, double lng) => errorOf(
        serviceWith(FakeGpsGateway(fix: DeviceFix(latitude: lat, longitude: lng))));

    test('out-of-range or non-finite values -> invalidCoordinates', () async {
      expect(await forFix(90.0001, 0), LocationErrorType.invalidCoordinates);
      expect(await forFix(-90.0001, 0), LocationErrorType.invalidCoordinates);
      expect(await forFix(0, 180.0001), LocationErrorType.invalidCoordinates);
      expect(await forFix(0, -180.0001), LocationErrorType.invalidCoordinates);
      expect(await forFix(double.nan, 0), LocationErrorType.invalidCoordinates);
      expect(await forFix(0, double.infinity),
          LocationErrorType.invalidCoordinates);
    });

    test('boundary values are accepted', () async {
      for (final p in [
        const DeviceFix(latitude: 90, longitude: 180),
        const DeviceFix(latitude: -90, longitude: -180),
      ]) {
        final point = await serviceWith(FakeGpsGateway(fix: p))
            .getCurrentLocation();
        expect(point.lat, p.latitude);
        expect(point.lng, p.longitude);
      }
    });
  });

  group('stale fixes', () {
    DeviceFix fixAt(DateTime? t) =>
        DeviceFix(latitude: 10, longitude: 20, timestamp: t);

    test('older than maxFixAge -> stale', () async {
      final gateway = FakeGpsGateway(
          fix: fixAt(_now.subtract(const Duration(minutes: 3))));
      expect(await errorOf(serviceWith(gateway)), LocationErrorType.stale);
    });

    test('recent, exactly-at-limit, future and untimestamped fixes pass',
        () async {
      for (final t in [
        _now.subtract(const Duration(seconds: 30)),
        _now.subtract(const Duration(minutes: 2)),
        _now.add(const Duration(seconds: 5)),
        null,
      ]) {
        await serviceWith(FakeGpsGateway(fix: fixAt(t))).getCurrentLocation();
      }
    });
  });
}
