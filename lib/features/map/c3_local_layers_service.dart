import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:konektizen/core/api/api_service.dart';
import 'package:konektizen/core/config/environment.dart';

class C3LocalLayersService {
  static Future<Map<String, dynamic>> fetchGeoJson() async {
    Map<String, dynamic>? emptyPayload;
    Object? lastError;

    for (final url in _candidateUrls()) {
      try {
        final payload = await _fetch(url);
        final count = (payload['features'] as List<dynamic>? ?? []).length;
        debugPrint('C3 local layers feed: $url ($count features)');
        if (count > 0) return payload;
        emptyPayload ??= payload;
      } catch (error) {
        lastError = error;
        debugPrint('C3 local layers feed failed: $url ($error)');
      }
    }

    if (emptyPayload != null) return emptyPayload;
    throw Exception('Local C3 layers unavailable: $lastError');
  }

  static Future<Map<String, dynamic>> _fetch(Uri url) async {
    final response = await http.get(url).timeout(EnvironmentConfig.requestTimeout);
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final payload = jsonDecode(response.body);
    if (payload is Map<String, dynamic>) return payload;
    return {"type": "FeatureCollection", "features": []};
  }

  static List<Uri> _candidateUrls() {
    final urls = <String>[
      '${ApiService.baseUrl}/data-encoding/public-map-layers',
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
