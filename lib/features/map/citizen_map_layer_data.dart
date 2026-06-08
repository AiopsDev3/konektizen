Map<String, dynamic> laoagStatusFeature({
  required String label,
  required String color,
  required double radius,
}) {
  return {
    "type": "Feature",
    "geometry": {
      "type": "Point",
      "coordinates": [120.598, 18.196],
    },
    "properties": {"label": label, "color": color, "radius": radius},
  };
}

List<Map<String, dynamic>> wildfireFeaturesNearLaoag(
  Map<String, dynamic> data,
) {
  final events = (data['events'] as List<dynamic>? ?? []);
  final features = <Map<String, dynamic>>[];

  for (final event in events) {
    final geometries = event['geometry'] as List<dynamic>? ?? [];
    if (geometries.isEmpty) continue;

    final coordinates = geometries.last['coordinates'];
    if (coordinates is! List || coordinates.length < 2) continue;

    final longitude = (coordinates[0] as num).toDouble();
    final latitude = (coordinates[1] as num).toDouble();
    if (!_isNearLaoag(latitude, longitude)) continue;

    features.add({
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [longitude, latitude],
      },
      "properties": {
        "label": event['title'] ?? "Open wildfire event",
        "color": "#f97316",
        "radius": 9,
      },
    });
  }

  if (features.isNotEmpty) return features;

  return [
    laoagStatusFeature(
      label: "No open fire event nearby",
      color: "#22c55e",
      radius: 16,
    ),
  ];
}

List<Map<String, dynamic>> quakeFeaturesNearLaoag(Map<String, dynamic> data) {
  final sourceFeatures = (data['features'] as List<dynamic>? ?? []);
  final features = <Map<String, dynamic>>[];

  for (final feature in sourceFeatures) {
    final geometry = feature['geometry'] as Map<String, dynamic>?;
    final coordinates = geometry?['coordinates'];
    if (coordinates is! List || coordinates.length < 2) continue;

    final longitude = (coordinates[0] as num).toDouble();
    final latitude = (coordinates[1] as num).toDouble();
    final depth = coordinates.length > 2 && coordinates[2] is num
        ? (coordinates[2] as num).toDouble()
        : null;
    if (!_isNearLaoag(latitude, longitude)) continue;

    final properties = feature['properties'] as Map<String, dynamic>? ?? {};
    final magnitude = (properties['mag'] as num?)?.toDouble();
    final depthColor = depth == null
        ? "#ef4444"
        : depth >= 70
        ? "#3b82f6"
        : depth >= 30
        ? "#f59e0b"
        : "#ef4444";
    features.add({
      "type": "Feature",
      "geometry": {
        "type": "Point",
        "coordinates": [longitude, latitude, if (depth != null) depth],
      },
      "properties": {
        "label": magnitude == null
            ? "Recent earthquake"
            : "M${magnitude.toStringAsFixed(1)} earthquake",
        "mag": magnitude ?? 2.5,
        "depth": depth ?? 0,
        "color": depthColor,
        "radius": magnitude == null ? 8 : (magnitude.clamp(2.5, 7.0) * 2.0),
      },
    });
  }

  if (features.isNotEmpty) return features;

  return [
    laoagStatusFeature(
      label: "No M2.5+ quake nearby today",
      color: "#22c55e",
      radius: 16,
    ),
  ];
}

bool _isNearLaoag(double latitude, double longitude) {
  return latitude >= 17.7 &&
      latitude <= 18.7 &&
      longitude >= 120.0 &&
      longitude <= 121.2;
}
