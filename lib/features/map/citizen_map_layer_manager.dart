import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:konektizen/core/api/api_service.dart';
import 'package:konektizen/features/map/c3_local_layers_overlay.dart';
import 'package:konektizen/features/map/citizen_map_layer_data.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class CitizenMapLayerManager {
  CitizenMapLayerManager(this.controller, this.addedSources);

  final MapLibreMapController? controller;
  final Set<String> addedSources;
  static final _assetGeoJsonCache = <String, Map<String, dynamic>>{};
  static Map<String, dynamic>? _rainViewerFrameCache;
  static DateTime? _rainViewerFrameFetchedAt;

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
      final tileUrl = await _latestRainViewerTileUrl();
      if (tileUrl == null) return;
      await _ensureRasterLayer(
        sourceId: sourceId,
        layerId: layerId,
        tiles: [tileUrl],
        opacity: 0.58,
        maxzoom: 7,
        belowLayerId: belowLayerId,
      );
    } catch (e) {
      debugPrint('Heavy rainfall RainViewer fetch failed: $e');
    }
  }

  Future<String?> _latestRainViewerTileUrl() async {
    final cachedAt = _rainViewerFrameFetchedAt;
    final now = DateTime.now();
    if (_rainViewerFrameCache == null ||
        cachedAt == null ||
        now.difference(cachedAt) > const Duration(minutes: 5)) {
      final res = await http
          .get(Uri.parse('https://api.rainviewer.com/public/weather-maps.json'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode != 200) return null;
      _rainViewerFrameCache = jsonDecode(res.body) as Map<String, dynamic>;
      _rainViewerFrameFetchedAt = now;
    }

    final data = _rainViewerFrameCache;
    if (data == null) return null;
    final radar = data['radar'];
    if (radar is! Map) return null;
    final frames = radar['past'];
    if (frames is! List || frames.isEmpty) return null;
    final latest = frames.last;
    if (latest is! Map) return null;
    final path = latest['path']?.toString();
    if (path == null || path.isEmpty) return null;
    final host = data['host']?.toString();
    final tileHost = (host == null || host.isEmpty)
        ? 'https://tilecache.rainviewer.com'
        : host;
    return '$tileHost$path/256/{z}/{x}/{y}/2/1_1.png';
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
          'color': _aqiColor(aqiValue),
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
            'color': _aqiColor(aqi),
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
        if (f is Map<String, dynamic> && f['properties'] is Map<String, dynamic>) {
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
