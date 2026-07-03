import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:konektizen/core/api/api_service.dart';

String _aitelligenzRoomMessage(Object? value) {
  return (value?.toString() ?? '')
      .replaceAll(
        RegExp(r'ZEGOCLOUD|ZegoCloud|ZEGO|Zego', caseSensitive: false),
        'AITELLIGENZ room',
      )
      .trim();
}

class ZegoTokenResponse {
  final int appId;
  final String token;
  final String roomId;
  final String userId;
  final String userName;
  final String publishStreamId;
  final List<String> loginTokens;

  const ZegoTokenResponse({
    required this.appId,
    required this.token,
    required this.roomId,
    required this.userId,
    required this.userName,
    required this.publishStreamId,
    required this.loginTokens,
  });

  factory ZegoTokenResponse.fromJson(Map<String, dynamic> json) {
    final candidates = <String>[
      json['token']?.toString() ?? '',
      json['basicToken']?.toString() ?? '',
      json['fallbackToken']?.toString() ?? '',
    ].where((token) => token.trim().isNotEmpty).toList();
    final uniqueCandidates = <String>[];
    for (final token in candidates) {
      if (!uniqueCandidates.contains(token)) uniqueCandidates.add(token);
    }

    return ZegoTokenResponse(
      appId: int.tryParse('${json['appID'] ?? json['appId'] ?? 0}') ?? 0,
      token: json['token']?.toString() ?? '',
      roomId: json['roomID']?.toString() ?? json['roomName']?.toString() ?? '',
      userId: json['userID']?.toString() ?? json['userId']?.toString() ?? '',
      userName: json['userName']?.toString() ?? 'Citizen SOS',
      publishStreamId:
          json['publishStreamID']?.toString() ??
          json['publishStreamId']?.toString() ??
          '',
      loginTokens: uniqueCandidates,
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
    final body = decoded is Map<String, dynamic>
        ? decoded
        : <String, dynamic>{};
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        _aitelligenzRoomMessage(body['message']).isNotEmpty
            ? _aitelligenzRoomMessage(body['message'])
            : 'Unable to prepare AITELLIGENZ room access.',
      );
    }
    if (body['status'] != 'success') {
      throw Exception(
        _aitelligenzRoomMessage(body['message']).isNotEmpty
            ? _aitelligenzRoomMessage(body['message'])
            : 'Invalid AITELLIGENZ room response.',
      );
    }

    final token = ZegoTokenResponse.fromJson(body);
    if (token.appId == 0 ||
        token.token.isEmpty ||
        token.roomId.isEmpty ||
        token.userId.isEmpty ||
        token.publishStreamId.isEmpty ||
        token.loginTokens.isEmpty) {
      throw Exception('AITELLIGENZ room response is incomplete.');
    }
    return token;
  }
}

final zegoTokenService = ZegoTokenService();
