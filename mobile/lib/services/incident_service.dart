import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../models/geo_point.dart';
import '../models/incident.dart';

enum IncidentErrorType {
  invalidInput,
  noteTooLong,
  validation,
  unauthorized,
  forbidden,
  network,
  timeout,
  unexpectedResponse,
  server,
}

/// Safe, user-facing SOS submission failure.
class IncidentException implements Exception {
  const IncidentException(this.type);

  final IncidentErrorType type;

  String get message {
    switch (type) {
      case IncidentErrorType.invalidInput:
        return 'Please check the emergency type, number of people and location.';
      case IncidentErrorType.noteTooLong:
        return 'The note is too long. Please keep it under 500 characters.';
      case IncidentErrorType.forbidden:
        return 'This account is not allowed to send SOS reports. Please sign in with a tourist account.';
      case IncidentErrorType.validation:
        return 'The server could not accept these SOS details. Please check them and try again.';
      case IncidentErrorType.unauthorized:
        return 'Your session has expired. Please sign in again.';
      case IncidentErrorType.network:
        return "Can't reach the server. Your SOS was not sent. Check your connection and try again.";
      case IncidentErrorType.timeout:
        return 'The server took too long to respond. Your SOS may not have been delivered; please try again.';
      case IncidentErrorType.unexpectedResponse:
        return 'Received an unexpected response from the server. Your SOS may not have been recorded; please try again.';
      case IncidentErrorType.server:
        return 'The server ran into a problem. Please try again.';
    }
  }

  @override
  String toString() => 'IncidentException(${type.name})';
}

/// POST /incidents. Pass the Task 02 authenticated client: it adds the Bearer
/// token and signs the user out on 401. The reporter is never sent; the
/// backend reads it from the JWT.
class IncidentService {
  IncidentService({
    required http.Client client,
    required String baseUrl,
    Duration timeout = const Duration(seconds: 15),
  })  : _client = client,
        _baseUrl = baseUrl.endsWith('/')
            ? baseUrl.substring(0, baseUrl.length - 1)
            : baseUrl,
        _timeout = timeout;

  static const Set<String> allowedTypes = {'FIRE', 'DROWNING'};
  static const int minPeople = 1;
  static const int maxPeople = 100;

  /// Backend limit (CreateIncidentRequest @Size(max = 500) / openapi.yaml).
  static const int maxNoteLength = 500;

  final http.Client _client;
  final String _baseUrl;
  final Duration _timeout;

  Future<Incident> createIncident({
    required String type,
    required int peopleCount,
    String? note,
    required GeoPoint location,
  }) async {
    if (!allowedTypes.contains(type) ||
        peopleCount < minPeople ||
        peopleCount > maxPeople ||
        !location.isValid) {
      throw const IncidentException(IncidentErrorType.invalidInput);
    }

    final trimmedNote = note?.trim() ?? '';
    if (trimmedNote.length > maxNoteLength) {
      throw const IncidentException(IncidentErrorType.noteTooLong);
    }
    final body = <String, Object>{
      'type': type,
      'peopleCount': peopleCount,
      if (trimmedNote.isNotEmpty) 'note': trimmedNote,
      'location': location.toJson(),
    };

    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl/incidents'),
            headers: const {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const IncidentException(IncidentErrorType.timeout);
    } on http.ClientException {
      throw const IncidentException(IncidentErrorType.network);
    } on IOException {
      throw const IncidentException(IncidentErrorType.network);
    }

    final code = response.statusCode;
    if (code != 201) {
      switch (code) {
        case 400:
          throw const IncidentException(IncidentErrorType.validation);
        case 401: // the authenticated client has already ended the session
          throw const IncidentException(IncidentErrorType.unauthorized);
        case 403: // signed in, but not allowed; the session stays
          throw const IncidentException(IncidentErrorType.forbidden);
        default: // 5xx and anything else unexpected: no internals exposed
          throw const IncidentException(IncidentErrorType.server);
      }
    }

    try {
      // JSON is UTF-8; response.body would assume latin1 when the server
      // sends no charset, which garbles non-ASCII zone names.
      return Incident.fromJson(jsonDecode(utf8.decode(response.bodyBytes)));
    } on FormatException {
      throw const IncidentException(IncidentErrorType.unexpectedResponse);
    }
  }
}
