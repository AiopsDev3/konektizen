import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

Future<Map<String, dynamic>?> queryC3LocalFeature(
  MapLibreMapController? controller,
  math.Point point, {
  bool includeFacilities = true,
  bool includeHazards = true,
}) async {
  if (controller == null) return null;
  final tapPoint = math.Point<double>(point.x.toDouble(), point.y.toDouble());
  try {
    final layers = await _existingClickableLayers(
      controller,
      includeFacilities: includeFacilities,
      includeHazards: includeHazards,
    );

    if (layers.isNotEmpty) {
      try {
        final features = await controller.queryRenderedFeaturesInRect(
          Rect.fromCenter(
            center: Offset(tapPoint.x, tapPoint.y),
            width: 72,
            height: 72,
          ),
          layers,
          null,
        );
        final rendered = _firstFeature(features);
        if (rendered != null) return rendered;
      } catch (error) {
        debugPrint('Error querying rendered C3 local layers: $error');
      }
    }

    return _nearestSourceFeature(
      controller,
      tapPoint,
      includeFacilities: includeFacilities,
      includeHazards: includeHazards,
    );
  } catch (error) {
    debugPrint('Error querying C3 local feature: $error');
    return null;
  }
}

Future<List<String>> _existingClickableLayers(
  MapLibreMapController controller, {
  required bool includeFacilities,
  required bool includeHazards,
}) async {
  final existing = (await controller.getLayerIds())
      .map((id) => id.toString())
      .toSet();
  return _clickableLayers(
    includeFacilities: includeFacilities,
    includeHazards: includeHazards,
  ).where(existing.contains).toList();
}

List<String> _clickableLayers({
  required bool includeFacilities,
  required bool includeHazards,
}) {
  return [
    if (includeFacilities) ...[
      'c3-local-facilities-symbols-icons',
      'c3-local-facilities-symbols',
      'c3-local-facilities-points',
      'c3-local-facilities-labels',
    ],
    if (includeHazards) ...[
      'c3-local-hazards-fill',
      'c3-local-hazards-outline',
      'c3-local-hazards-symbols-icons',
      'c3-local-hazards-symbols',
      'c3-local-hazards-points',
      'c3-local-hazards-labels',
    ],
  ];
}

Map<String, dynamic>? _firstFeature(List features) {
  if (features.isEmpty || features.first is! Map) return null;
  return _stringKeyedMap(features.first as Map);
}

Future<Map<String, dynamic>?> _nearestSourceFeature(
  MapLibreMapController controller,
  math.Point<double> tapPoint, {
  required bool includeFacilities,
  required bool includeHazards,
}) async {
  final sources = [
    if (includeFacilities) 'c3-local-facilities-source',
    if (includeHazards) 'c3-local-hazards-source',
  ];
  Map<String, dynamic>? nearest;
  var nearestDistance = double.infinity;

  for (final sourceId in sources) {
    List features;
    try {
      features = await controller.querySourceFeatures(sourceId, null, null);
    } catch (_) {
      continue;
    }

    for (final rawFeature in features.whereType<Map>()) {
      final feature = _stringKeyedMap(rawFeature);
      final coordinates = feature['geometry']?['coordinates'];
      if (coordinates is! List || coordinates.length < 2) continue;
      final lng = double.tryParse(coordinates[0].toString());
      final lat = double.tryParse(coordinates[1].toString());
      if (lat == null || lng == null) continue;

      final screenPoint = await controller.toScreenLocation(LatLng(lat, lng));
      final distance = _screenDistance(tapPoint, screenPoint);
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearest = feature;
      }
    }
  }

  return nearestDistance <= 72 ? nearest : null;
}

double _screenDistance(math.Point<double> a, math.Point b) {
  final dx = a.x - b.x.toDouble();
  final dy = a.y - b.y.toDouble();
  return math.sqrt((dx * dx) + (dy * dy));
}

Map<String, dynamic> _stringKeyedMap(Map source) {
  return source.map((key, value) {
    if (value is Map) return MapEntry(key.toString(), _stringKeyedMap(value));
    if (value is List) {
      return MapEntry(
        key.toString(),
        value
            .map((item) => item is Map ? _stringKeyedMap(item) : item)
            .toList(),
      );
    }
    return MapEntry(key.toString(), value);
  });
}
