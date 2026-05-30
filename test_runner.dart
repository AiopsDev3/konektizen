import 'dart:convert';
import 'dart:math';
import '../../../test_util.dart';
import 'package:http/http.dart' as http;

class BrgyRainThreatUtil {
  static const _geoRiskUrl =
      "https://portal.georisk.gov.ph/arcgis/rest/services/PSA/Barangay/MapServer/4/query?where=city_name%20LIKE%20%27%25Laoag%25%27&outFields=brgy_name,city_name,prov_name,brgy_code&returnGeometry=true&outSR=4326&f=geojson";
  static const _openMeteoUrl = "https://api.open-meteo.com/v1/forecast";
  static const _batchSize = 25;

  static List<List<double>> _flattenPairs(dynamic coords, [List<List<double>>? pairs]) {
    pairs ??= [];
    if (coords is List) {
      if (coords.length >= 2 && coords.every((value) => value is num)) {
        pairs.add([
          (coords[0] as num).toDouble(),
          (coords[1] as num).toDouble(),
        ]);
        return pairs;
      }
      for (var child in coords) {
        _flattenPairs(child, pairs);
      }
    }
    return pairs;
  }

  static Map<String, double>? _getCenter(Map<String, dynamic> feature) {
    final geometry = feature['geometry'];
    if (geometry == null || geometry['coordinates'] == null) return null;

    final pairs = _flattenPairs(geometry['coordinates']);
    if (pairs.isEmpty) return null;

    double minLng = 180, maxLng = -180, minLat = 90, maxLat = -90;
    for (var pair in pairs) {
      minLng = min(minLng, pair[0]);
      maxLng = max(maxLng, pair[0]);
      minLat = min(minLat, pair[1]);
      maxLat = max(maxLat, pair[1]);
    }

    return {
      'lng': (minLng + maxLng) / 2,
      'lat': (minLat + maxLat) / 2,
    };
  }

  static String _classifyRain(double mm) {
    if (!mm.isFinite) return "unknown";
    if (mm >= 100) return "very_high";
    if (mm >= 65) return "high";
    if (mm >= 30) return "moderate";
    if (mm >= 15) return "low";
    return "minimal";
  }

  static Future<Map<String, dynamic>> fetchAndEnrich() async {
    final geoRiskRes = await http.get(Uri.parse(_geoRiskUrl)).timeout(const Duration(seconds: 15));
    if (geoRiskRes.statusCode != 200) {
      throw Exception("GeoRiskPH fetch failed with status ${geoRiskRes.statusCode}");
    }

    final geoJson = jsonDecode(geoRiskRes.body) as Map<String, dynamic>;
    final featuresList = geoJson['features'];
    if (featuresList == null || featuresList is! List) {
      throw Exception("GeoRiskPH returned invalid features list");
    }

    final List<Map<String, dynamic>> validRows = [];
    for (int i = 0; i < featuresList.length; i++) {
      final feature = featuresList[i] as Map<String, dynamic>;
      final center = _getCenter(feature);
      if (center != null) {
        validRows.add({
          'feature': feature,
          'center': center,
        });
      }
    }

    for (int start = 0; start < validRows.length; start += _batchSize) {
      final end = min(start + _batchSize, validRows.length);
      final batch = validRows.sublist(start, end);

      final lats = batch.map((r) => (r['center']['lat'] as double).toStringAsFixed(5)).join(',');
      final lngs = batch.map((r) => (r['center']['lng'] as double).toStringAsFixed(5)).join(',');

      final queryParams = {
        'latitude': lats,
        'longitude': lngs,
        'hourly': 'precipitation',
        'current': 'precipitation,weather_code',
        'forecast_hours': '24',
        'timezone': 'Asia/Manila',
      };

      final uri = Uri.parse(_openMeteoUrl).replace(queryParameters: queryParams);
      try {
        final meteoRes = await http.get(uri).timeout(const Duration(seconds: 15));
        if (meteoRes.statusCode == 200) {
          final payload = jsonDecode(meteoRes.body);
          final forecasts = payload is List ? payload : [payload];

          for (int i = 0; i < batch.length; i++) {
            if (i >= forecasts.length) break;
            final row = batch[i];
            final forecast = forecasts[i];

            final hourly = forecast['hourly'];
            final precipList = (hourly?['precipitation'] as List<dynamic>?) ?? [];
            final subset = precipList.take(24).toList();
            final rain24h = subset.fold<double>(0.0, (sum, val) => sum + ((val as num?)?.toDouble() ?? 0.0));

            final currentRain = (forecast['current']?['precipitation'] as num?)?.toDouble() ?? 0.0;

            final feature = row['feature'] as Map<String, dynamic>;
            feature['properties'] ??= {};
            final properties = feature['properties'] as Map<String, dynamic>;

            properties['current_rain_mm'] = currentRain;
            properties['rain_24h_mm'] = double.parse(rain24h.toStringAsFixed(1));
            properties['rain_level'] = _classifyRain(rain24h);
            properties['rain_source'] = "Open-Meteo centroid forecast";
          }
        } else {
          debugPrint("Open-Meteo batch failed with status ${meteoRes.statusCode}");
        }
      } catch (e) {
        debugPrint("Open-Meteo fetch error: $e");
      }
    }

    geoJson['features'] = validRows.map((r) => r['feature']).toList();
    return geoJson;
  }
}

void main() async {
  try {
    final res = await BrgyRainThreatUtil.fetchAndEnrich();
    print("SUCCESS! Features: \${res['features']?.length}");
  } catch(e, st) {
    print("ERROR: \$e");
    print(st);
  }
}
