import 'package:flutter/material.dart';
import 'package:konektizen/features/map/c3_facility_map_icons.dart';
import 'package:konektizen/features/map/c3_local_layer_features.dart';
import 'package:konektizen/features/map/c3_local_layers_service.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

Future<void> syncC3LocalLayers(
  MapLibreMapController? controller,
  Set<String> addedSources,
  bool showFacilities,
  bool showHazards,
) async {
  if (controller == null) return;

  Map<String, dynamic>? geoJson;

  Future<void> fetchGeoJsonIfNeeded() async {
    if (geoJson == null) {
      try {
        geoJson = await C3LocalLayersService.fetchGeoJson();
        await registerC3FacilityMapIcons(controller);
      } catch (e) {
        debugPrint('Failed to fetch C3 Local GeoJson: $e');
      }
    }
  }

  // Handle Facilities
  if (showFacilities) {
    if (!addedSources.contains('c3-local-facilities-source')) {
      await fetchGeoJsonIfNeeded();
      if (geoJson != null) {
        await _addLocalLayer(
          controller,
          sourceId: 'c3-local-facilities-source',
          pointLayerId: 'c3-local-facilities-points',
          symbolLayerId: 'c3-local-facilities-symbols',
          labelLayerId: 'c3-local-facilities-labels',
          geoJson: filterC3LocalFeatures(geoJson!, 'facility'),
          useImageIcons: true,
        );
        addedSources.add('c3-local-facilities-source');
      }
    } else {
      await _setLocalLayerVisibility(controller, 'facilities', true);
    }
  } else if (addedSources.contains('c3-local-facilities-source')) {
    await _setLocalLayerVisibility(controller, 'facilities', false);
  }

  // Handle Hazards
  if (showHazards) {
    if (!addedSources.contains('c3-local-hazards-source')) {
      await fetchGeoJsonIfNeeded();
      if (geoJson != null) {
        await _addLocalLayer(
          controller,
          sourceId: 'c3-local-hazards-source',
          pointLayerId: 'c3-local-hazards-points',
          symbolLayerId: 'c3-local-hazards-symbols',
          labelLayerId: 'c3-local-hazards-labels',
          geoJson: filterC3LocalFeatures(geoJson!, 'hazard'),
        );
        addedSources.add('c3-local-hazards-source');
      }
    } else {
      await _setLocalLayerVisibility(controller, 'hazards', true);
    }
  } else if (addedSources.contains('c3-local-hazards-source')) {
    await _setLocalLayerVisibility(controller, 'hazards', false);
  }
}

Future<void> _addLocalLayer(
  MapLibreMapController controller, {
  required String sourceId,
  required String pointLayerId,
  required String symbolLayerId,
  required String labelLayerId,
  required Map<String, dynamic> geoJson,
  bool useImageIcons = false,
}) async {
  await controller.addGeoJsonSource(sourceId, geoJson);
  if (useImageIcons) {
    await controller.addCircleLayer(
      sourceId,
      pointLayerId,
      const CircleLayerProperties(
        circleColor: '#ffffff',
        circleRadius: 24,
        circleOpacity: 0.01,
        circleStrokeWidth: 0,
      ),
    );
    await controller.addSymbolLayer(
      sourceId,
      symbolLayerId,
      const SymbolLayerProperties(
        iconImage: [Expressions.get, 'iconImage'],
        iconSize: 0.85,
        iconAllowOverlap: true,
        iconIgnorePlacement: true,
      ),
    );
  } else {
    await controller.addCircleLayer(
      sourceId,
      pointLayerId,
      const CircleLayerProperties(
        circleColor: [Expressions.get, 'markerColor'],
        circleRadius: [Expressions.get, 'markerRadius'],
        circleOpacity: 0.95,
        circleStrokeColor: [Expressions.get, 'markerStroke'],
        circleStrokeWidth: 3,
      ),
    );
    await controller.addSymbolLayer(
      sourceId,
      symbolLayerId,
      const SymbolLayerProperties(
        textField: [Expressions.get, 'symbol'],
        textSize: [Expressions.get, 'symbolSize'],
        textColor: '#ffffff',
        textHaloColor: '#0f172a',
        textHaloWidth: 1.4,
        textAllowOverlap: true,
      ),
    );
  }
  await controller.addSymbolLayer(
    sourceId,
    labelLayerId,
    const SymbolLayerProperties(
      textField: [Expressions.get, 'name'],
      textSize: 12,
      textOffset: [0, 2.0],
      textColor: '#0f172a',
      textHaloColor: '#ffffff',
      textHaloWidth: 1.6,
      textAllowOverlap: true,
    ),
  );
}

Future<void> _setLocalLayerVisibility(
  MapLibreMapController controller,
  String layer,
  bool visible,
) async {
  final prefix = layer == 'hazards'
      ? 'c3-local-hazards'
      : 'c3-local-facilities';
  for (final layerId in [
    '$prefix-points',
    '$prefix-symbols',
    '$prefix-labels',
  ]) {
    try {
      await controller.setLayerVisibility(layerId, visible);
      debugPrint('Successfully set visibility for $layerId to $visible');
    } catch (e) {
      debugPrint('Failed to set visibility for $layerId: $e');
    }
  }
}
