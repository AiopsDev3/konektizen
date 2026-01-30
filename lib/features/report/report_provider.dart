import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:konektizen/features/cases/case_model.dart';
import 'package:konektizen/core/ai/llm_service.dart';
import 'package:konektizen/features/cases/cases_provider.dart';
import 'package:konektizen/core/api/api_service.dart';
import 'package:flutter/material.dart';

/// UI-specific analysis result with icon
class AnalysisResult {
  final String category;
  final Severity severity;
  final IconData icon;
  final String urgencyLabel;
  final String? detectedCity;

  AnalysisResult({
    required this.category,
    required this.severity,
    required this.icon,
    required this.urgencyLabel,
    this.detectedCity,
  });
}

class ReportDraftState {
  final String description;
  final String? category;
  final Severity? severity;
  final String? address; // Full address
  final String city; // Current active city context
  final bool isCityDetected;
  final AnalysisResult? aiAnalysis;
  
  // Location coordinates
  final double? latitude;
  final double? longitude;
  
  // Media evidence
  final List<String> mediaUrls;
  final List<String> mediaTypes;
  final List<String> localMediaPaths;
  
  // Reporter information (for validation)
  final double? reporterLatitude;
  final double? reporterLongitude;
  final String? reporterAddress;
  final bool locationVerified;

  // LLM state
  final bool isAnalyzing;
  final String? analysisError;
  final String? detectedLanguage;
  final double? confidence;

  ReportDraftState({
    this.description = '',
    this.category,
    this.severity,
    this.address,
    this.city = '', // No default city
    this.isCityDetected = false,
    this.aiAnalysis,
    this.latitude,
    this.longitude,
    this.mediaUrls = const [],
    this.mediaTypes = const [],
    this.localMediaPaths = const [],
    this.isAnalyzing = false,
    this.analysisError,
    this.detectedLanguage,
    this.confidence,
    this.reporterLatitude,
    this.reporterLongitude,
    this.reporterAddress,
    this.locationVerified = false,
  });


  ReportDraftState copyWith({
    String? description,
    String? category,
    Severity? severity,
    String? address,
    String? city,
    bool? isCityDetected,
    AnalysisResult? aiAnalysis,
    double? latitude,
    double? longitude,
    List<String>? mediaUrls,
    List<String>? mediaTypes,
    List<String>? localMediaPaths,
    bool? isAnalyzing,
    String? analysisError,
    String? detectedLanguage,
    double? confidence,
    double? reporterLatitude,
    double? reporterLongitude,
    String? reporterAddress,
    bool? locationVerified,
  }) {
    return ReportDraftState(
      description: description ?? this.description,
      category: category ?? this.category,
      severity: severity ?? this.severity,
      address: address ?? this.address,
      city: city ?? this.city,
      isCityDetected: isCityDetected ?? this.isCityDetected,
      aiAnalysis: aiAnalysis ?? this.aiAnalysis,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      mediaUrls: mediaUrls ?? this.mediaUrls,
      mediaTypes: mediaTypes ?? this.mediaTypes,
      localMediaPaths: localMediaPaths ?? this.localMediaPaths,
      isAnalyzing: isAnalyzing ?? this.isAnalyzing,
      analysisError: analysisError ?? this.analysisError,
      detectedLanguage: detectedLanguage ?? this.detectedLanguage,
      confidence: confidence ?? this.confidence,
      reporterLatitude: reporterLatitude ?? this.reporterLatitude,
      reporterLongitude: reporterLongitude ?? this.reporterLongitude,
      reporterAddress: reporterAddress ?? this.reporterAddress,
      locationVerified: locationVerified ?? this.locationVerified,
    );
  }

}

class ReportDraftNotifier extends StateNotifier<ReportDraftState> {
  final Ref ref;

  ReportDraftNotifier(this.ref) : super(ReportDraftState());

  void updateDescription(String text) {
    state = state.copyWith(description: text);
  }

  Future<void> analyzeDraft() async {
    if (state.description.isEmpty) return;

    // Set loading state
    state = state.copyWith(
      isAnalyzing: true,
      analysisError: null,
    );

    /* 
    // AI Analysis disabled for C3 integration (Endpoint not supported)
    try {
      // Call real LLM service
      final llmResult = await LLMService.analyzeIncident(state.description);
      // ... (code omitted)
    } 
    */

    // IMMEDIATE FALLBACK: Skip analysis
    state = state.copyWith(
      isAnalyzing: false,
      analysisError: null,
      category: state.category ?? 'General',
      severity: state.severity ?? Severity.medium,
      city: state.city.isEmpty ? 'Unknown' : state.city,
      aiAnalysis: AnalysisResult(
        category: state.category ?? 'General',
        severity: state.severity ?? Severity.medium,
        icon: Icons.info_outline,
        urgencyLabel: 'Normal',
        detectedCity: state.city.isNotEmpty ? state.city : null,
      ),
    );
  }


  void updateLocation({String? address, String? city}) {
    state = state.copyWith(
      address: address,
      city: city,
      isCityDetected: false, // User manually overrode, so clear "detected" flag to stop nagging
    );
  }
  
  void updateCategory(String category) {
      // Allow manual category override
      state = state.copyWith(category: category);
  }

  void confirmLocation({
    required double lat, 
    required double lng, 
    required String address
  }) {
    state = state.copyWith(
      reporterLatitude: lat,
      reporterLongitude: lng,
      reporterAddress: address,
      locationVerified: true,
    );
  }

  void resetLocationVerification() {
    state = state.copyWith(
      locationVerified: false,
      reporterLatitude: null,
      reporterLongitude: null,
      reporterAddress: null,
    );
  }

  Future<String> submitReport() async {
    print('=== Starting report submission ===');
    final caseData = {
      'category': state.category ?? 'General',
      'severity': state.severity?.name ?? 'medium',
      'description': state.description,
      'city': state.city.isEmpty ? 'Unknown' : state.city,
      'address': state.address,
      'latitude': state.latitude,
      'longitude': state.longitude,
      'media_urls': state.mediaUrls,      // Changed to snake_case
      'media_types': state.mediaTypes,    // Changed to snake_case
      'reporter_latitude': state.reporterLatitude,   // Changed to snake_case
      'reporter_longitude': state.reporterLongitude, // Changed to snake_case
      'reporter_address': state.reporterAddress,     // Changed to snake_case
      'location_verified': state.locationVerified,   // Changed to snake_case
    };

    print('Case data: $caseData');
    
    try {
      final result = await apiService.submitCase(caseData);
      print('Submit result: $result');
      
      if (result) {
         print('Clearing draft...');
         clearDraft();
         print('=== Report submission successful ===');
         return 'success';
      } else {
         print('=== Report submission failed (result was false) ===');
         throw Exception('Hindi naisumite ang ulat. Subukan muli.');
      }
    } catch (e) {
      print('=== Report submission error: $e ===');
      rethrow;
    }
  }

  void clearDraft() {
    state = ReportDraftState();
  }
}

final reportDraftProvider = StateNotifierProvider<ReportDraftNotifier, ReportDraftState>((ref) {
  return ReportDraftNotifier(ref);
});
