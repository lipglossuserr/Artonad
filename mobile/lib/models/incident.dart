/// The parts of the incident detail response the tourist app uses.
/// nearestResort and recommendedResponders are intentionally ignored:
/// they are for the admin dashboard, not the tourist.
class Incident {
  const Incident({required this.id, required this.status, this.zoneName});

  final int id;
  final String status;
  final String? zoneName;

  /// Throws [FormatException] if required fields are missing or mistyped.
  factory Incident.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Incident response is not a JSON object');
    }
    final id = json['id'];
    final status = json['status'];
    if (id is! num) throw const FormatException('Missing id');
    if (status is! String || status.isEmpty) {
      throw const FormatException('Missing status');
    }
    final zone = json['zone'];
    String? zoneName;
    if (zone is Map<String, dynamic>) {
      final name = zone['name'];
      if (name is String && name.trim().isNotEmpty) zoneName = name.trim();
    }
    return Incident(id: id.toInt(), status: status, zoneName: zoneName);
  }
}
