import 'package:flutter/material.dart';
import 'package:konektizen/features/map/c3_local_layer_features.dart';
import 'package:konektizen/features/map/c3_local_layers_service.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

final _visibleLocalLayerKeys = <String>{};
const _shapeFilter = [
  'match',
  ['geometry-type'],
  ['Polygon', 'MultiPolygon'],
  true,
  false,
];
const _facilitySourceId = 'c3-local-facilities-source';
const _hazardSourceId = 'c3-local-hazards-source';

void resetC3LocalLayerRuntimeState() {
  _visibleLocalLayerKeys.clear();
}

Future<void> syncC3LocalLayers(
  MapLibreMapController? controller,
  Set<String> addedSources,
  bool showFacilities,
  bool showHazards, {
  String? belowLayerId,
}) async {
  if (controller == null) return;

  Map<String, dynamic>? geoJson;
  final localBelowLayerId = _externalBelowLayerId(belowLayerId);

  Future<void> fetchGeoJsonIfNeeded() async {
    if (geoJson == null) {
      try {
        geoJson = await C3LocalLayersService.fetchGeoJson();
      } catch (e) {
        debugPrint('Failed to fetch C3 Local GeoJson: $e');
      }
    }
  }

  // Handle Hazards first so facility pins remain above hazard shapes.
  if (showHazards) {
    if (addedSources.contains(_hazardSourceId) &&
        !await _hasAllLocalLayers(controller, 'hazards')) {
      await _removeLocalLayer(controller, addedSources, 'hazards');
    }
    if (!addedSources.contains(_hazardSourceId)) {
      await fetchGeoJsonIfNeeded();
      if (geoJson != null) {
        await _removeLocalLayer(controller, addedSources, 'hazards');
        await _addLocalLayer(
          controller,
          sourceId: _hazardSourceId,
          fillLayerId: 'c3-local-hazards-fill',
          outlineLayerId: 'c3-local-hazards-outline',
          geoJson: filterC3LocalFeatures(geoJson!, 'hazard'),
          includeShapes: true,
          belowLayerId: localBelowLayerId,
        );
        addedSources.add(_hazardSourceId);
      }
    }
    if (addedSources.contains(_hazardSourceId)) {
      _visibleLocalLayerKeys.add('hazards');
    }
  } else {
    await _removeLocalLayer(controller, addedSources, 'hazards');
    _visibleLocalLayerKeys.remove('hazards');
  }

  // Handle Facilities
  if (showFacilities) {
    if (addedSources.contains(_facilitySourceId) &&
        !await _hasAllLocalLayers(controller, 'facilities')) {
      await _removeLocalLayer(controller, addedSources, 'facilities');
    }
    if (!addedSources.contains(_facilitySourceId)) {
      await fetchGeoJsonIfNeeded();
      if (geoJson != null) {
        await _removeLocalLayer(controller, addedSources, 'facilities');
        await _addLocalLayer(
          controller,
          sourceId: _facilitySourceId,
          geoJson: filterC3LocalFeatures(geoJson!, 'facility'),
        );
        addedSources.add(_facilitySourceId);
      }
    }
    if (addedSources.contains(_facilitySourceId)) {
      _visibleLocalLayerKeys.add('facilities');
    }
  } else {
    await _removeLocalLayer(controller, addedSources, 'facilities');
    _visibleLocalLayerKeys.remove('facilities');
  }
}

Future<void> _addLocalLayer(
  MapLibreMapController controller, {
  required String sourceId,
  String? fillLayerId,
  String? outlineLayerId,
  required Map<String, dynamic> geoJson,
  bool includeShapes = false,
  String? belowLayerId,
}) async {
  await controller.addGeoJsonSource(sourceId, geoJson);

  if (includeShapes && fillLayerId != null && outlineLayerId != null) {
    await controller.addFillLayer(
      sourceId,
      fillLayerId,
      const FillLayerProperties(
        fillColor: [Expressions.get, 'shapeFillColor'],
        fillOpacity: [Expressions.get, 'shapeOpacity'],
        fillOutlineColor: 'rgba(255, 0, 0, 0)',
      ),
      belowLayerId: belowLayerId,
      filter: _shapeFilter,
      enableInteraction: true,
    );
    await controller.addLineLayer(
      sourceId,
      outlineLayerId,
      const LineLayerProperties(
        lineColor: [Expressions.get, 'shapeStrokeColor'],
        lineOpacity: 0.9,
        lineWidth: [
          'interpolate',
          ['linear'],
          [Expressions.zoom],
          11,
          1.8,
          16,
          4.0,
        ],
      ),
      belowLayerId: belowLayerId,
      filter: _shapeFilter,
      enableInteraction: true,
    );
  }
}

Future<bool> _hasAllLocalLayers(
  MapLibreMapController controller,
  String layer,
) async {
  final existing = (await controller.getLayerIds())
      .map((id) => id.toString())
      .toSet();
  return _coreLocalLayerIds(layer).every(existing.contains);
}

Future<void> _removeLocalLayer(
  MapLibreMapController controller,
  Set<String> addedSources,
  String layer,
) async {
  for (final layerId in _allLocalLayerIds(layer).reversed) {
    try {
      await controller.removeLayer(layerId);
    } catch (_) {}
  }
  final sourceId = layer == 'hazards' ? _hazardSourceId : _facilitySourceId;
  try {
    await controller.removeSource(sourceId);
  } catch (_) {}
  addedSources.remove(sourceId);
  _visibleLocalLayerKeys.remove(layer);
}

List<String> _coreLocalLayerIds(String layer) {
  final prefix = layer == 'hazards'
      ? 'c3-local-hazards'
      : 'c3-local-facilities';
  return [
    if (layer == 'hazards') ...['$prefix-fill', '$prefix-outline'],
  ];
}

List<String> _allLocalLayerIds(String layer) {
  final prefix = layer == 'hazards'
      ? 'c3-local-hazards'
      : 'c3-local-facilities';
  return [
    ..._coreLocalLayerIds(layer),
    '$prefix-points',
    '$prefix-symbols',
    '$prefix-symbols-icons',
    '$prefix-labels',
  ];
}

String? _externalBelowLayerId(String? layerId) {
  if (layerId == null || layerId.startsWith('c3-local-hazards')) return null;
  return layerId;
}
