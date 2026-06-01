import 'package:konektizen/features/map/c3_facility_map_icons.dart';

const _facilityColors = {
  'Hospital': '#ef4444',
  'Health Center': '#06b6d4',
  'Fire Station': '#f97316',
  'Police Station': '#2563eb',
  'Evacuation Center': '#22c55e',
  'Command Center': '#8b5cf6',
  'Warehouse': '#64748b',
  'Water Source': '#0ea5e9',
};

const _facilityStrokes = {
  'Hospital': '#fee2e2',
  'Health Center': '#cffafe',
  'Fire Station': '#ffedd5',
  'Police Station': '#dbeafe',
  'Evacuation Center': '#dcfce7',
  'Command Center': '#ede9fe',
  'Warehouse': '#f1f5f9',
  'Water Source': '#e0f2fe',
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
      .map((feature) => _decorateFeature(feature, kind))
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

Map<String, dynamic> _decorateFeature(Map feature, String kind) {
  final properties = Map<String, dynamic>.from(
    feature['properties'] as Map? ?? {},
  );
  final type = (properties['type'] ?? '').toString();
  final isFacility = kind == 'facility';
  final symbol = _hazardSymbols[type] ?? '!';
  final markerColor = isFacility
      ? _facilityColors[type] ?? _defaultColor(kind)
      : properties['color'] ?? _defaultColor(kind);
  final markerStroke = isFacility
      ? _facilityStrokes[type] ?? '#ffffff'
      : '#ffffff';
  final iconImage = isFacility ? c3FacilityIconImageId(type) : null;

  return {
    ...Map<String, dynamic>.from(feature),
    "properties": {
      ...properties,
      if (!isFacility) "symbol": symbol,
      "markerColor": markerColor,
      "markerStroke": markerStroke,
      "symbolSize": isFacility ? 15 : 13,
      "markerRadius": isFacility ? 17 : 15,
      if (iconImage != null) "iconImage": iconImage,
    },
  };
}

String _defaultColor(String kind) => kind == 'facility' ? '#2563eb' : '#ef4444';
