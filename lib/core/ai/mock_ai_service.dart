import 'package:flutter/material.dart';
import 'package:konektizen/features/cases/case_model.dart';
import 'package:konektizen/theme/app_theme.dart';

class AnalysisResult {
  final String category;
  final Severity severity;
  final IconData icon;
  final String? detectedCity;
  final String urgencyLabel;

  AnalysisResult({
    required this.category,
    required this.severity,
    required this.icon,
    this.detectedCity,
    required this.urgencyLabel,
  });
}

class MockAIService {
  static AnalysisResult analyze(String text) {
    final lower = text.toLowerCase();
    
    // City Detection
    String? city;
    if (lower.contains('manila')) city = 'Manila City';
    else if (lower.contains('cebu')) city = 'Cebu City';
    else if (lower.contains('davao')) city = 'Davao City';
    else if (lower.contains('quezon')) city = 'Quezon City';
    else if (lower.contains('naga')) city = 'Naga City';

    // Category & Severity
    if (lower.contains('road') || lower.contains('pothole')) {
      return AnalysisResult(
        category: 'Roads & Infra',
        icon: Icons.add_road,
        severity: Severity.medium,
        urgencyLabel: 'Medium',
        detectedCity: city,
      );
    } else if (lower.contains('flood') || lower.contains('water') || lower.contains('fire') || lower.contains('danger')) {
      return AnalysisResult(
        category: 'Safety & Emergency',
        icon: Icons.warning_amber_rounded,
        severity: Severity.high,
        urgencyLabel: 'High',
        detectedCity: city,
      );
    } else if (lower.contains('garbage') || lower.contains('trash') || lower.contains('waste')) {
      return AnalysisResult(
        category: 'Sanitation',
        icon: Icons.delete,
        severity: Severity.low,
        urgencyLabel: 'Low',
        detectedCity: city,
      );
    } else if (lower.contains('traffic')) {
       return AnalysisResult(
        category: 'Traffic',
        icon: Icons.traffic,
        severity: Severity.medium,
        urgencyLabel: 'Medium',
        detectedCity: city,
      );
    }

    return AnalysisResult(
      category: 'Public Concern',
      icon: Icons.campaign,
      severity: Severity.medium,
      urgencyLabel: 'Medium',
      detectedCity: city,
    );
  }
}
