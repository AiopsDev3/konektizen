import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:konektizen/core/api/api_service.dart';

class VerificationResult {
  final bool isVerified;
  final String extractedName;
  final double confidence;
  final String reasoning;

  VerificationResult({
    required this.isVerified,
    required this.extractedName,
    required this.confidence,
    required this.reasoning,
  });

  factory VerificationResult.fromJson(Map<String, dynamic> json) {
    return VerificationResult(
      isVerified: json['isVerified'] ?? false,
      extractedName: json['extractedName'] ?? 'Unknown',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      reasoning: json['reasoning'] ?? '',
    );
  }
}

class VerificationService {
  Future<String?> getToken() => apiService.getToken();
  String get baseUrl => ApiService.baseUrl;

  Future<Map<String, dynamic>> uploadIdImage(File imageFile, {
    required String city,
    required String barangay,
    String? addressDetail,
    String? sex,
    DateTime? birthday,
    int? age,
    String? phoneNumber,
    bool phoneVerified = false,
  }) async {
    final token = await getToken();
    if (token == null) throw Exception('No token found');

    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/verification/upload'));
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Bypass-Tunnel-Reminder'] = 'true';

    // Add Address Fields
    request.fields['city'] = city;
    request.fields['barangay'] = barangay;
    if (addressDetail != null) request.fields['addressDetail'] = addressDetail;
    
    // Add Personal Info Fields
    if (sex != null) request.fields['sex'] = sex;
    if (birthday != null) request.fields['birthday'] = birthday.toIso8601String();
    if (age != null) request.fields['age'] = age.toString();
    if (phoneNumber != null) request.fields['phoneNumber'] = phoneNumber;
    request.fields['phoneVerified'] = phoneVerified.toString();

    request.files.add(await http.MultipartFile.fromPath('idImage', imageFile.path));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to upload ID and address: ${response.body}');
    }
  }

  Future<VerificationResult> analyzeId() async {
    final token = await getToken();
    if (token == null) throw Exception('No token found');

    final response = await http.post(
      Uri.parse('$baseUrl/verification/analyze'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
        'Bypass-Tunnel-Reminder': 'true',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['result'] != null) {
        return VerificationResult.fromJson(data['result']);
      }
      throw Exception('Verification returned invalid format');
    } else {
      final error = jsonDecode(response.body);
      throw Exception(error['error'] ?? 'Verification failed');
    }
  }
}

final verificationService = VerificationService();
