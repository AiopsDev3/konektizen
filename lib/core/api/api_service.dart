import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:konektizen/core/config/environment.dart';

class ApiService {
  // Use environment configuration for base URL
  static String get baseUrl => EnvironmentConfig.apiBaseUrl;
  
  final _storage = const FlutterSecureStorage();

  Future<String?> getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<void> saveToken(String token) async {
    await _storage.write(key: 'jwt_token', value: token);
  }

  Future<void> deleteToken() async {
    await _storage.delete(key: 'jwt_token');
  }

  Future<void> logout() async {
    await deleteToken();
  }

  // Login method - with timeout and error handling
  Future<Map<String, dynamic>?> login(String email, String password) async {
    try {
      final url = Uri.parse('$baseUrl/auth/login');
      print('Attempting login to: $url');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(EnvironmentConfig.requestTimeout);
      
      print('Login Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveToken(data['token']);
        return data;
      }
      return null;
    } catch (e) {
      print('Login Error: $e');
      return null;
    }
  }

  // Register method - with timeout and error handling
  Future<Map<String, dynamic>> register(String fullName, String email, String password, {String? phoneNumber}) async {
    try {
      final url = Uri.parse('$baseUrl/auth/register');
      print('Attempting register to: $url');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Bypass-Tunnel-Reminder': 'true',
        },
        body: jsonEncode({
          'fullName': fullName,
          'email': email, 
          'password': password,
          if (phoneNumber != null) 'phoneNumber': phoneNumber,
        }),
      ).timeout(const Duration(seconds: 30));
      print('Register Response Status: ${response.statusCode}');
      print('Register Response Body: ${response.body}');

