import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:konektizen/core/api/api_service.dart';
import 'package:konektizen/features/map/c3_local_layers_overlay.dart';
import 'package:konektizen/features/map/citizen_map_layer_data.dart';
import 'package:konektizen/features/map/utils/brgy_rain_threat_util.dart';
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
  static const _noahFloodAsset =
      'assets/data/NOAH_Flood_IlocosNorte_Laoag.geojson';
  static const _noahLandslideAsset =
      'assets/data/NOAH_Landslide_IlocosNorte_Laoag.geojson';
  static const _noahStormSurgeAsset =
      'assets/data/NOAH_StormSurge_IlocosNorte_Laoag.geojson';
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
    required bool showBarangayRain,
    required bool showFaults,
    required bool showAqi,
    required bool showSevereWeather,
    required bool showLocalFacilities,
    required bool showLocalHazards,
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
    await _syncBarangayRainLayer(showBarangayRain, overlayBelowLayerId);
    await _syncFaultLayer(showFaults, overlayBelowLayerId);
    await _syncAqiLayer(showAqi, overlayBelowLayerId);
    await _syncSevereWeatherLayer(showSevereWeather, overlayBelowLayerId);

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
    await _syncGeoJsonFillLineLayer(
      show: show,
      sourceId: 'noah-flood-local-source',
      fillLayerId: 'noah-flood-local-fill',
      outlineLayerId: 'noah-flood-local-outline',
      assetPath: _noahFloodAsset,
      filter: _inFilter('return_period', returnPeriods),
      fillProperties: FillLayerProperties(
        fillColor: [
          Expressions.match,
          [
            'to-string',
            [Expressions.get, 'var'],
          ],
          '1',
          '#9fcfe6',
          '2',
          '#4f97c6',
          '3',
          '#0b5f8e',
          '#4f97c6',
        ],
        fillOpacity: [
          '*',
          [
            'interpolate',
            ['linear'],
            [Expressions.get, 'return_period'],
            5,
            0.5,
            25,
            0.54,
            100,
            0.58,
          ],
          opacity,
        ],
        fillOutlineColor: 'rgba(11, 95, 142, 0)',
      ),
      outlineProperties: LineLayerProperties(
        lineColor: '#0b5f8e',
        lineOpacity: [
          '*',
          [
            'interpolate',
            ['linear'],
            [Expressions.zoom],
            8,
            0,
            11,
            0.03,
            14,
            0.07,
          ],
          opacity,
        ],
        lineWidth: [
          'interpolate',
          ['linear'],
          [Expressions.zoom],
          11,
          0.1,
          16,
          0.35,
        ],
      ),
      belowLayerId: belowLayerId,
    );
  }

  Future<void> _syncNoahLandslideLayer(
    bool show,
    double layerOpacity,
    String? belowLayerId,
  ) async {
    final opacity = layerOpacity.clamp(0.0, 1.0);
    await _syncGeoJsonFillLineLayer(
      show: show,
      sourceId: 'noah-landslide-local-source',
      fillLayerId: 'noah-landslide-local-fill',
      outlineLayerId: 'noah-landslide-local-outline',
      assetPath: _noahLandslideAsset,
      fillProperties: FillLayerProperties(
        fillColor: [
          'coalesce',
          [Expressions.get, 'fillColor'],
          '#22c55e',
        ],
        fillOpacity: [
          '*',
          [
            'interpolate',
            ['linear'],
            [
              'coalesce',
              [Expressions.get, 'lh'],
              1,
            ],
            1,
            0.32,
            2,
            0.44,
            3,
            0.58,
          ],
          opacity,
        ],
      ),
      outlineProperties: LineLayerProperties(
        lineColor: [
          'coalesce',
          [Expressions.get, 'fillColor'],
          '#22c55e',
        ],
        lineOpacity: ['*', 0.66, opacity],
        lineWidth: [
          'interpolate',
          ['linear'],
          [Expressions.zoom],
          11,
          0.45,
          16,
          1.15,
        ],
      ),
      belowLayerId: belowLayerId,
    );
  }

  Future<void> _syncNoahStormSurgeLayer(
    bool show,
    List<int> advisories,
    double layerOpacity,
    String? belowLayerId,
  ) async {
    final opacity = layerOpacity.clamp(0.0, 1.0);
    await _syncGeoJsonFillLineLayer(
      show: show,
      sourceId: 'noah-storm-surge-local-source',
      fillLayerId: 'noah-storm-surge-local-fill',
      outlineLayerId: 'noah-storm-surge-local-outline',
      assetPath: _noahStormSurgeAsset,
      filter: _inFilter('advisory', advisories),
      fillProperties: FillLayerProperties(
        fillColor: [
          'coalesce',
          [Expressions.get, 'fillColor'],
          '#fb923c',
        ],
        fillOpacity: [
          '*',
          [
            'interpolate',
            ['linear'],
            [
              'coalesce',
              [Expressions.get, 'advisory'],
              1,
            ],
            1,
            0.28,
            4,
            0.48,
          ],
          opacity,
        ],
      ),
      outlineProperties: LineLayerProperties(
        lineColor: [
          'coalesce',
          [Expressions.get, 'fillColor'],
          '#fb923c',
        ],
        lineOpacity: ['*', 0.7, opacity],
        lineWidth: [
          'interpolate',
          ['linear'],
          [Expressions.zoom],
          11,
          0.45,
          16,
          1.1,
        ],
      ),
      belowLayerId: belowLayerId,
    );
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
    const sourceId = 'rain-radar-source';
    const layerId = 'rain-radar-layer';
    if (await _syncExistingVisibility(
      show: show,
      sourceId: sourceId,
      layerIds: const [layerId],
    )) {
      return;
    }

    try {
      final res = await http
          .get(Uri.parse('https://api.rainviewer.com/public/weather-maps.json'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body);
      final path = data['radar']['past'].last['path'];
      await _ensureRasterLayer(
        sourceId: sourceId,
        layerId: layerId,
        tiles: [
          'https://tilecache.rainviewer.com$path/256/{z}/{x}/{y}/2/1_1.png',
        ],
        opacity: 0.6,
        maxzoom: 6,
        belowLayerId: belowLayerId,
      );
    } catch (e) {
      debugPrint('Rain radar fetch failed: $e');
    }
  }

  Future<void> _syncBarangayRainLayer(bool show, String? belowLayerId) async {
    const sourceId = 'brgy-rain-source';
    const layerIds = ['brgy-rain-fill', 'brgy-rain-line', 'brgy-rain-label'];
    if (await _syncExistingVisibility(
      show: show,
      sourceId: sourceId,
      layerIds: layerIds,
    )) {
      return;
    }

    try {
      final geoJson = await BrgyRainThreatUtil.fetchAndEnrich();
      await controller?.addGeoJsonSource(sourceId, geoJson);
      await controller?.addFillLayer(
        sourceId,
        'brgy-rain-fill',
        const FillLayerProperties(
          fillColor: [
            Expressions.match,
            [Expressions.get, 'rain_level'],
            'very_high',
            '#ef4444',
            'high',
            '#f97316',
            'moderate',
            '#eab308',
            'low',
            '#22c55e',
            'minimal',
            '#0ea5e9',
            '#38bdf8',
          ],
          fillOpacity: 0.5,
        ),
        belowLayerId: belowLayerId,
        enableInteraction: false,
      );
      await controller?.addLineLayer(
        sourceId,
        'brgy-rain-line',
        const LineLayerProperties(lineColor: '#ffffff', lineWidth: 1.0),
        belowLayerId: belowLayerId,
        enableInteraction: false,
      );
      await controller?.addSymbolLayer(
        sourceId,
        'brgy-rain-label',
        const SymbolLayerProperties(
          textField: [
            Expressions.concat,
            [Expressions.get, 'brgy_name'],
            '\n',
            [
              'to-string',
              [Expressions.get, 'rain_24h_mm'],
            ],
            ' mm',
          ],
          textSize: 10,
          textColor: '#111827',
          textHaloColor: '#ffffff',
          textHaloWidth: 1.2,
        ),
        belowLayerId: belowLayerId,
        enableInteraction: false,
      );
      addedSources.add(sourceId);
    } catch (e) {
      debugPrint('Barangay rain threat fetch failed: $e');
    }
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
    const layerIds = ['aqi-layer', 'aqi-label'];
    if (await _syncExistingVisibility(
      show: show,
      sourceId: sourceId,
      layerIds: layerIds,
    )) {
      return;
    }

    try {
      final res = await http
          .get(
            Uri.parse('${ApiService.baseUrl}/weather/air-quality').replace(
              queryParameters: const {'lat': '18.196', 'lon': '120.598'},
            ),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return;

      final payload = jsonDecode(res.body) as Map<String, dynamic>;
      final data = Map<String, dynamic>.from(payload['data'] as Map? ?? {});
      final aqi = (data['aqi'] as num?)?.round() ?? 0;
      final color = _aqiColor(aqi);
      await controller?.addGeoJsonSource(sourceId, {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [120.598, 18.196],
            },
            'properties': {
              'aqi': aqi,
              'label': 'US AQI $aqi',
              'color': color,
              'radius': 42,
            },
          },
        ],
      });
      await controller?.addCircleLayer(
        sourceId,
        'aqi-layer',
        const CircleLayerProperties(
          circleColor: [Expressions.get, 'color'],
          circleRadius: [Expressions.get, 'radius'],
          circleOpacity: 0.32,
          circleStrokeColor: '#ffffff',
          circleStrokeWidth: 1.4,
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

  Future<void> _syncSevereWeatherLayer(bool show, String? belowLayerId) async {
    const sourceId = 'severe-source';
    const layerIds = ['severe-layer', 'severe-label'];
    if (await _syncExistingVisibility(
      show: show,
      sourceId: sourceId,
      layerIds: layerIds,
    )) {
      return;
    }

    try {
      final res = await http
          .get(
            Uri.parse(
              'https://api.open-meteo.com/v1/forecast?latitude=18.196&longitude=120.598&current_weather=true',
            ),
          )
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return;

      final data = jsonDecode(res.body);
      final severe = data['current_weather']['weathercode'] >= 80;
      await controller?.addGeoJsonSource(sourceId, {
        'type': 'FeatureCollection',
        'features': [
          laoagStatusFeature(
            label: severe
                ? 'Severe weather possible'
                : 'No severe weather signal',
            color: severe ? '#8b5cf6' : '#22c55e',
            radius: severe ? 60 : 22,
          ),
        ],
      });
      await controller?.addCircleLayer(
        sourceId,
        'severe-layer',
        const CircleLayerProperties(
          circleColor: [Expressions.get, 'color'],
          circleRadius: [Expressions.get, 'radius'],
          circleOpacity: 0.3,
        ),
        belowLayerId: belowLayerId,
        enableInteraction: false,
      );
      await controller?.addSymbolLayer(
        sourceId,
        'severe-label',
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
      debugPrint('Severe weather fetch failed: $e');
    }
  }

  Future<void> _syncGeoJsonFillLineLayer({
    required bool show,
    required String sourceId,
    required String fillLayerId,
    required String outlineLayerId,
    required String assetPath,
    required FillLayerProperties fillProperties,
    required LineLayerProperties outlineProperties,
    dynamic filter,
    String? belowLayerId,
  }) async {
    final layerIds = [fillLayerId, outlineLayerId];
    final handledExisting = await _syncExistingVisibility(
      show: show,
      sourceId: sourceId,
      layerIds: layerIds,
    );
    if (handledExisting) {
      if (show && addedSources.contains(sourceId)) {
        await _refreshFillLineLayer(
          fillLayerId,
          outlineLayerId,
          fillProperties,
          outlineProperties,
          filter,
        );
      }
      return;
    }

    try {
      final geoJson = await _loadAssetGeoJson(assetPath);
      await controller?.addGeoJsonSource(sourceId, geoJson);
      await controller?.addFillLayer(
        sourceId,
        fillLayerId,
        fillProperties,
        belowLayerId: belowLayerId,
        filter: filter,
        enableInteraction: false,
      );
      await controller?.addLineLayer(
        sourceId,
        outlineLayerId,
        outlineProperties,
        belowLayerId: belowLayerId,
        filter: filter,
        enableInteraction: false,
      );
      addedSources.add(sourceId);
    } catch (e) {
      debugPrint('Failed to load $assetPath: $e');
    }
  }

  Future<void> _refreshFillLineLayer(
    String fillLayerId,
    String outlineLayerId,
    FillLayerProperties fillProperties,
    LineLayerProperties outlineProperties,
    dynamic filter,
  ) async {
    try {
      await controller?.setLayerProperties(fillLayerId, fillProperties);
      await controller?.setLayerProperties(outlineLayerId, outlineProperties);
      if (filter != null) {
        await controller?.setFilter(fillLayerId, filter);
        await controller?.setFilter(outlineLayerId, filter);
      }
    } catch (e) {
      debugPrint('Failed to refresh $fillLayerId/$outlineLayerId: $e');
    }
  }

  Future<Map<String, dynamic>> _loadAssetGeoJson(String assetPath) async {
    final cached = _assetGeoJsonCache[assetPath];
    if (cached != null) return cached;

    final geoJsonString = await rootBundle.loadString(assetPath);
    final geoJson = jsonDecode(geoJsonString);
    final normalized = geoJson is Map<String, dynamic>
        ? geoJson
        : {'type': 'FeatureCollection', 'features': []};
    _assetGeoJsonCache[assetPath] = normalized;
    return normalized;
  }

  List<dynamic> _inFilter(String property, List<int> values) {
    return [
      'in',
      [Expressions.get, property],
      ['literal', values],
    ];
  }

  String _aqiColor(int value) {
    if (value <= 50) return '#00e400';
    if (value <= 100) return '#ffff00';
    if (value <= 150) return '#ff7e00';
    if (value <= 200) return '#ff0000';
    if (value <= 300) return '#8f3f97';
    return '#7e0023';
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
