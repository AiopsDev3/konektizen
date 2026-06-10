import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:konektizen/core/config/server_connection_config.dart';

class LiveKitTokenResponse {
  final String token;
  final String liveKitUrl;

  const LiveKitTokenResponse({required this.token, required this.liveKitUrl});

  factory LiveKitTokenResponse.fromJson(Map<String, dynamic> json) {
    return LiveKitTokenResponse(
      token: json['token']?.toString() ?? '',
      liveKitUrl: json['liveKitUrl']?.toString() ?? '',
    );
  }
}

class LiveKitTokenService {
  Future<LiveKitTokenResponse> createToken({
    required String roomName,
    required String participantName,
  }) async {
    final baseUrl = ServerConnectionConfig.instance.videoApiBaseUrl;
    final response = await http
        .post(
          Uri.parse('$baseUrl/getToken'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({
            'roomName': roomName,
            'participantName': participantName,
          }),
        )
        .timeout(const Duration(seconds: 8));

    final body = jsonDecode(response.body);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = body is Map && body['error'] != null
          ? body['error'].toString()
          : 'Unable to create LiveKit token.';
      throw Exception(message);
    }

    if (body is! Map<String, dynamic>) {
      throw Exception('Invalid LiveKit token response.');
    }

    final tokenResponse = LiveKitTokenResponse.fromJson(body);
    if (tokenResponse.token.isEmpty || tokenResponse.liveKitUrl.isEmpty) {
      throw Exception('LiveKit token response is incomplete.');
    }
    return tokenResponse;
  }
}

final liveKitTokenService = LiveKitTokenService();
