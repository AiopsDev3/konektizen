const _facilityColors = {'Facility': '#3b82f6'};

const _facilitySymbols = {
  'Hospital': '+',
  'Health Center': '+',
  'Fire Station': 'F',
  'Police Station': 'P',
  'Evacuation Center': 'E',
  'Command Center': 'C',
  'Warehouse': 'W',
  'Water Source': 'W',
};

const _hazardSymbols = {
  'Flood': '~',
  'Dengue': 'D',
  'Landslide': 'L',
  'Storm Surge': 'S',
  'Fire': 'F',
  'Earthquake': 'E',
  'Road Closure': 'R',
};

Map<String, dynamic> filterC3LocalFeatures(
  Map<String, dynamic> geoJson,
  String kind,
) {
  final features = (geoJson['features'] as List<dynamic>? ?? [])
      .whereType<Map>()
      .where((feature) => _featureKind(feature) == kind)
      .expand((feature) => _decorateFeatureWithAnchor(feature, kind))
      .toList();

  return {"type": "FeatureCollection", "features": features};
}

int countC3LocalFeatures(Map<String, dynamic> geoJson, String kind) {
  return (geoJson['features'] as List<dynamic>? ?? [])
      .whereType<Map>()
      .where((feature) => _featureKind(feature) == kind)
      .length;
}

String _featureKind(Map feature) {
  final properties = feature['properties'];
  if (properties is! Map) return '';
  return (properties['kind'] ?? '').toString();
}

List<Map<String, dynamic>> _decorateFeatureWithAnchor(
  Map feature,
  String kind,
) {
  final decorated = _decorateFeature(feature, kind);
  final geometry = decorated['geometry'];
  if (kind != 'hazard' || geometry is! Map || geometry['type'] == 'Point') {
    return [decorated];
  }

  final center = _centerCoordinates(decorated);
  if (center == null) return [decorated];
  return [
    decorated,
    {
      ...decorated,
      "geometry": {
        "type": "Point",
        "coordinates": [center.$1, center.$2],
      },
      "properties": {
        ...Map<String, dynamic>.from(decorated['properties'] as Map? ?? {}),
        "isAnchor": true,
        "showMarker": true,
        "sourceGeometryType": geometry['type']?.toString() ?? '',
      },
    },
  ];
}

Map<String, dynamic> _decorateFeature(Map feature, String kind) {
  final properties = Map<String, dynamic>.from(
    feature['properties'] as Map? ?? {},
  );
  final type = (properties['type'] ?? '').toString();
  final severity = (properties['severity'] ?? '').toString();
  final isFacility = kind == 'facility';
  final geometry = feature['geometry'];
  final geometryType = geometry is Map ? geometry['type']?.toString() : '';
  final symbol = isFacility
      ? _facilitySymbols[type] ?? 'F'
      : _hazardSymbols[type] ?? '!';
  final markerColor = isFacility
      ? _facilityColors['Facility']!
      : _hazardMarkerColor(severity);
  final fillColor = isFacility ? markerColor : '#ef4444';

  return {
    ...Map<String, dynamic>.from(feature),
    "properties": {
      ...properties,
      "symbol": symbol,
      "markerColor": markerColor,
      "markerStroke": '#0f172a',
      "markerRadius": isFacility ? 18 : 17,
      "symbolSize": isFacility ? 15 : 14,
      "showMarker": isFacility || geometryType == 'Point',
      "shapeFillColor": fillColor,
      "shapeStrokeColor": isFacility ? markerColor : '#ff0000',
      "shapeOpacity": isFacility ? 0.0 : 0.58,
      "shapeStrokeWidth": isFacility ? 0.0 : 3.4,
    },
  };
}

String _hazardMarkerColor(String severity) {
  final normalized = severity.toLowerCase().trim();
  if (normalized == 'high' || normalized == 'very high') return '#ef4444';
  return '#f59e0b';
}

(double, double)? _centerCoordinates(Map<String, dynamic> feature) {
  final properties = Map<String, dynamic>.from(
    feature['properties'] as Map? ?? {},
  );
  final lng =
      _toDouble(properties['centerLng']) ??
      _toDouble(properties['longitude']) ??
      _toDouble(properties['lng']);
  final lat =
      _toDouble(properties['centerLat']) ??
      _toDouble(properties['latitude']) ??
      _toDouble(properties['lat']);
  if (lng != null && lat != null) return (lng, lat);

  final coordinates = (feature['geometry'] as Map?)?['coordinates'];
  final bounds = _coordinateBounds(coordinates);
  if (bounds == null) return null;
  return (
    (bounds.minLng + bounds.maxLng) / 2,
    (bounds.minLat + bounds.maxLat) / 2,
  );
}

({double minLng, double minLat, double maxLng, double maxLat})?
_coordinateBounds(dynamic coordinates) {
  final pairs = <(double, double)>[];
  void collect(dynamic value) {
    if (value is! List || value.isEmpty) return;
    if (value.length >= 2 && value[0] is num && value[1] is num) {
      pairs.add(((value[0] as num).toDouble(), (value[1] as num).toDouble()));
      return;
    }
    for (final child in value) {
      collect(child);
    }
  }

  collect(coordinates);
  if (pairs.isEmpty) return null;
  var minLng = pairs.first.$1;
  var maxLng = pairs.first.$1;
  var minLat = pairs.first.$2;
  var maxLat = pairs.first.$2;
  for (final pair in pairs.skip(1)) {
    if (pair.$1 < minLng) minLng = pair.$1;
    if (pair.$1 > maxLng) maxLng = pair.$1;
    if (pair.$2 < minLat) minLat = pair.$2;
    if (pair.$2 > maxLat) maxLat = pair.$2;
  }
  return (minLng: minLng, minLat: minLat, maxLng: maxLng, maxLat: maxLat);
}

double? _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value == null) return null;
  return double.tryParse(value.toString());
}
