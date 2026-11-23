import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/geo_point.dart';

enum LocationErrorType {
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  permissionUnavailable,
  timeout,
  unavailable,
  invalidCoordinates,
  stale,
  mockNotConfigured,
  mockInvalid,
}

class LocationException implements Exception {
  const LocationException(this.type);

  final LocationErrorType type;

  String get message {
    switch (type) {
      case LocationErrorType.serviceDisabled:
        return 'Location services are turned off. Turn on GPS and try again.';
      case LocationErrorType.permissionDenied:
        return 'Location permission was denied. Allow location access so your position can be sent with the SOS.';
      case LocationErrorType.permissionDeniedForever:
        return "Location permission is permanently denied. Enable it for Artonad in your phone's Settings.";
      case LocationErrorType.permissionUnavailable:
        return "Location permission status can't be determined on this device. Check your phone's location settings.";
      case LocationErrorType.timeout:
        return "Couldn't get your location in time. Move to an open area and try again.";
      case LocationErrorType.unavailable:
        return 'Your location is currently unavailable. Please try again.';
      case LocationErrorType.invalidCoordinates:
        return 'Received an invalid location from the device. Please try again.';
      case LocationErrorType.stale:
        return 'Your device returned an outdated location. Wait a moment and try again.';
      case LocationErrorType.mockNotConfigured:
        return 'Mock GPS is not configured. Run the app with --dart-define=MOCK_LATITUDE=<lat> --dart-define=MOCK_LONGITUDE=<lng>.';
      case LocationErrorType.mockInvalid:
        return 'Mock GPS coordinates are invalid. MOCK_LATITUDE must be between -90 and 90 and MOCK_LONGITUDE between -180 and 180.';
    }
  }

  @override
  String toString() => 'LocationException(${type.name})';
}

abstract class LocationService {
  /// Throws [LocationException] on any failure.
  Future<GeoPoint> getCurrentLocation();
}

// ------------------------------------------------------------------ real GPS

enum DevicePermission { denied, deniedForever, granted, undetermined }

/// A raw position fix from the platform, before validation.
class DeviceFix {
  const DeviceFix({
    required this.latitude,
    required this.longitude,
    this.timestamp,
  });

  final double latitude;
  final double longitude;
  final DateTime? timestamp;
}

/// The only seam to the geolocator plugin, so the GPS logic below can be
/// unit-tested without a device.
abstract class GpsGateway {
  Future<bool> isLocationServiceEnabled();
  Future<DevicePermission> checkPermission();
  Future<DevicePermission> requestPermission();

  /// Requests a FRESH fix (never the last known position).
  Future<DeviceFix> getCurrentFix({required Duration timeLimit});
}

class GeolocatorGateway implements GpsGateway {
  const GeolocatorGateway();

  @override
  Future<bool> isLocationServiceEnabled() =>
      Geolocator.isLocationServiceEnabled();

  @override
  Future<DevicePermission> checkPermission() async =>
      _map(await Geolocator.checkPermission());

  @override
  Future<DevicePermission> requestPermission() async =>
      _map(await Geolocator.requestPermission());

  @override
  Future<DeviceFix> getCurrentFix({required Duration timeLimit}) async {
    try {
      final p = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: timeLimit,
        ),
      );
      return DeviceFix(
        latitude: p.latitude,
        longitude: p.longitude,
        timestamp: p.timestamp,
      );
    } on LocationServiceDisabledException {
      throw const LocationException(LocationErrorType.serviceDisabled);
    } on PermissionDeniedException {
      throw const LocationException(LocationErrorType.permissionDenied);
    }
  }

  static DevicePermission _map(LocationPermission p) {
    switch (p) {
      case LocationPermission.denied:
        return DevicePermission.denied;
      case LocationPermission.deniedForever:
        return DevicePermission.deniedForever;
      case LocationPermission.whileInUse:
      case LocationPermission.always:
        return DevicePermission.granted;
      case LocationPermission.unableToDetermine:
        return DevicePermission.undetermined;
    }
  }
}

/// Real device GPS. Order: services enabled -> permission -> fresh fix ->
/// validate range -> reject outdated fix. Anything else throws
/// [LocationException]; nothing is ever guessed or defaulted.
class GeolocatorLocationService implements LocationService {
  GeolocatorLocationService({
    GpsGateway? gateway,
    this.timeout = const Duration(seconds: 15),
    this.maxFixAge = const Duration(minutes: 2),
    DateTime Function()? now,
  })  : _gateway = gateway ?? const GeolocatorGateway(),
        _now = now ?? DateTime.now;

  final GpsGateway _gateway;

  /// How long to wait for a fix.
  final Duration timeout;

  /// A fix whose own timestamp is older than this is rejected as stale.
  final Duration maxFixAge;
  final DateTime Function() _now;

  @override
  Future<GeoPoint> getCurrentLocation() async {
    try {
      if (!await _gateway.isLocationServiceEnabled()) {
        throw const LocationException(LocationErrorType.serviceDisabled);
      }

      var permission = await _gateway.checkPermission();
      if (permission == DevicePermission.denied) {
        permission = await _gateway.requestPermission();
      }
      switch (permission) {
        case DevicePermission.granted:
          break;
        case DevicePermission.denied:
          throw const LocationException(LocationErrorType.permissionDenied);
        case DevicePermission.deniedForever:
          throw const LocationException(
              LocationErrorType.permissionDeniedForever);
        case DevicePermission.undetermined:
          throw const LocationException(
              LocationErrorType.permissionUnavailable);
      }

      final fix =
          await _gateway.getCurrentFix(timeLimit: timeout).timeout(timeout);

      final point = GeoPoint(fix.latitude, fix.longitude);
      if (!point.isValid) {
        throw const LocationException(LocationErrorType.invalidCoordinates);
      }
      final timestamp = fix.timestamp;
      if (timestamp != null &&
          _now().toUtc().difference(timestamp.toUtc()) > maxFixAge) {
        throw const LocationException(LocationErrorType.stale);
      }
      return point;
    } on LocationException {
      rethrow;
    } on TimeoutException {
      throw const LocationException(LocationErrorType.timeout);
    } catch (_) {
      throw const LocationException(LocationErrorType.unavailable);
    }
  }
}

// ------------------------------------------------------------------ mock GPS

/// Developer-only fixed position from --dart-define values. Never guesses:
/// missing values fail with [LocationErrorType.mockNotConfigured], malformed
/// or out-of-range values with [LocationErrorType.mockInvalid].
class MockLocationService implements LocationService {
  const MockLocationService({required this.latitude, required this.longitude});

  final String latitude;
  final String longitude;

  @override
  Future<GeoPoint> getCurrentLocation() async {
    final latText = latitude.trim();
    final lngText = longitude.trim();
    if (latText.isEmpty || lngText.isEmpty) {
      throw const LocationException(LocationErrorType.mockNotConfigured);
    }
    final lat = double.tryParse(latText);
    final lng = double.tryParse(lngText);
    if (lat == null || lng == null) {
      throw const LocationException(LocationErrorType.mockInvalid);
    }
    final point = GeoPoint(lat, lng);
    if (!point.isValid) {
      throw const LocationException(LocationErrorType.mockInvalid);
    }
    return point;
  }
}
