import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:konektizen/core/api/api_service.dart';

class ZegoTokenResponse {
  final int appId;
  final String token;
  final String roomId;
  final String userId;
  final String userName;
  final String publishStreamId;

  const ZegoTokenResponse({
    required this.appId,
    required this.token,
    required this.roomId,
    required this.userId,
    required this.userName,
    required this.publishStreamId,
  });

  factory ZegoTokenResponse.fromJson(Map<String, dynamic> json) {
    return ZegoTokenResponse(
      appId: int.tryParse('${json['appID'] ?? json['appId'] ?? 0}') ?? 0,
      token: json['token']?.toString() ?? '',
      roomId: json['roomID']?.toString() ?? json['roomName']?.toString() ?? '',
      userId: json['userID']?.toString() ?? json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? 'Citizen SOS',
      publishStreamId: json['publishStreamID']?.toString() ??
          json['publishStreamId']?.toString() ??
          '',
    );
  }
}

class ZegoTokenService {
  Future<ZegoTokenResponse> createToken({
    required String callId,
    required String roomName,
    required String userId,
    required String userName,
  }) async {
    final response = await http
        .post(
          Uri.parse('${ApiService.baseUrl}/calls/zego/token'),
          headers: const {
            'Content-Type': 'application/json',
            'Bypass-Tunnel-Reminder': 'true',
          },
          body: jsonEncode({
            'call_id': callId,
            'room_name': roomName,
            'user_id': userId,
            'user_name': userName,
          }),
        )
        .timeout(const Duration(seconds: 12));

    final decoded = jsonDecode(response.body);
    final body = decoded is Map<String, dynamic> ? decoded : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(body['message']?.toString() ?? 'Unable to create ZEGO token.');
    }
    if (body['status'] != 'success') {
      throw Exception(body['message']?.toString() ?? 'Invalid ZEGO token response.');
    }

    final token = ZegoTokenResponse.fromJson(body);
    if (token.appId == 0 ||
        token.token.isEmpty ||
        token.roomId.isEmpty ||
        token.userId.isEmpty ||
        token.publishStreamId.isEmpty) {
      throw Exception('ZEGO token response is incomplete.');
    }
    return token;
  }
}

final zegoTokenService = ZegoTokenService();
