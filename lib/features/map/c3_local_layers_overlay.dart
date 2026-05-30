import 'package:flutter/material.dart';
import 'package:konektizen/features/map/c3_local_layers_service.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

Future<void> syncC3LocalLayers(
  MapLibreMapController? controller,
  Set<String> addedSources,
) async {
  if (controller == null) return;
  if (addedSources.contains('c3-local-layers-source')) {
    await controller.setLayerVisibility('c3-local-layers-points', true);
    await controller.setLayerVisibility('c3-local-layers-labels', true);
    return;
  }

  try {
    final geoJson = await C3LocalLayersService.fetchGeoJson();
    await controller.addGeoJsonSource('c3-local-layers-source', geoJson);
    await controller.addCircleLayer(
      'c3-local-layers-source',
      'c3-local-layers-points',
      const CircleLayerProperties(
        circleColor: [Expressions.get, 'color'],
        circleRadius: 9,
        circleOpacity: 0.9,
        circleStrokeColor: '#ffffff',
        circleStrokeWidth: 2,
      ),
    );
    await controller.addSymbolLayer(
      'c3-local-layers-source',
      'c3-local-layers-labels',
      const SymbolLayerProperties(
        textField: [Expressions.get, 'name'],
        textSize: 11,
        textOffset: [0, 1.45],
        textColor: '#0f172a',
        textHaloColor: '#ffffff',
        textHaloWidth: 1.6,
      ),
    );
    addedSources.add('c3-local-layers-source');
  } catch (error) {
    debugPrint('C3 local layer fetch failed: $error');
  }
}
