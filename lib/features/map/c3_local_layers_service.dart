import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:konektizen/core/api/api_service.dart';
import 'package:konektizen/core/config/environment.dart';

class C3LocalLayersService {
  static Future<Map<String, dynamic>> fetchGeoJson() async {
    final url = Uri.parse('${ApiService.baseUrl}/data-encoding/public-map-layers');
    final response = await http.get(url).timeout(EnvironmentConfig.requestTimeout);
    if (response.statusCode != 200) {
      throw Exception('Local C3 layers unavailable: ${response.statusCode}');
    }
    final payload = jsonDecode(response.body);
    if (payload is Map<String, dynamic>) return payload;
    return {"type": "FeatureCollection", "features": []};
  }
}
