import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:konektizen/core/api/api_service.dart';
import 'package:konektizen/core/config/environment.dart';
import 'package:konektizen/features/weather/weather_advisory.dart';

class WeatherAdvisoryService {
  const WeatherAdvisoryService({this.client});

  final http.Client? client;

  Future<List<WeatherAdvisory>> fetchAdvisories({
    int hours = 72,
    int limit = 30,
  }) async {
    final token = await apiService.getToken();
    if (token == null || token.isEmpty) return const [];

    final uri = Uri.parse('${ApiService.baseUrl}/reporters/weather-advisories')
        .replace(
          queryParameters: {
            'hours': hours.toString(),
            'limit': limit.toString(),
          },
        );
    final response = await _http
        .get(uri, headers: _headers(token))
        .timeout(EnvironmentConfig.requestTimeout);

    if (response.statusCode != 200) {
      throw Exception('Unable to load weather advisories.');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final advisories = decoded['advisories'];
    if (advisories is! List) return const [];
    return advisories
        .whereType<Map>()
        .map(
          (item) => WeatherAdvisory.fromJson(
            item.map((key, value) => MapEntry(key.toString(), value)),
          ),
        )
        .toList();
  }

  Future<void> registerPushToken(String pushToken) async {
    final token = await apiService.getToken();
    if (token == null || token.isEmpty || pushToken.trim().isEmpty) return;

    final uri = Uri.parse(
      '${ApiService.baseUrl}/reporters/weather-advisories/push-token',
    );
    final response = await _http
        .post(
          uri,
          headers: _headers(token),
          body: jsonEncode({'token': pushToken.trim()}),
        )
        .timeout(EnvironmentConfig.requestTimeout);

    if (response.statusCode >= 400) {
      throw Exception('Unable to register weather push token.');
    }
  }

  Future<Map<String, dynamic>> syncAdvisories() async {
    final token = await apiService.getToken();
    if (token == null || token.isEmpty) {
      throw Exception('Not authenticated');
    }

    final uri = Uri.parse(
      '${ApiService.baseUrl}/reporters/weather-advisories/sync',
    );
    final response = await _http
        .post(uri, headers: _headers(token))
        .timeout(EnvironmentConfig.requestTimeout);

    if (response.statusCode != 200) {
      throw Exception('Unable to sync weather advisories.');
    }

    return jsonDecode(response.body) as Map<String, dynamic>;
  }

  Map<String, String> _headers(String token) {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  http.Client get _http => client ?? _sharedClient;
}

final _sharedClient = http.Client();
