import 'dart:convert';

import 'package:coastguard360_mobile/models/geo_point.dart';
import 'package:coastguard360_mobile/services/auth_service.dart';
import 'package:coastguard360_mobile/services/location_service.dart';
import 'package:coastguard360_mobile/services/session_controller.dart';
import 'package:coastguard360_mobile/services/token_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class FakeTokenStorage implements TokenStorage {
  FakeTokenStorage({this.token, this.failOnWrite = false});

  String? token;
  final bool failOnWrite;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String value) async {
    if (failOnWrite) throw StateError('write failed');
    token = value;
  }

  @override
  Future<void> delete() async => token = null;
}

http.Response jsonResponse(Object body, int status) => http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

http.Response loginOk({String role = 'TOURIST', String token = 'test-token'}) =>
    jsonResponse({'token': token, 'role': role, 'userId': 1}, 200);

SessionController makeSession(MockClient client, FakeTokenStorage storage) =>
    SessionController(
      authService:
          AuthService(client: client, baseUrl: 'http://test.local/api/v1'),
      storage: storage,
    );

/// Test-only coordinates (taken from the contract's sample request).
const GeoPoint testPoint = GeoPoint(21.4272, 92.0058);

class FakeLocationService implements LocationService {
  FakeLocationService({this.point = testPoint, this.error});

  final GeoPoint point;
  final LocationException? error;
  int calls = 0;

  @override
  Future<GeoPoint> getCurrentLocation() async {
    calls++;
    if (error != null) throw error!;
    return point;
  }
}

/// Full incident detail as the backend returns it (tourist app ignores
/// nearestResort and recommendedResponders).
Map<String, dynamic> incidentJson({
  int id = 101,
  String status = 'REPORTED',
  bool withZone = true,
}) =>
    {
      'id': id,
      'type': 'DROWNING',
      'severity': 'HIGH',
      'peopleCount': 2,
      'note': 'Child in water near rocks',
      'location': {'lat': 21.4272, 'lng': 92.0058},
      'status': status,
      'zone': withZone ? {'id': 3, 'name': 'North Beach High-Risk'} : null,
      'nearestResort': {'id': 2, 'name': 'Sea Pearl Resort', 'distanceM': 420},
      'recommendedResponders': [
        {'id': 7, 'name': 'Rahim', 'role': 'LIFEGUARD', 'distanceM': 310}
      ],
      'createdAt': '2026-11-20T10:15:00Z',
    };
