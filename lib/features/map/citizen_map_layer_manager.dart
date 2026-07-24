import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:konektizen/core/api/api_service.dart';
import 'package:konektizen/features/map/c3_local_layers_overlay.dart';
import 'package:konektizen/features/map/citizen_map_hazard_catalog.dart';
import 'package:konektizen/features/map/citizen_map_layer_data.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class CitizenMapLayerManager {
  CitizenMapLayerManager(this.controller, this.addedSources);

  final MapLibreMapController? controller;
  final Set<String> addedSources;
  static final _assetGeoJsonCache = <String, Map<String, dynamic>>{};

  static void resetRuntimeState() {
    resetC3LocalLayerRuntimeState();
  }

  static const _cityLabelLayerId = 'konektizen-city-label';
  static const _overlayBelowCandidates = [_cityLabelLayerId];

  Future<void> updateLayers({
    required bool showFlood,
    required List<int> floodReturnPeriods,
    required bool showLandslide,
    required bool showStormSurge,
    required List<int> stormSurgeAdvisories,
    required bool showTyphoon,
    required bool showQuakes,
    required bool showRainRadar,
    required bool showFaults,
    required bool showAqi,
    required bool showLocalFacilities,
    required bool showLocalHazards,
    required bool showBarangays,
    required double layerOpacity,
  }) async {
    if (controller == null) return;
    final overlayBelowLayerId = await _overlayBelowLayerId();

    await _syncNoahFloodLayer(
      showFlood,
      floodReturnPeriods,
      layerOpacity,
      overlayBelowLayerId,
    );
    await _syncNoahLandslideLayer(
      showLandslide,
      layerOpacity,
      overlayBelowLayerId,
    );
    await _syncNoahStormSurgeLayer(
      showStormSurge,
      stormSurgeAdvisories,
      layerOpacity,
      overlayBelowLayerId,
    );
    await _syncTyphoonLayer(showTyphoon, overlayBelowLayerId);
    await _syncQuakeLayer(showQuakes, overlayBelowLayerId);
    await _syncRainRadarLayer(showRainRadar, overlayBelowLayerId);
    await _syncFaultLayer(showFaults, overlayBelowLayerId);
    await _syncAqiLayer(showAqi, overlayBelowLayerId);
    await _syncBarangayBoundariesLayer(
      showBarangays,
      layerOpacity,
      overlayBelowLayerId,
    );

    await syncC3LocalLayers(
      controller,
      addedSources,
      showLocalFacilities,
      showLocalHazards,
      belowLayerId: overlayBelowLayerId,
    );
  }

  Future<void> _syncTyphoonLayer(bool show, String? belowLayerId) async {
    const sourceId = 'typhoon-live-source';
    const layerIds = [
      'typhoon-live-track',
      'typhoon-live-points',
      'typhoon-live-labels',
    ];
    if (await _syncExistingVisibility(
      show: show,
      sourceId: sourceId,
      layerIds: layerIds,
    )) {
      return;
    }

    try {
      final uri = Uri.parse('${ApiService.baseUrl}/weather/typhoon/live')
          .replace(
            queryParameters: const {
              'lat': '18.196',
              'lon': '120.598',
              'municipality': 'Laoag City',
              'province': 'Ilocos Norte',
              'region': 'Region I',
            },
          );
      final res = await http.get(uri).timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      await controller?.addGeoJsonSource(
        sourceId,
        _typhoonFeatureCollection(data),
      );
      await controller?.addLineLayer(
        sourceId,
        'typhoon-live-track',
        const LineLayerProperties(
          lineColor: [Expressions.get, 'color'],
          lineOpacity: 0.88,
          lineWidth: [
            'interpolate',
            ['linear'],
            [Expressions.zoom],
            10,
            2.2,
            16,
            4.2,
          ],
          lineDasharray: [1.3, 1.1],
        ),
        belowLayerId: belowLayerId,
        filter: const [
          '==',
          [Expressions.get, 'kind'],
          'track',
        ],
        enableInteraction: false,
      );
      await controller?.addCircleLayer(
        sourceId,
        'typhoon-live-points',
        const CircleLayerProperties(
          circleColor: [Expressions.get, 'color'],
          circleRadius: [Expressions.get, 'radius'],
          circleOpacity: 0.88,
          circleStrokeColor: '#ffffff',
          circleStrokeWidth: 2,
        ),
        belowLayerId: belowLayerId,
        filter: const [
          '!=',
          [Expressions.get, 'kind'],
          'track',
        ],
        enableInteraction: false,
      );
      await controller?.addSymbolLayer(
        sourceId,
        'typhoon-live-labels',
        const SymbolLayerProperties(
          textField: [Expressions.get, 'label'],
          textSize: 11,
          textOffset: [0, 1.45],
          textColor: '#111827',
          textHaloColor: '#ffffff',
          textHaloWidth: 1.4,
          textAllowOverlap: false,
          textOptional: true,
        ),
        belowLayerId: belowLayerId,
        filter: const [
          '!=',
          [Expressions.get, 'kind'],
          'track',
        ],
        enableInteraction: false,
      );
      addedSources.add(sourceId);
    } catch (e) {
      debugPrint('Typhoon layer fetch failed: $e');
    }
  }

  Future<void> _syncNoahFloodLayer(
    bool show,
    List<int> returnPeriods,
    double layerOpacity,
    String? belowLayerId,
  ) async {
    final opacity = layerOpacity.clamp(0.0, 1.0);
    const sourceId = 'noah-flood-national-source';
    final layerIds = <String>[
      for (final period in const [5, 25, 100]) ...[
        'noah-flood-fill-$period',
        'noah-flood-outline-$period',
      ],
    ];
    if (!show) {
      if (addedSources.contains(sourceId)) {
        await _setLayersVisible(layerIds, false);
      }
      return;
    }

    await _ensureNoahVectorSource(sourceId);
    for (final period in const [5, 25, 100]) {
      final fillId = 'noah-flood-fill-$period';
      final outlineId = 'noah-flood-outline-$period';
      final selected = returnPeriods.contains(period);
      final fill = FillLayerProperties(
        visibility: selected ? 'visible' : 'none',
        fillColor: const [
          'case',
          [
            '==',
            [
              'to-number',
              [
                'coalesce',
                [Expressions.get, 'Var'],
                1,
              ],
            ],
            1,
          ],
          '#9fcfe6',
          [
            '==',
            [
              'to-number',
              [
                'coalesce',
                [Expressions.get, 'Var'],
                1,
              ],
            ],
            2,
          ],
          '#4f97c6',
          [
            '==',
            [
              'to-number',
              [
                'coalesce',
                [Expressions.get, 'Var'],
                1,
              ],
            ],
            3,
          ],
          '#0b5f8e',
          '#4f97c6',
        ],
        fillOpacity:
            (period == 5
                ? 0.42
                : period == 25
                ? 0.46
                : 0.5) *
            opacity,
        fillOutlineColor: 'rgba(11, 95, 142, 0)',
        fillAntialias: true,
      );
      final outline = LineLayerProperties(
        visibility: selected ? 'visible' : 'none',
        lineColor: '#0b5f8e',
        lineOpacity: [
          'interpolate',
          ['linear'],
          [Expressions.zoom],
          8,
          0,
          11,
          0.02 * opacity,
          14,
          0.05 * opacity,
        ],
        lineWidth: const [
          'interpolate',
          ['linear'],
          [Expressions.zoom],
          8,
          0,
          11,
          0.08,
          14,
          0.24,
          16,
          0.36,
        ],
      );
      await _ensureVectorFillLineLayers(
        sourceId: sourceId,
        sourceLayer: 'flood_${period}yr',
        fillLayerId: fillId,
        outlineLayerId: outlineId,
        fill: fill,
        outline: outline,
        belowLayerId: belowLayerId,
      );
    }
  }

  Future<void> _syncNoahLandslideLayer(
    bool show,
    double layerOpacity,
    String? belowLayerId,
  ) async {
    final opacity = layerOpacity.clamp(0.0, 1.0);
    const sourceId = 'noah-landslide-national-source';
    const layerIds = [
      'noah-landslide-fill',
      'noah-landslide-outline',
      'noah-debris-flow-fill',
      'noah-debris-flow-outline',
    ];
    if (!show) {
      if (addedSources.contains(sourceId)) {
        await _setLayersVisible(layerIds, false);
      }
      return;
    }

    await _ensureNoahVectorSource(sourceId);
    for (final sourceLayer in const ['landslide', 'debris_flow']) {
      final debrisFlow = sourceLayer == 'debris_flow';
      final prefix = debrisFlow ? 'noah-debris-flow' : 'noah-landslide';
      final classValue = [
        'to-number',
        [
          'coalesce',
          [Expressions.get, 'HAZ'],
          1,
        ],
      ];
      final color = [
        'case',
        ['==', classValue, 1],
        '#facc15',
        ['==', classValue, 2],
        '#fb923c',
        ['==', classValue, 3],
        '#ef4444',
        ['==', classValue, 4],
        '#7f1d1d',
        '#fb923c',
      ];
      await _ensureVectorFillLineLayers(
        sourceId: sourceId,
        sourceLayer: sourceLayer,
        fillLayerId: '$prefix-fill',
        outlineLayerId: '$prefix-outline',
        fill: FillLayerProperties(
          visibility: 'visible',
          fillColor: color,
          fillOpacity: [
            '*',
            debrisFlow ? 0.62 : 0.54,
            [
              'interpolate',
              ['linear'],
              classValue,
              1,
              0.5,
              2,
              0.72,
              3,
              1,
              4,
              1,
            ],
            opacity,
          ],
          fillOutlineColor: 'rgba(127, 29, 29, 0)',
          fillAntialias: true,
        ),
        outline: LineLayerProperties(
          visibility: 'visible',
          lineColor: color,
          lineOpacity: (debrisFlow ? 0.9 : 0.72) * opacity,
          lineWidth: const [
            'interpolate',
            ['linear'],
            [Expressions.zoom],
            7,
            0.12,
            10,
            0.35,
            13,
            0.9,
            15,
            1.4,
          ],
        ),
        belowLayerId: belowLayerId,
      );
    }
  }

  Future<void> _syncNoahStormSurgeLayer(
    bool show,
    List<int> advisories,
    double layerOpacity,
    String? belowLayerId,
  ) async {
    final opacity = layerOpacity.clamp(0.0, 1.0);
    const sourceId = 'noah-storm-surge-national-source';
    final layerIds = <String>[
      for (final advisory in const [1, 2, 3, 4]) ...[
        'noah-storm-surge-fill-$advisory',
        'noah-storm-surge-outline-$advisory',
      ],
    ];
    if (!show) {
      if (addedSources.contains(sourceId)) {
        await _setLayersVisible(layerIds, false);
      }
      return;
    }

    await _ensureNoahVectorSource(sourceId);
    for (final advisory in const [1, 2, 3, 4]) {
      final selected = advisories.contains(advisory);
      final classValue = [
        'to-number',
        [
          'coalesce',
          [Expressions.get, 'HAZ'],
          1,
        ],
      ];
      final color = [
        'case',
        ['==', classValue, 1],
        '#facc15',
        ['==', classValue, 2],
        '#fb923c',
        ['==', classValue, 3],
        '#ef4444',
        '#f97316',
      ];
      await _ensureVectorFillLineLayers(
        sourceId: sourceId,
        sourceLayer: 'storm_surge_ssa$advisory',
        fillLayerId: 'noah-storm-surge-fill-$advisory',
        outlineLayerId: 'noah-storm-surge-outline-$advisory',
        fill: FillLayerProperties(
          visibility: selected ? 'visible' : 'none',
          fillColor: color,
          fillOpacity: [
            '*',
            advisory == 1
                ? 0.34
                : advisory == 2
                ? 0.38
                : advisory == 3
                ? 0.42
                : 0.46,
            [
              'interpolate',
              ['linear'],
              classValue,
              1,
              0.55,
              2,
              0.78,
              3,
              1,
            ],
            opacity,
          ],
          fillOutlineColor: 'rgba(127, 29, 29, 0)',
          fillAntialias: true,
        ),
        outline: LineLayerProperties(
          visibility: selected ? 'visible' : 'none',
          lineColor: color,
          lineOpacity: (advisory == 1 ? 0.42 : 0.58) * opacity,
          lineWidth: const [
            'interpolate',
            ['linear'],
            [Expressions.zoom],
            5,
            0.12,
            9,
            0.35,
            13,
            0.8,
          ],
        ),
        belowLayerId: belowLayerId,
      );
    }
  }

  Future<void> _syncQuakeLayer(bool show, String? belowLayerId) async {
    const sourceId = 'usgs-quake-source';
    const layerIds = ['usgs-quake-layer', 'usgs-quake-label'];
    if (await _syncExistingVisibility(
      show: show,
      sourceId: sourceId,
      layerIds: layerIds,
    )) {
      return;
    }

    try {
      final response = await http
          .get(
            Uri.parse(
              'https://earthquake.usgs.gov/earthquakes/feed/v1.0/summary/2.5_day.geojson',
            ),
          )
          .timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await controller?.addGeoJsonSource(sourceId, {
        'type': 'FeatureCollection',
        'features': quakeFeaturesNearLaoag(data),
      });
      await controller?.addCircleLayer(
        sourceId,
        'usgs-quake-layer',
        const CircleLayerProperties(
          circleColor: [Expressions.get, 'color'],
          circleRadius: [Expressions.get, 'radius'],
          circleStrokeWidth: 2,
          circleStrokeColor: '#ffffff',
        ),
        belowLayerId: belowLayerId,
        enableInteraction: false,
      );
      await controller?.addSymbolLayer(
        sourceId,
        'usgs-quake-label',
        const SymbolLayerProperties(
          textField: [Expressions.get, 'label'],
          textSize: 11,
          textOffset: [0, 1.5],
          textColor: '#111827',
          textHaloColor: '#ffffff',
          textHaloWidth: 1.4,
        ),
        belowLayerId: belowLayerId,
        enableInteraction: false,
      );
      addedSources.add(sourceId);
    } catch (e) {
      debugPrint('Error loading USGS quake data: $e');
    }
  }

  Future<void> _syncRainRadarLayer(bool show, String? belowLayerId) async {
    const sourceId = 'heavy-rainfall-radar-source';
    const layerId = 'heavy-rainfall-radar-layer';
    if (await _syncExistingVisibility(
      show: show,
      sourceId: sourceId,
      layerIds: const [layerId],
    )) {
      return;
    }

    try {
      await _ensureRasterLayer(
        sourceId: sourceId,
        layerId: layerId,
        tiles: [_latestGibsImergTileUrl()],
        opacity: 0.58,
        maxzoom: 6,
        belowLayerId: belowLayerId,
      );
    } catch (e) {
      debugPrint('Heavy rainfall NASA GIBS layer failed: $e');
    }
  }

  String _latestGibsImergTileUrl() {
    final frame = DateTime.now().toUtc().subtract(const Duration(hours: 6));
    final minute = frame.minute >= 30 ? 30 : 0;
    final rounded = DateTime.utc(
      frame.year,
      frame.month,
      frame.day,
      frame.hour,
      minute,
    );
    final time = rounded.toIso8601String().replaceFirst('.000Z', 'Z');
    return 'https://gibs.earthdata.nasa.gov/wmts/epsg3857/best/'
        'IMERG_Precipitation_Rate_30min/default/$time/'
        'GoogleMapsCompatible_Level6/{z}/{y}/{x}.png';
  }

  Future<void> _syncFaultLayer(bool show, String? belowLayerId) async {
    const sourceId = 'faults-source';
    const layerId = 'faults-layer';
    if (await _syncExistingVisibility(
      show: show,
      sourceId: sourceId,
      layerIds: const [layerId],
    )) {
      return;
    }

    try {
      final geoJson = await _loadAssetGeoJson(
        'assets/data/PhilippineFaultLines.geojson',
      );
      await controller?.addGeoJsonSource(sourceId, geoJson);
      await controller?.addLineLayer(
        sourceId,
        layerId,
        const LineLayerProperties(lineColor: '#ef4444', lineWidth: 2.0),
        belowLayerId: belowLayerId,
        enableInteraction: false,
      );
      addedSources.add(sourceId);
    } catch (e) {
      debugPrint('Failed to load local faults: $e');
    }
  }

  Future<void> _syncAqiLayer(bool show, String? belowLayerId) async {
    const sourceId = 'aqi-source';
    const layerIds = ['aqi-fill', 'aqi-outline', 'aqi-label'];
    if (await _syncExistingVisibility(
      show: show,
      sourceId: sourceId,
      layerIds: layerIds,
    )) {
      return;
    }

    try {
      final geoJson = await _buildAqiGridFeatureCollection();
      await controller?.addGeoJsonSource(sourceId, geoJson);
      await controller?.addFillLayer(
        sourceId,
        'aqi-fill',
        const FillLayerProperties(
          fillColor: [Expressions.get, 'color'],
          fillOpacity: 0.42,
        ),
        belowLayerId: belowLayerId,
        enableInteraction: false,
      );
      await controller?.addLineLayer(
        sourceId,
        'aqi-outline',
        const LineLayerProperties(
          lineColor: '#ffffff',
          lineOpacity: 0.38,
          lineWidth: 0.6,
        ),
        belowLayerId: belowLayerId,
        enableInteraction: false,
      );
      await controller?.addSymbolLayer(
        sourceId,
        'aqi-label',
        const SymbolLayerProperties(
          textField: [Expressions.get, 'label'],
          textSize: 11,
          textOffset: [0, 1.5],
          textColor: '#111827',
          textHaloColor: '#ffffff',
          textHaloWidth: 1.3,
        ),
        belowLayerId: belowLayerId,
        enableInteraction: false,
      );
      addedSources.add(sourceId);
    } catch (e) {
      debugPrint('AQI fetch failed: $e');
    }
  }

  Future<void> _syncBarangayBoundariesLayer(
    bool show,
    double layerOpacity,
    String? belowLayerId,
  ) async {
    final opacity = layerOpacity.clamp(0.0, 1.0);
    const sourceId = 'laoag-barangay-boundaries-source';
    const fillLayerId = 'laoag-barangay-boundaries-fill';
    const outlineLayerId = 'laoag-barangay-boundaries-outline';
    const labelLayerId = 'laoag-barangay-boundaries-label';

    final layerIds = [fillLayerId, outlineLayerId, labelLayerId];
    final handledExisting = await _syncExistingVisibility(
      show: show,
      sourceId: sourceId,
      layerIds: layerIds,
    );

    if (handledExisting) {
      if (show && addedSources.contains(sourceId)) {
        await controller?.setLayerProperties(
          fillLayerId,
          FillLayerProperties(fillOpacity: ['*', 0.45, opacity]),
        );
        await controller?.setLayerProperties(
          outlineLayerId,
          LineLayerProperties(lineOpacity: ['*', 0.5, opacity]),
        );
        await controller?.setLayerProperties(
          labelLayerId,
          SymbolLayerProperties(textOpacity: opacity),
        );
      }
      return;
    }

    if (!show) return;

    try {
      final geoJson = await _loadAssetGeoJson(
        'assets/data/LaoagBarangayBoundaries.geojson',
      );
      await controller?.addGeoJsonSource(sourceId, geoJson);

      await controller?.addFillLayer(
        sourceId,
        fillLayerId,
        FillLayerProperties(
          fillColor: [
            'coalesce',
            [Expressions.get, 'district_color'],
            '#cbd5e1',
          ],
          fillOpacity: ['*', 0.45, opacity],
        ),
        belowLayerId: belowLayerId,
        enableInteraction: false,
      );

      await controller?.addLineLayer(
        sourceId,
        outlineLayerId,
        LineLayerProperties(
          lineColor: '#1e3a8a',
          lineOpacity: ['*', 0.5, opacity],
          lineWidth: 1.2,
        ),
        belowLayerId: belowLayerId,
        enableInteraction: false,
      );

      await controller?.addSymbolLayer(
        sourceId,
        labelLayerId,
        SymbolLayerProperties(
          textField: [Expressions.get, 'name'],
          textSize: [
            'interpolate',
            ['linear'],
            [Expressions.zoom],
            11.5,
            8.5,
            14.5,
            11,
          ],
          textColor: '#0f172a',
          textHaloColor: '#ffffff',
          textHaloWidth: 2.0,
          textOpacity: opacity,
        ),
        belowLayerId: belowLayerId,
        enableInteraction: false,
      );

      addedSources.add(sourceId);
    } catch (e) {
      debugPrint('Failed to load barangay boundaries layer: $e');
    }
  }

  Future<Map<String, dynamic>> _buildAqiGridFeatureCollection() async {
    const latitudes = [18.13, 18.17, 18.21, 18.25];
    const longitudes = [120.54, 120.58, 120.62, 120.66];
    final points = <Map<String, double>>[];
    for (final lat in latitudes) {
      for (final lon in longitudes) {
        points.add({'lat': lat, 'lon': lon});
      }
    }

    final uri =
        Uri.parse(
          'https://air-quality-api.open-meteo.com/v1/air-quality',
        ).replace(
          queryParameters: {
            'latitude': points
                .map((point) => point['lat'].toString())
                .join(','),
            'longitude': points
                .map((point) => point['lon'].toString())
                .join(','),
            'hourly': 'us_aqi,pm2_5,nitrogen_dioxide',
            'timezone': 'Asia/Manila',
            'forecast_days': '1',
          },
        );
    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) {
      throw Exception('Open-Meteo AQI status ${res.statusCode}');
    }

    final decoded = jsonDecode(res.body);
    final entries = decoded is List ? decoded : [decoded];
    final features = <Map<String, dynamic>>[];
    for (var i = 0; i < entries.length && i < points.length; i++) {
      final entry = Map<String, dynamic>.from(entries[i] as Map? ?? {});
      final hourly = Map<String, dynamic>.from(entry['hourly'] as Map? ?? {});
      final index = _nearestAqiIndex(hourly['time'] as List? ?? const []);
      final aqi = _numAt(hourly['us_aqi'] as List? ?? const [], index);
      if (aqi == null) continue;
      final pm25 = _numAt(hourly['pm2_5'] as List? ?? const [], index);
      final no2 = _numAt(
        hourly['nitrogen_dioxide'] as List? ?? const [],
        index,
      );
      final point = points[i];
      final aqiValue = aqi.round();
      features.add({
        'type': 'Feature',
        'geometry': _aqiCellPolygon(point['lat']!, point['lon']!),
        'properties': {
          'aqi': aqiValue,
          'pm25': pm25,
          'no2': no2,
          'color': aqiColor(aqiValue),
          'label': 'AQI $aqiValue',
          'source': 'Open-Meteo Air Quality',
        },
      });
    }

    if (features.isEmpty) {
      final fallback = await _fallbackAqiFeatureCollection();
      if ((fallback['features'] as List? ?? const []).isNotEmpty) {
        return fallback;
      }
    }

    return {'type': 'FeatureCollection', 'features': features};
  }

  Future<Map<String, dynamic>> _fallbackAqiFeatureCollection() async {
    final res = await http
        .get(
          Uri.parse(
            '${ApiService.baseUrl}/weather/air-quality',
          ).replace(queryParameters: const {'lat': '18.196', 'lon': '120.598'}),
        )
        .timeout(const Duration(seconds: 5));
    if (res.statusCode != 200) {
      return {'type': 'FeatureCollection', 'features': []};
    }
    final payload = jsonDecode(res.body) as Map<String, dynamic>;
    final data = Map<String, dynamic>.from(payload['data'] as Map? ?? {});
    final aqi = (data['aqi'] as num?)?.round();
    if (aqi == null) {
      return {'type': 'FeatureCollection', 'features': []};
    }

    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': _aqiCellPolygon(
            18.196,
            120.598,
            latHalfSize: 0.055,
            lonHalfSize: 0.065,
          ),
          'properties': {
            'aqi': aqi,
            'pm25': data['pm2_5'],
            'no2': data['nitrogen_dioxide'],
            'color': aqiColor(aqi),
            'label': 'AQI $aqi',
            'source': data['sourceLabel'] ?? 'Open-Meteo Air Quality',
          },
        },
      ],
    };
  }

  Map<String, dynamic> _aqiCellPolygon(
    double lat,
    double lon, {
    double latHalfSize = 0.025,
    double lonHalfSize = 0.027,
  }) {
    return {
      'type': 'Polygon',
      'coordinates': [
        [
          [lon - lonHalfSize, lat - latHalfSize],
          [lon + lonHalfSize, lat - latHalfSize],
          [lon + lonHalfSize, lat + latHalfSize],
          [lon - lonHalfSize, lat + latHalfSize],
          [lon - lonHalfSize, lat - latHalfSize],
        ],
      ],
    };
  }

  int _nearestAqiIndex(List<dynamic> times) {
    if (times.isEmpty) return 0;
    final now = DateTime.now();
    var bestIndex = 0;
    var bestDelta = 1 << 62;
    for (var i = 0; i < times.length; i++) {
      final parsed = DateTime.tryParse(times[i].toString());
      if (parsed == null) continue;
      final delta = parsed.difference(now).inMinutes.abs();
      if (delta < bestDelta) {
        bestDelta = delta;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  num? _numAt(List<dynamic> values, int index) {
    if (index < 0 || index >= values.length) return null;
    final value = values[index];
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '');
  }

  Future<void> _ensureNoahVectorSource(String sourceId) async {
    if (addedSources.contains(sourceId)) return;
    await controller?.addSource(
      sourceId,
      VectorSourceProperties(
        tiles: [
          '${ApiService.baseUrl}/gis-intelligence/noah/tiles/{z}/{x}/{y}.pbf',
        ],
        bounds: const [116.894531, 4.631179, 126.650391, 20.935789],
        minzoom: 0,
        maxzoom: 14,
        attribution: 'Project NOAH / UP Resilience Institute / PAGASA',
      ),
    );
    addedSources.add(sourceId);
  }

  Future<void> _ensureVectorFillLineLayers({
    required String sourceId,
    required String sourceLayer,
    required String fillLayerId,
    required String outlineLayerId,
    required FillLayerProperties fill,
    required LineLayerProperties outline,
    String? belowLayerId,
  }) async {
    final existing = (await controller?.getLayerIds())
        ?.map((id) => id.toString())
        .toSet();
    if (existing?.contains(fillLayerId) == true) {
      await controller?.setLayerProperties(fillLayerId, fill);
    } else {
      await controller?.addFillLayer(
        sourceId,
        fillLayerId,
        fill,
        sourceLayer: sourceLayer,
        belowLayerId: belowLayerId,
        enableInteraction: false,
      );
    }
    if (existing?.contains(outlineLayerId) == true) {
      await controller?.setLayerProperties(outlineLayerId, outline);
    } else {
      await controller?.addLineLayer(
        sourceId,
        outlineLayerId,
        outline,
        sourceLayer: sourceLayer,
        belowLayerId: belowLayerId,
        enableInteraction: false,
      );
    }
  }

  Future<Map<String, dynamic>> _loadAssetGeoJson(String assetPath) async {
    final cached = _assetGeoJsonCache[assetPath];
    if (cached != null) return cached;

    final geoJsonString = await rootBundle.loadString(assetPath);
    final geoJson = jsonDecode(geoJsonString);
    var normalized = geoJson is Map<String, dynamic>
        ? geoJson
        : {'type': 'FeatureCollection', 'features': []};
    if (assetPath.contains('LaoagBarangayBoundaries.geojson')) {
      normalized = _preprocessBarangays(normalized);
    }
    _assetGeoJsonCache[assetPath] = normalized;
    return normalized;
  }

  Map<String, dynamic> _preprocessBarangays(Map<String, dynamic> geoJson) {
    final features = geoJson['features'];
    if (features is List) {
      for (final f in features) {
        if (f is Map<String, dynamic> &&
            f['properties'] is Map<String, dynamic>) {
          final props = f['properties'] as Map<String, dynamic>;
          final name = props['brgy_name'] ?? props['name'] ?? '';
          final code = props['brgy_code'] ?? '';

          final match = RegExp(
            r'(?:Bgy\.?\s*No\.?\s*|Barangay\s*|Brgy\s*No\.\s*)?([0-9]+(?:-[A-Z])?)',
            caseSensitive: false,
          ).firstMatch(name);
          var barangayCode = code;
          if (match != null) {
            barangayCode = match.group(1)?.toUpperCase() ?? '';
          }

          final numMatch = RegExp(r'^([0-9]+)').firstMatch(barangayCode);
          var numVal = 0;
          if (numMatch != null) {
            numVal = int.tryParse(numMatch.group(1) ?? '') ?? 0;
          }

          String districtColor = '#cbd5e1';
          String districtName = 'Unassigned';
          if (numVal >= 1 && numVal <= 9) {
            districtColor = '#F4A261';
            districtName = 'District 1 (North)';
          } else if (numVal >= 10 && numVal <= 19) {
            districtColor = '#E9C46A';
            districtName = 'District 2 (Northwest)';
          } else if (numVal >= 20 && numVal <= 29) {
            districtColor = '#FFD166';
            districtName = 'District 3 (Northeast)';
          } else if (numVal >= 30 && numVal <= 34) {
            districtColor = '#8BCF7B';
            districtName = 'District 4 (East)';
          } else if (numVal >= 35 && numVal <= 43) {
            districtColor = '#4FD1C5';
            districtName = 'District 5 (South)';
          } else if (numVal >= 44 && numVal <= 50) {
            districtColor = '#60A5FA';
            districtName = 'District 6 (Southeast)';
          } else if (numVal == 51 && barangayCode == '51-A') {
            districtColor = '#60A5FA';
            districtName = 'District 6 (Southeast)';
          } else if (numVal == 51 && barangayCode == '51-B') {
            districtColor = '#818CF8';
            districtName = 'District 7 (West)';
          } else if (numVal >= 52 && numVal <= 55) {
            districtColor = '#818CF8';
            districtName = 'District 7 (West)';
          } else if (numVal == 56 && barangayCode == '56-A') {
            districtColor = '#818CF8';
            districtName = 'District 7 (West)';
          } else if (numVal == 56 && barangayCode == '56-B') {
            districtColor = '#C084FC';
            districtName = 'District 8 (Central)';
          } else if (numVal >= 57 && numVal <= 62) {
            districtColor = '#C084FC';
            districtName = 'District 8 (Central)';
          }

          props['district_color'] = districtColor;
          props['district_name'] = districtName;
        }
      }
    }
    return geoJson;
  }

  Map<String, dynamic> _typhoonFeatureCollection(Map<String, dynamic> payload) {
    final data = Map<String, dynamic>.from(payload['data'] as Map? ?? payload);
    final track = Map<String, dynamic>.from(data['track'] as Map? ?? {});
    final storm = Map<String, dynamic>.from(data['storm'] as Map? ?? {});
    final impact = Map<String, dynamic>.from(data['impact'] as Map? ?? {});
    final active = data['active'] == true;
    final affectsLaoag = impact['affects_scope'] == true;
    final color = active ? (affectsLaoag ? '#ef4444' : '#0891b2') : '#22c55e';
    final coordinates = <List<double>>[];
    final pointFeatures = <Map<String, dynamic>>[];
    final title = [
      storm['classification']?.toString(),
      storm['name']?.toString(),
    ].where((value) => value != null && value.isNotEmpty).join(' ');

    for (final point in (track['points'] as List<dynamic>? ?? [])) {
      final pointMap = point as Map?;
      final lat = (pointMap?['lat'] as num?)?.toDouble();
      final lng = (pointMap?['lng'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      final label = (pointMap?['label'] ?? '').toString();
      coordinates.add([lng, lat]);
      pointFeatures.add({
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [lng, lat],
        },
        'properties': {
          'kind': 'track-point',
          'label': label.isEmpty ? 'Track' : label,
          'color': color,
          'radius': label == 'Now' ? 8 : 5,
        },
      });
    }

    final features = <Map<String, dynamic>>[
      if (coordinates.length > 1)
        {
          'type': 'Feature',
          'geometry': {'type': 'LineString', 'coordinates': coordinates},
          'properties': {'kind': 'track', 'color': color},
        },
      ...pointFeatures,
    ];

    if (features.isEmpty) {
      features.add(
        laoagStatusFeature(
          label: active
              ? (title.isEmpty ? 'Typhoon active' : title)
              : 'No active typhoon signal',
          color: color,
          radius: active ? 18 : 16,
        )..['properties']['kind'] = 'status',
      );
    }

    return {'type': 'FeatureCollection', 'features': features};
  }

  Future<void> _setLayersVisible(List<String> layerIds, bool visible) async {
    for (final layerId in layerIds) {
      try {
        await controller?.setLayerVisibility(layerId, visible);
      } catch (e) {
        debugPrint('Failed to set $layerId visibility to $visible: $e');
      }
    }
  }

  Future<bool> _syncExistingVisibility({
    required bool show,
    required String sourceId,
    required List<String> layerIds,
  }) async {
    if (!show) {
      if (addedSources.contains(sourceId)) {
        await _setLayersVisible(layerIds, false);
      }
      return true;
    }
    if (!addedSources.contains(sourceId)) return false;
    await _setLayersVisible(layerIds, true);
    return true;
  }

  Future<String?> _overlayBelowLayerId() async {
    final layerIds = (await controller?.getLayerIds())
        ?.map((id) => id.toString())
        .toSet();
    if (layerIds == null) return null;
    for (final candidate in _overlayBelowCandidates) {
      if (layerIds.contains(candidate)) return candidate;
    }
    return null;
  }

  Future<void> _ensureRasterLayer({
    required String sourceId,
    required String layerId,
    required List<String> tiles,
    required double opacity,
    double? maxzoom,
    String? belowLayerId,
  }) async {
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
      belowLayerId: belowLayerId,
      enableInteraction: false,
    );
    addedSources.add(sourceId);
  }
}
