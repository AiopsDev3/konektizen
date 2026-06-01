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
  if (addedSources.contains('c3-local-facilities-source')) {
    await _setLocalLayerVisibility(controller, 'facilities', showFacilities);
    await _setLocalLayerVisibility(controller, 'hazards', showHazards);
    return;
  }

  try {
    final geoJson = await C3LocalLayersService.fetchGeoJson();
    debugPrint(
      'C3 local layers: '
      '${countC3LocalFeatures(geoJson, 'facility')} facilities, '
      '${countC3LocalFeatures(geoJson, 'hazard')} hazards',
    );
    await registerC3FacilityMapIcons(controller);
    await _addLocalLayer(
      controller,
      sourceId: 'c3-local-facilities-source',
      pointLayerId: 'c3-local-facilities-points',
      symbolLayerId: 'c3-local-facilities-symbols',
      labelLayerId: 'c3-local-facilities-labels',
      geoJson: filterC3LocalFeatures(geoJson, 'facility'),
      useImageIcons: true,
    );
    await _addLocalLayer(
      controller,
      sourceId: 'c3-local-hazards-source',
      pointLayerId: 'c3-local-hazards-points',
      symbolLayerId: 'c3-local-hazards-symbols',
      labelLayerId: 'c3-local-hazards-labels',
      geoJson: filterC3LocalFeatures(geoJson, 'hazard'),
    );
    addedSources.add('c3-local-facilities-source');
    addedSources.add('c3-local-hazards-source');
    await _setLocalLayerVisibility(controller, 'facilities', showFacilities);
    await _setLocalLayerVisibility(controller, 'hazards', showHazards);
  } catch (error) {
    debugPrint('C3 local layer fetch failed: $error');
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
    await controller.addSymbolLayer(
      sourceId,
      symbolLayerId,
      const SymbolLayerProperties(
        iconImage: [Expressions.get, 'iconImage'],
        iconSize: 0.46,
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
      textSize: 11,
      textOffset: [0, 1.45],
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
    } catch (_) {
      // Some layer groups intentionally omit circle layers when image icons are used.
    }
  }
}
