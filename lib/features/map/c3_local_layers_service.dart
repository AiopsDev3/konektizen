import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:konektizen/core/api/api_service.dart';

class C3LocalLayersService {
  static const _cloudPublicLayersUrl =
      'https://c3.aitelligenz.com/api/data-encoding/public-map-layers';
  static const _cacheTtl = Duration(minutes: 2);
  static Map<String, dynamic>? _cachedGeoJson;
  static DateTime? _cachedAt;
  static Future<Map<String, dynamic>>? _pendingFetch;

  static Future<Map<String, dynamic>> fetchGeoJson({
    bool forceRefresh = false,
  }) async {
    final cached = _cachedGeoJson;
    if (!forceRefresh && cached != null && !_isCacheExpired) return cached;

    final pending = _pendingFetch;
    if (pending != null) return pending;

    _pendingFetch = _fetchMergedGeoJson();
    try {
      return await _pendingFetch!;
    } finally {
      _pendingFetch = null;
    }
  }

  static bool get _isCacheExpired {
    final cachedAt = _cachedAt;
    if (cachedAt == null) return true;
    return DateTime.now().difference(cachedAt) > _cacheTtl;
  }

  static Future<Map<String, dynamic>> _fetchMergedGeoJson() async {
    Map<String, dynamic>? emptyPayload;
    final mergedFeatures = <Map<String, dynamic>>[];
    final seen = <String>{};
    Object? lastError;

    for (final url in _candidateUrls()) {
      try {
        final payload = await _fetch(url);
        final count = (payload['features'] as List<dynamic>? ?? []).length;
        debugPrint('C3 local layers feed: $url ($count features)');
        if (count == 0) {
          emptyPayload ??= payload;
          continue;
        }
        for (final feature
            in (payload['features'] as List<dynamic>).whereType<Map>()) {
          final normalized = _stringKeyedMap(feature);
          if (seen.add(_featureKey(normalized))) {
            mergedFeatures.add(normalized);
          }
        }
      } catch (error) {
        lastError = error;
        debugPrint('C3 local layers feed failed: $url ($error)');
      }
    }

    if (mergedFeatures.isNotEmpty) {
      _cachedGeoJson = {
        "type": "FeatureCollection",
        "features": mergedFeatures,
      };
      _cachedAt = DateTime.now();
      return _cachedGeoJson!;
    }
    if (emptyPayload != null) {
      _cachedGeoJson = emptyPayload;
      _cachedAt = DateTime.now();
      return emptyPayload;
    }
    final cached = _cachedGeoJson;
    if (cached != null) return cached;
    throw Exception('Local C3 layers unavailable: $lastError');
  }

  static Future<Map<String, dynamic>> _fetch(Uri url) async {
    final response = await http.get(url).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final payload = jsonDecode(response.body);
    if (payload is Map<String, dynamic>) return payload;
    return {"type": "FeatureCollection", "features": []};
  }

  static Map<String, dynamic> _stringKeyedMap(Map source) {
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

  static String _featureKey(Map<String, dynamic> feature) {
    final properties = Map<String, dynamic>.from(
      feature['properties'] as Map? ?? {},
    );
    final id = properties['id']?.toString().trim();
    if (id != null && id.isNotEmpty) return '${properties['kind']}:$id';
    return [
      properties['kind'],
      properties['type'],
      properties['name'],
      feature['geometry'],
    ].join('|');
  }

  static List<Uri> _candidateUrls() {
    final urls = <String>[
      '${ApiService.baseUrl}/data-encoding/public-map-layers',
      _cloudPublicLayersUrl,
      if (kDebugMode) ...[
        'http://localhost:5175/api/data-encoding/public-map-layers',
        'http://127.0.0.1:5001/api/data-encoding/public-map-layers',
        'http://10.0.2.2:5001/api/data-encoding/public-map-layers',
      ],
    ];
    final seen = <String>{};
    return urls.where(seen.add).map(Uri.parse).toList();
  }
}
