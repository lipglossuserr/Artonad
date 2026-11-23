/// A WGS84 point written as {lat, lng} (never GeoJSON order).
class GeoPoint {
  const GeoPoint(this.lat, this.lng);

  final double lat;
  final double lng;

  static bool isValidLatitude(double v) => v.isFinite && v >= -90 && v <= 90;
  static bool isValidLongitude(double v) =>
      v.isFinite && v >= -180 && v <= 180;

  bool get isValid => isValidLatitude(lat) && isValidLongitude(lng);

  Map<String, double> toJson() => {'lat': lat, 'lng': lng};
}
