import 'package:flutter/material.dart';
import 'package:konektizen/theme/app_theme.dart';

enum CaseStatus {
  submitted,
  validated,
  inProgress,
  resolved,
}

enum Severity {
  low,
  medium,
  high,
}

class CaseModel {
  final String id;
  final String title;
  final String location; // City name
  final DateTime date;
  final CaseStatus status;
  final String category;
  final String description;
  final Severity severity;
  
  // Location details
  final double? latitude;
  final double? longitude;
  final String? address;
  
  // Media evidence
  final List<String> mediaUrls;
  final List<String> mediaTypes;
  
  // Resolution (admin fields)
  final DateTime? resolvedAt;
  final String? resolutionNote;
  final String? resolvedBy;

  const CaseModel({
    required this.id,
    required this.title,
    required this.location,
    required this.date,
    required this.status,
    required this.category,
    required this.description,
    this.severity = Severity.medium,
    this.latitude,
    this.longitude,
    this.address,
    this.mediaUrls = const [],
    this.mediaTypes = const [],
    this.resolvedAt,
    this.resolutionNote,
    this.resolvedBy,
  });

  Color get statusColor {
    switch (status) {
      case CaseStatus.submitted: return Colors.grey;
      case CaseStatus.validated: return AppTheme.secondary;
      case CaseStatus.inProgress: return AppTheme.warning;
      case CaseStatus.resolved: return AppTheme.success;
    }
  }

  String get statusLabel {
    switch (status) {
      case CaseStatus.submitted: return 'Submitted';
      case CaseStatus.validated: return 'Validated';
      case CaseStatus.inProgress: return 'In Progress';
      case CaseStatus.resolved: return 'Resolved';
    }
  }
  factory CaseModel.fromJson(Map<String, dynamic> json) {
    // Parse media arrays from comma-separated strings
    final mediaUrlsStr = json['mediaUrls'] as String? ?? '';
    final mediaTypesStr = json['mediaTypes'] as String? ?? '';
    
    return CaseModel(
      id: json['id'],
      title: json['category'] ?? 'Report',
      location: json['city'] ?? 'Unknown',
      date: DateTime.parse(json['createdAt']),
      status: _parseStatus(json['status']),
      category: json['category'] ?? 'General',
      description: json['description'] ?? '',
      severity: _parseSeverity(json['severity']),
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
      address: json['address'],
      mediaUrls: mediaUrlsStr.isEmpty ? [] : mediaUrlsStr.split(','),
      mediaTypes: mediaTypesStr.isEmpty ? [] : mediaTypesStr.split(','),
      resolvedAt: json['resolvedAt'] != null ? DateTime.parse(json['resolvedAt']) : null,
      resolutionNote: json['resolutionNote'],
      resolvedBy: json['resolvedBy'],
    );
  }

  static CaseStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'submitted': return CaseStatus.submitted;
      case 'validated': return CaseStatus.validated;
      case 'in_progress': return CaseStatus.inProgress;
      case 'resolved': return CaseStatus.resolved;
      default: return CaseStatus.submitted;
    }
  }

  static Severity _parseSeverity(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'low': return Severity.low;
      case 'high': return Severity.high;
      default: return Severity.medium;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'severity': severity.name,
      'description': description,
      'city': location != 'Unknown' ? location : null,
      'address': address,
    };
  }
}
