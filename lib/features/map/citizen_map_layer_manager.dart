import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:konektizen/features/map/citizen_map_layer_data.dart';
import 'package:konektizen/features/map/c3_local_layers_overlay.dart';
import 'package:konektizen/features/map/utils/brgy_rain_threat_util.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class CitizenMapLayerManager {
  final MapLibreMapController? controller;
  final Set<String> addedSources;

  CitizenMapLayerManager(this.controller, this.addedSources);

  Future<void> updateLayers({
    required bool showFlood,
    required bool showLandslide,
    required bool showQuakes,
    required bool showFire,
    required bool showRainRadar,
    required bool showBarangayRain,
    required bool showFaults,
    required bool showVolcanoes,
    required bool showAqi,
    required bool showSevereWeather,
    required bool showLocalFacilities,
    required bool showLocalHazards,
  }) async {
    if (controller == null) return;

    if (showFlood) {
      if (!addedSources.contains('mgb-flood-source')) {
        await _ensureRasterLayer(
          sourceId: 'mgb-flood-source',
          layerId: 'mgb-flood-layer',
          tiles: [
            "https://controlmap.mgb.gov.ph/arcgis/rest/services/GeospatialDataInventory/GDI_Detailed_Flood_Susceptibility/MapServer/tile/{z}/{y}/{x}",
          ],
          opacity: 0.55,
        );
      } else {
        await controller?.setLayerVisibility('mgb-flood-layer', true);
      }
    } else if (addedSources.contains('mgb-flood-source')) {
      await controller?.setLayerVisibility('mgb-flood-layer', false);
    }

    if (showLandslide) {
      if (!addedSources.contains('mgb-landslide-source')) {
        await _ensureRasterLayer(
          sourceId: 'mgb-landslide-source',
          layerId: 'mgb-landslide-layer',
          tiles: [
            "https://controlmap.mgb.gov.ph/arcgis/rest/services/GeospatialDataInventory/GDI_Detailed_Rain_induced_Landslide_Susceptibility/MapServer/tile/{z}/{y}/{x}",
          ],
          opacity: 0.55,
        );
      } else {
        await controller?.setLayerVisibility('mgb-landslide-layer', true);
      }
    } else if (addedSources.contains('mgb-landslide-source')) {
      await controller?.setLayerVisibility('mgb-landslide-layer', false);
    }

    if (showFire) {
      if (!addedSources.contains('nasa-fire-source')) {
        try {
          final res = await http
              .get(
                Uri.parse(
                  "https://eonet.gsfc.nasa.gov/api/v3/events?category=wildfires&status=open",
                ),
              )
              .timeout(const Duration(seconds: 8));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body) as Map<String, dynamic>;
            final features = wildfireFeaturesNearLaoag(data);
            await controller?.addGeoJsonSource('nasa-fire-source', {
              "type": "FeatureCollection",
              "features": features,
            });
            await controller?.addCircleLayer(
              'nasa-fire-source',
              'nasa-fire-layer',
              const CircleLayerProperties(
                circleColor: [Expressions.get, 'color'],
                circleRadius: [Expressions.get, 'radius'],
                circleOpacity: 0.65,
                circleStrokeWidth: 2,
                circleStrokeColor: '#ffffff',
              ),
            );
            await controller?.addSymbolLayer(
              'nasa-fire-source',
              'nasa-fire-label',
              const SymbolLayerProperties(
                textField: [Expressions.get, 'label'],
                textSize: 11,
                textOffset: [0, 1.5],
                textColor: '#111827',
                textHaloColor: '#ffffff',
                textHaloWidth: 1.4,
              ),
            );
            addedSources.add('nasa-fire-source');
          }
        } catch (e) {
          debugPrint("NASA EONET fire fetch failed: $e");
        }
      } else {
        await controller?.setLayerVisibility('nasa-fire-layer', true);
        await controller?.setLayerVisibility('nasa-fire-label', true);
      }
    } else if (addedSources.contains('nasa-fire-source')) {
      await controller?.setLayerVisibility('nasa-fire-layer', false);
      await controller?.setLayerVisibility('nasa-fire-label', false);
    }

    if (showQuakes) {
      if (!addedSources.contains('usgs-quake-source')) {
        try {
          final response = await http
              .get(
                Uri.parse(
                  "https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/2.5_day.geojson",
                ),
              )
              .timeout(const Duration(seconds: 5));
          if (response.statusCode == 200) {
            final data = jsonDecode(response.body) as Map<String, dynamic>;
            await controller?.addGeoJsonSource('usgs-quake-source', {
              "type": "FeatureCollection",
              "features": quakeFeaturesNearLaoag(data),
            });
            await controller?.addCircleLayer(
              'usgs-quake-source',
              'usgs-quake-layer',
              const CircleLayerProperties(
                circleColor: [Expressions.get, 'color'],
                circleRadius: [Expressions.get, 'radius'],
                circleStrokeWidth: 2,
                circleStrokeColor: '#ffffff',
              ),
            );
            await controller?.addSymbolLayer(
              'usgs-quake-source',
              'usgs-quake-label',
              const SymbolLayerProperties(
                textField: [Expressions.get, 'label'],
                textSize: 11,
                textOffset: [0, 1.5],
                textColor: '#111827',
                textHaloColor: '#ffffff',
                textHaloWidth: 1.4,
              ),
            );
            addedSources.add('usgs-quake-source');
          }
        } catch (e) {
          debugPrint("Error loading USGS Quake Data: $e");
        }
      } else {
        await controller?.setLayerVisibility('usgs-quake-layer', true);
        await controller?.setLayerVisibility('usgs-quake-label', true);
      }
    } else if (addedSources.contains('usgs-quake-source')) {
      await controller?.setLayerVisibility('usgs-quake-layer', false);
      await controller?.setLayerVisibility('usgs-quake-label', false);
    }

    if (showRainRadar) {
      if (!addedSources.contains('rain-radar-source')) {
        try {
          final res = await http
              .get(
                Uri.parse(
                  "https://api.rainviewer.com/public/weather-maps.json",
                ),
              )
              .timeout(const Duration(seconds: 5));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final path = data['radar']['past'].last['path'];
            await _ensureRasterLayer(
              sourceId: 'rain-radar-source',
              layerId: 'rain-radar-layer',
              tiles: [
                "https://tilecache.rainviewer.com$path/256/{z}/{x}/{y}/2/1_1.png",
              ],
              opacity: 0.6,
              maxzoom: 6,
            );
          }
        } catch (e) {
          debugPrint("Rain radar fetch failed: $e");
        }
      } else {
        await controller?.setLayerVisibility('rain-radar-layer', true);
      }
    } else if (addedSources.contains('rain-radar-source')) {
      await controller?.setLayerVisibility('rain-radar-layer', false);
    }

    if (showBarangayRain) {
      if (!addedSources.contains('brgy-rain-source')) {
        try {
          final geoJson = await BrgyRainThreatUtil.fetchAndEnrich();
          await controller?.addGeoJsonSource('brgy-rain-source', geoJson);
          await controller?.addFillLayer(
            'brgy-rain-source',
            'brgy-rain-fill',
            const FillLayerProperties(
              fillOpacity: 0.5,
            ).copyWith(
              FillLayerProperties(
                fillColor: [
                  Expressions.match,
                  [Expressions.get, 'rain_level'],
                  'very_high', '#ef4444',
                  'high', '#f97316',
                  'moderate', '#eab308',
                  'low', '#22c55e',
                  'minimal', '#0ea5e9',
                  '#38bdf8'
                ],
              )
            ),
          );
          await controller?.addLineLayer(
            'brgy-rain-source',
            'brgy-rain-line',
            const LineLayerProperties(lineColor: '#ffffff', lineWidth: 1.0),
          );
          await controller?.addSymbolLayer(
            'brgy-rain-source',
            'brgy-rain-label',
            const SymbolLayerProperties(
              textSize: 10,
              textColor: '#111827',
              textHaloColor: '#ffffff',
              textHaloWidth: 1.2,
            ).copyWith(
              SymbolLayerProperties(
                textField: [
                  Expressions.concat,
                  [Expressions.get, 'brgy_name'],
                  '\n',
                  ['to-string', [Expressions.get, 'rain_24h_mm']],
                  ' mm'
                ],
              )
            ),
          );
          addedSources.add('brgy-rain-source');
        } catch (e) {
          debugPrint("Brgy Rain Threat fetch failed: $e");
        }
      } else {
        await controller?.setLayerVisibility('brgy-rain-fill', true);
        await controller?.setLayerVisibility('brgy-rain-line', true);
        await controller?.setLayerVisibility('brgy-rain-label', true);
      }
    } else if (addedSources.contains('brgy-rain-source')) {
      await controller?.setLayerVisibility('brgy-rain-fill', false);
      await controller?.setLayerVisibility('brgy-rain-line', false);
      await controller?.setLayerVisibility('brgy-rain-label', false);
    }

    if (showFaults) {
      if (!addedSources.contains('faults-source')) {
        try {
          final geoJsonString = await rootBundle.loadString(
            'assets/data/PhilippineFaultLines.geojson',
          );
          final geoJson = jsonDecode(geoJsonString);
          await controller?.addGeoJsonSource('faults-source', geoJson);
          await controller?.addLineLayer(
            'faults-source',
            'faults-layer',
            const LineLayerProperties(lineColor: '#ef4444', lineWidth: 2.0),
          );
          addedSources.add('faults-source');
        } catch (e) {
          debugPrint("Failed to load local faults: $e");
        }
      } else {
        await controller?.setLayerVisibility('faults-layer', true);
      }
    } else if (addedSources.contains('faults-source')) {
      await controller?.setLayerVisibility('faults-layer', false);
    }

    if (showVolcanoes) {
      if (!addedSources.contains('volcano-source')) {
        try {
          final res = await http
              .get(
                Uri.parse(
                  "https://raw.githubusercontent.com/fraxen/tectonicplates/master/GeoJSON/PB2002_boundaries.json",
                ),
              )
              .timeout(const Duration(seconds: 5));
          if (res.statusCode == 200) {
            final geoJson = jsonDecode(res.body) as Map<String, dynamic>;
            final features = geoJson['features'] as List<dynamic>? ?? [];
            features.add(
              laoagStatusFeature(
                label: "Tectonic boundary source loaded",
                color: "#b91c1c",
                radius: 14,
              ),
            );
            geoJson['features'] = features;
            await controller?.addGeoJsonSource('volcano-source', geoJson);
            await controller?.addLineLayer(
              'volcano-source',
              'volcano-layer',
              const LineLayerProperties(lineColor: '#b91c1c', lineWidth: 2.5),
            );
            await controller?.addCircleLayer(
              'volcano-source',
              'volcano-status-layer',
              const CircleLayerProperties(
                circleColor: [Expressions.get, 'color'],
                circleRadius: [Expressions.get, 'radius'],
                circleOpacity: 0.45,
              ),
            );
            await controller?.addSymbolLayer(
              'volcano-source',
              'volcano-status-label',
              const SymbolLayerProperties(
                textField: [Expressions.get, 'label'],
                textSize: 11,
                textOffset: [0, 1.5],
                textColor: '#111827',
                textHaloColor: '#ffffff',
                textHaloWidth: 1.4,
              ),
            );
            addedSources.add('volcano-source');
          }
        } catch (e) {
          debugPrint("Tectonic fetch failed: $e");
        }
      } else {
        await controller?.setLayerVisibility('volcano-layer', true);
        await controller?.setLayerVisibility('volcano-status-layer', true);
        await controller?.setLayerVisibility('volcano-status-label', true);
      }
    } else if (addedSources.contains('volcano-source')) {
      await controller?.setLayerVisibility('volcano-layer', false);
      await controller?.setLayerVisibility('volcano-status-layer', false);
      await controller?.setLayerVisibility('volcano-status-label', false);
    }

    if (showAqi) {
      if (!addedSources.contains('aqi-source')) {
        try {
          final res = await http
              .get(
                Uri.parse(
                  "https://air-quality-api.open-meteo.com/v1/air-quality?latitude=18.196&longitude=120.598&current=european_aqi",
                ),
              )
              .timeout(const Duration(seconds: 5));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final aqi = data['current']['european_aqi'];
            final color = aqi > 50 ? '#ef4444' : '#22c55e';
            final aqiGeoJson = {
              "type": "FeatureCollection",
              "features": [
                {
                  "type": "Feature",
                  "geometry": {
                    "type": "Point",
                    "coordinates": [120.598, 18.196],
                  },
                  "properties": {"aqi": aqi},
                },
              ],
            };
            await controller?.addGeoJsonSource('aqi-source', aqiGeoJson);
            await controller?.addCircleLayer(
              'aqi-source',
              'aqi-layer',
              CircleLayerProperties(
                circleColor: color,
                circleRadius: 30,
                circleOpacity: 0.5,
              ),
            );
            addedSources.add('aqi-source');
          }
        } catch (e) {
          debugPrint("AQI fetch failed: $e");
        }
      } else {
        await controller?.setLayerVisibility('aqi-layer', true);
      }
    } else if (addedSources.contains('aqi-source')) {
      await controller?.setLayerVisibility('aqi-layer', false);
    }

    if (showSevereWeather) {
      if (!addedSources.contains('severe-source')) {
        try {
          final res = await http
              .get(
                Uri.parse(
                  "https://api.open-meteo.com/v1/forecast?latitude=18.196&longitude=120.598&current_weather=true",
                ),
              )
              .timeout(const Duration(seconds: 5));
          if (res.statusCode == 200) {
            final data = jsonDecode(res.body);
            final code = data['current_weather']['weathercode'];
            final severe = code >= 80;
            final severeGeoJson = {
              "type": "FeatureCollection",
              "features": [
                {
                  "type": "Feature",
                  "geometry": {
                    "type": "Point",
                    "coordinates": [120.598, 18.196],
                  },
                  "properties": {
                    "color": severe ? "#8b5cf6" : "#22c55e",
                    "radius": severe ? 60 : 22,
                    "label": severe
                        ? "Severe weather possible"
                        : "No severe weather signal",
                  },
                },
              ],
            };
            await controller?.addGeoJsonSource('severe-source', severeGeoJson);
            await controller?.addCircleLayer(
              'severe-source',
              'severe-layer',
              const CircleLayerProperties(
                circleColor: [Expressions.get, 'color'],
                circleRadius: [Expressions.get, 'radius'],
                circleOpacity: 0.3,
              ),
            );
            await controller?.addSymbolLayer(
              'severe-source',
              'severe-label',
              const SymbolLayerProperties(
                textField: [Expressions.get, 'label'],
                textSize: 11,
                textOffset: [0, 1.5],
                textColor: '#111827',
                textHaloColor: '#ffffff',
                textHaloWidth: 1.4,
              ),
            );
            addedSources.add('severe-source');
          }
        } catch (e) {
          debugPrint("Severe weather fetch failed: $e");
        }
      } else {
        await controller?.setLayerVisibility('severe-layer', true);
        await controller?.setLayerVisibility('severe-label', true);
      }
    } else if (addedSources.contains('severe-source')) {
      await controller?.setLayerVisibility('severe-layer', false);
      await controller?.setLayerVisibility('severe-label', false);
    }

    await syncC3LocalLayers(
      controller,
      addedSources,
      showLocalFacilities,
      showLocalHazards,
    );
  }

  Future<void> _ensureRasterLayer({
    required String sourceId,
    required String layerId,
    required List<String> tiles,
    required double opacity,
    double? maxzoom,
  }) async {
    if (addedSources.contains(sourceId)) return;

    await controller?.addSource(
      sourceId,
      RasterSourceProperties(
        tiles: tiles,
        tileSize: 256,
        maxzoom: maxzoom ?? 22,
      ),
    );
    await controller?.addLayer(
      sourceId,
      layerId,
      RasterLayerProperties(rasterOpacity: opacity),
    );
    addedSources.add(sourceId);
  }
}