      if (response.statusCode == 200) {
        return {'success': true};
      } else {
        // Try to parse error message from response
        try {
          final errorData = jsonDecode(response.body);
          return {
            'success': false,
            'error': errorData['error'] ?? 'Registration failed. Please try again.',
          };
        } catch (e) {
          print('JSON Decode Error: $e');
          print('Body was: ${response.body}');
          return {
            'success': false,
            'error': 'Registration failed. Please try again (Invalid Response).',
          };
        }
      }
    } catch (e) {
      print('Register Error: $e');
      // Check for common connection errors
      String message = 'Cannot connect to server.';
      if (e.toString().contains('Connection refused') || e.toString().contains('Network is unreachable')) {
        message += ' Please check your connection (ADB Reverse).';
      } else {
        message += ' ($e)'; // Show exact error for debugging
      }
      return {
        'success': false,
        'error': message,
      };
    }
  }

  // Update user profile
  Future<void> updateProfile({
    required String fullName,
    required String email,
    String? phoneNumber,
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final url = Uri.parse('$baseUrl/auth/profile');
      final response = await http.put(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Bypass-Tunnel-Reminder': 'true',
        },
        body: jsonEncode({
          'fullName': fullName,
          'email': email,
          if (phoneNumber != null && phoneNumber.isNotEmpty) 'phoneNumber': phoneNumber,
        }),
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to update profile');
      }
    } catch (e) {
      throw Exception('Failed to update profile: $e');
    }
  }

  // Change password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('Not authenticated');

    try {
      final url = Uri.parse('$baseUrl/auth/change-password');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Bypass-Tunnel-Reminder': 'true',
        },
        body: jsonEncode({
          'currentPassword': currentPassword,
          'newPassword': newPassword,
        }),
      );

      if (response.statusCode != 200) {
        final errorData = jsonDecode(response.body);
        throw Exception(errorData['error'] ?? 'Failed to change password');
      }
    } catch (e) {
      throw Exception('Failed to change password: $e');
    }
  }



  // Get current authenticated user
  Future<Map<String, dynamic>?> getCurrentUser() async {
    final token = await getToken();
    if (token == null) return null;

    try {
      final url = Uri.parse('$baseUrl/auth/me');
      print('Fetching current user from: $url');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Bypass-Tunnel-Reminder': 'true',
        },
      ).timeout(const Duration(seconds: 10));
      print('Get User Response: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Get User Error: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> facebookLogin(String accessToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/facebook'),
        headers: {
          'Content-Type': 'application/json',
          'Bypass-Tunnel-Reminder': 'true',
        },
        body: jsonEncode({'accessToken': accessToken}),
      ).timeout(const Duration(seconds: 30));

      print('FB Auth: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveToken(data['token']);
        // Save user info if needed
        return data;
      } else {
        // Return null but print specific error for debugging
        print('FB Auth Failed: Status ${response.statusCode}, Body: ${response.body}');
        
        // Attempt to parse error
        try {
           final errData = jsonDecode(response.body);
           if (errData['error'] != null) {
              return {'error': errData['error']}; // Return error map instead of null to propagate message
           }
        } catch(_) {}
        
        return {'error': 'Backend returned status ${response.statusCode}'};
      }
    } catch (e) {
      print('Faceook API Error: $e');
      return {'error': 'Connection error: $e'};
    }
  }

  // Phone Login (Check only)
  Future<Map<String, dynamic>?> phoneLogin({
    required String firebaseUid,
    required String phoneNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/phone/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firebaseUid': firebaseUid,
          'phoneNumber': phoneNumber,
        }),
      ).timeout(EnvironmentConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveToken(data['token']);
        return data;
      } else if (response.statusCode == 404) {
        // Account not found
        return {'error': 'Account not found. Please register.', 'status': 404};
      } else {
        final error = jsonDecode(response.body);
        return {'error': error['error'] ?? 'Login failed'};
      }
    } catch (e) {
      return {'error': 'Connection error: $e'};
    }
  }

  // Phone Register (Strict Create)
  Future<Map<String, dynamic>?> phoneRegister({
    required String firebaseUid,
    required String phoneNumber,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/phone/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firebaseUid': firebaseUid,
          'phoneNumber': phoneNumber,
        }),
      ).timeout(EnvironmentConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await saveToken(data['token']);
        return data;
      } else if (response.statusCode == 409) {
        // Already registered
        return {'error': 'Number already registered. Please log in.', 'status': 409};
      } else {
        final error = jsonDecode(response.body);
        return {'error': error['error'] ?? 'Registration failed'};
      }
    } catch (e) {
      return {'error': 'Connection error: $e'};
    }
  }

  // Complete Phone Profile (After Register)
  Future<Map<String, dynamic>?> completePhoneProfile({
    required String fullName,
    required String password,
  }) async {
    final token = await getToken();
    if (token == null) return {'error': 'Not authenticated'};

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/phone/complete-profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'fullName': fullName,
          'password': password,
        }),
      ).timeout(EnvironmentConfig.requestTimeout);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        return {'error': error['error'] ?? 'Profile update failed'};
      }
    } catch (e) {
      return {'error': 'Connection error: $e'};
    }
  }

  /// Verify phone number for KYC
  Future<bool> verifyPhone(String phoneNumber) async {
    try {
      final token = await getToken();
      if (token == null) return false;

      final response = await http.post(
        Uri.parse('$baseUrl/kyc/verify-phone'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'phoneNumber': phoneNumber}),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        print('Phone verify failed: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Phone verify error: $e');
      return false;
    }
  }

  // --- Cases ---

  Future<List<dynamic>> fetchCases() async {
    final token = await getToken();
    if (token == null) return [];

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/cases'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Bypass-Tunnel-Reminder': 'true',
        },
      );

      if (response.statusCode == 200) {
         return jsonDecode(response.body) as List<dynamic>;
      }
      return [];
    } catch (e) {
      print('Fetch Cases Error: $e');
      return [];
    }
  }

  Future<bool> submitCase(Map<String, dynamic> caseData) async {
    final token = await getToken();
    if (token == null) {
      print('Submit Case Error: No token');
      return false;
    }

    try {
      print('Submitting case to: $baseUrl/cases');
      print('Case data: $caseData');
      
      final response = await http.post(
        Uri.parse('$baseUrl/cases'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Bypass-Tunnel-Reminder': 'true',
        },
        body: jsonEncode(caseData),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('Submit Case Timeout: Request took too long');
          throw Exception('Request timeout - server not responding');
        },
      );

      print('Submit Case Response: ${response.statusCode} - ${response.body}');
      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      print('Submit Case Error: $e');
      rethrow; // Re-throw to let the UI handle it
    }
  }

  // Update existing report
  Future<bool> updateCase(String caseId, Map<String, dynamic> updates) async {
    final token = await getToken();
    if (token == null) return false;

    try {
      final response = await http.patch(
        Uri.parse('$baseUrl/cases/$caseId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Bypass-Tunnel-Reminder': 'true',
        },
        body: jsonEncode(updates),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Update Case Error: $e');
      return false;
    }
  }

  // Admin: Resolve a case
  Future<bool> resolveCase(String caseId, String resolutionNote) async {
    final token = await getToken();
    if (token == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/cases/$caseId/resolve'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Bypass-Tunnel-Reminder': 'true',
        },
        body: jsonEncode({'resolutionNote': resolutionNote}),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Resolve Case Error: $e');
      return false;
    }
  }

  // Delete/Withdraw a case
  Future<bool> deleteCase(String caseId) async {
    final token = await getToken();
    if (token == null) {
      print('Delete Case Error: No token');
      return false;
    }

    try {
      print('Deleting case: $caseId');
      final response = await http.delete(
        Uri.parse('$baseUrl/cases/$caseId'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'Bypass-Tunnel-Reminder': 'true',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('Delete Case Timeout');
          throw Exception('Request timeout');
        },
      );

      print('Delete Case Response: ${response.statusCode}');
      return response.statusCode == 200 || response.statusCode == 204;
    } catch (e) {
      print('Delete Case Error: $e');
      return false;
    }
  }
}

final apiService = ApiService();
