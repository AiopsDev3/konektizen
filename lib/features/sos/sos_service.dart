import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:konektizen/core/api/api_service.dart';

class SOSService {
  // TODO: Fetch this from backend settings in the future
  Future<String> getHotlineNumber() async {
    // Return mock hotline for now
    return '911'; 
  }

  Future<bool> sendSOS({
    required double latitude, 
    required double longitude,
    required String hotlineNumber,
  }) async {
    final token = await apiService.getToken();
    if (token == null) return false;

    try {
      // 1. Try to get current user details (may fail if token expired)
      Map<String, dynamic>? user;
      try {
        user = await apiService.getCurrentUser();
      } catch (e) {
        print('[SOS] Warning: Could not get user info (token may be expired): $e');
        // Continue anyway - C3 can identify user from token
      }
      
      final url = Uri.parse('${ApiService.baseUrl}/sos/');
      print('Sending SOS to: $url');
      
      final body = {
        'latitude': latitude,
        'longitude': longitude,
        'hotlineNumber': hotlineNumber,
        'timestamp': DateTime.now().toIso8601String(),
        'platform': 'android', // Simplified for now
        if (user != null) ...{
           'userId': user['_id'] ?? user['id'],
           'userName': user['fullName'] ?? user['name'] ?? 'Unknown',
           'userStatus': user['verificationStatus'] ?? 'unknown',
        }
      };

      print('SOS Payload: $body');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Bypass-Tunnel-Reminder': 'true',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 10));

      print('SOS Response: ${response.statusCode} - ${response.body}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('[SOS Service Error] Failed to send SOS: $e');
      return false;
    }
  }

  // Helper for Video Call (Flask)
  Future<Map<String, dynamic>?> startVideoCall({
    required double latitude,
    required double longitude, 
    required String hotlineNumber,
  }) async {
    final token = await apiService.getToken();
    if (token == null) return null;

    try {
      final user = await apiService.getCurrentUser();
      
      // Connect to C3 Command Center Web (Socket/Video)
      final url = Uri.parse('${ApiService.baseUrl}/sos/video/start');
      print('[SOS Service] ========================================');
      print('[SOS Service] Starting video call...');
      print('[SOS Service] URL: $url');
      
      final body = {
        'latitude': latitude,
        'longitude': longitude,
        'hotlineNumber': hotlineNumber, // lowercase per prompt intent
        'timestamp': DateTime.now().toIso8601String(),
        'platform': 'android',
        if (user != null) ...{
           'userId': user['_id'] ?? user['id'],
           'userName': user['fullName'] ?? user['name'] ?? 'Unknown',
        }
      };
      
      print('[SOS Service] Payload: $body');
      print('[SOS Service] ========================================');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 15));
      
      print('[SOS Service] Response status: ${response.statusCode}');
      print('[SOS Service] Response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('[SOS Service] ✓ Video call session created successfully');
        return data;
      }
      print('[SOS Service] ✗ ERROR: Non-200 response');
      return null;
    } catch (e) {
      print('[SOS Service] ✗ ERROR starting video call: $e');
      return null;
    }
  }
}

final sosService = SOSService();
