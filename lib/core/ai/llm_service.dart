import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:konektizen/core/api/api_service.dart';

/// LLM Analysis Result Model
class LLMAnalysisResult {
  final String category;
  final String severity; // 'low', 'medium', 'high'
  final String urgency; // 'Low', 'Medium', 'High', 'Critical'
  final String? detectedCity;
  final double confidence; // 0.0 to 1.0
  final String language; // 'Filipino', 'Taglish', 'English', etc.
  final String? reasoning;

  LLMAnalysisResult({
    required this.category,
    required this.severity,
    required this.urgency,
    this.detectedCity,
    required this.confidence,
    required this.language,
    this.reasoning,
  });

  factory LLMAnalysisResult.fromJson(Map<String, dynamic> json) {
    return LLMAnalysisResult(
      category: json['category'] as String,
      severity: json['severity'] as String,
      urgency: json['urgency'] as String,
      detectedCity: json['detectedCity'] as String?,
      confidence: (json['confidence'] as num).toDouble(),
      language: json['language'] as String,
      reasoning: json['reasoning'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'severity': severity,
      'urgency': urgency,
      'detectedCity': detectedCity,
      'confidence': confidence,
      'language': language,
      'reasoning': reasoning,
    };
  }
}


/// LLM Service for analyzing incident reports in Filipino/Tagalog
class LLMService {
  // Update this to match your backend URL
  static String get baseUrl => ApiService.baseUrl;
  
  static const int maxRetries = 3;
  static const Duration timeout = Duration(seconds: 15);

  /// Analyze incident description using LLM
  /// 
  /// Throws [LLMException] if analysis fails after retries
  static Future<LLMAnalysisResult> analyzeIncident(String description) async {
    if (description.trim().isEmpty) {
      throw LLMException('Ang paglalarawan ay hindi maaaring walang laman');
    }

    Exception? lastError;

    // Retry logic
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final response = await http
            .post(
              Uri.parse('$baseUrl/llm/analyze'),
              headers: {
                'Content-Type': 'application/json',
                'Bypass-Tunnel-Reminder': 'true',
              },
              body: jsonEncode({'description': description}),
            )
            .timeout(timeout);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body) as Map<String, dynamic>;
          return LLMAnalysisResult.fromJson(data);
        } else if (response.statusCode == 400) {
          throw LLMException('Invalid request: ${response.body}');
        } else if (response.statusCode >= 500) {
          // Server error, retry
          lastError = LLMException('Server error: ${response.statusCode}');
          if (attempt < maxRetries) {
            await Future.delayed(Duration(seconds: attempt * 2)); // Exponential backoff
            continue;
          }
        } else {
          throw LLMException('Unexpected error: ${response.statusCode}');
        }
      } on http.ClientException catch (e) {
        lastError = LLMException('Network error: ${e.message}');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }
      } catch (e) {
        lastError = LLMException('Analysis failed: $e');
        if (attempt < maxRetries) {
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }
      }
    }

    // All retries failed
    throw lastError ?? LLMException('Analysis failed after $maxRetries attempts');
  }

  /// Check LLM service health
  static Future<Map<String, dynamic>> checkHealth() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/llm/health'),
            headers: {'Bypass-Tunnel-Reminder': 'true'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw LLMException('Health check failed: ${response.statusCode}');
      }
    } catch (e) {
      throw LLMException('Cannot connect to LLM service: $e');
    }
  }
}

/// Custom exception for LLM errors
class LLMException implements Exception {
  final String message;
  
  LLMException(this.message);

  @override
  String toString() => message;
}
