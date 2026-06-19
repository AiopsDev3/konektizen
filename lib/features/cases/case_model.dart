import 'package:flutter/material.dart';
import 'package:konektizen/theme/app_theme.dart';

enum CaseStatus { submitted, validated, inProgress, resolved }

enum Severity { low, medium, high }

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

  // Timeline
  final DateTime? submittedAt;
  final DateTime? validatedAt;
  final DateTime? assignedAt;
  final DateTime? enrouteAt;
  final DateTime? arrivedAt;

  // Resolution (admin fields)
  final DateTime? resolvedAt;
  final String? resolutionNote;
  final String? resolvedBy;
  final String? rawStatus;
  final String? workflowStatus;
  final String? aiNarration;

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
    this.submittedAt,
    this.validatedAt,
    this.assignedAt,
    this.enrouteAt,
    this.arrivedAt,
    this.resolvedAt,
    this.resolutionNote,
    this.resolvedBy,
    this.rawStatus,
    this.workflowStatus,
    this.aiNarration,
  });

  Color get statusColor {
    switch (status) {
      case CaseStatus.submitted:
        return Colors.grey;
      case CaseStatus.validated:
        return AppTheme.secondary;
      case CaseStatus.inProgress:
        return AppTheme.warning;
      case CaseStatus.resolved:
        return AppTheme.success;
    }
  }

  String get statusLabel {
    switch (status) {
      case CaseStatus.submitted:
        return 'Submitted';
      case CaseStatus.validated:
        return 'Validated';
      case CaseStatus.inProgress:
        return 'In Progress';
      case CaseStatus.resolved:
        return 'Resolved';
    }
  }

  String get analyticsText {
    final parts = <String>[];
    final submittedText = _formatAnalyticsDate(submittedAt ?? date);
    final locationText = _bestLocationText();
    final categoryText = _categoryAnalyticsLabel(category);
    final severityText = severity.name.toUpperCase();
    final statusText = statusLabel.toLowerCase();

    if (status == CaseStatus.resolved || resolvedAt != null) {
      final resolvedText = resolvedAt == null
          ? null
          : _formatAnalyticsDate(resolvedAt!);
      parts.add(
        'This $categoryText report has been resolved'
        '${resolvedText == null ? '' : ' on $resolvedText'}'
        '${locationText.isNotEmpty ? ' at $locationText' : ''}.',
      );
      parts.add(
        'It was originally submitted on $submittedText and was classified as $severityText severity.',
      );
    } else {
      parts.add(
        'On $submittedText, a $categoryText report was submitted'
        '${locationText.isNotEmpty ? ' at $locationText' : ''}.',
      );
      parts.add(
        'The report is currently $statusText with $severityText severity.',
      );
    }

    final descriptionText = description.trim();
    if (descriptionText.isNotEmpty) {
      parts.add('Reporter description: "$descriptionText".');
    } else {
      parts.add('No reporter description was provided.');
    }

    final timelineFacts = <String>[];
    if (validatedAt != null) {
      timelineFacts.add('validated ${_formatAnalyticsDate(validatedAt!)}');
    }
    if (assignedAt != null) {
      timelineFacts.add('assigned ${_formatAnalyticsDate(assignedAt!)}');
    }
    if (enrouteAt != null) {
      timelineFacts.add(
        'responder en route ${_formatAnalyticsDate(enrouteAt!)}',
      );
    }
    if (arrivedAt != null) {
      timelineFacts.add(
        'responder arrived ${_formatAnalyticsDate(arrivedAt!)}',
      );
    }
    if (resolvedAt != null) {
      timelineFacts.add('resolved ${_formatAnalyticsDate(resolvedAt!)}');
    }
    if (timelineFacts.isNotEmpty) {
      parts.add('Timeline: ${timelineFacts.join('; ')}.');
    }

    final note = resolutionNote?.trim();
    if (note != null && note.isNotEmpty) {
      parts.add('Resolution note: "$note".');
    }

    return parts.join(' ');
  }

  String _bestLocationText() {
    final cleanAddress = address?.trim();
    if (cleanAddress != null && cleanAddress.isNotEmpty) return cleanAddress;
    final cleanLocation = location.trim();
    return cleanLocation == 'Unknown' ? '' : cleanLocation;
  }

  static String _formatAnalyticsDate(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')} at $hour:$minute $period';
  }

  static String _categoryAnalyticsLabel(String rawCategory) {
    final normalized = rawCategory.trim().toUpperCase().replaceAll(' ', '_');
    switch (normalized) {
      case 'BASURA':
      case 'SANITATION':
      case 'WASTE':
        return 'sanitation/waste concern';
      case 'KALSADA':
      case 'ROADS_&_INFRA':
      case 'ROADS_AND_INFRA':
      case 'INFRASTRUCTURE':
        return 'road/infrastructure concern';
      case 'PAGBAHA':
      case 'FLOOD':
      case 'FLOODING':
        return 'flooding concern';
      case 'ILAW_SA_KALYE':
      case 'UTILITIES':
        return 'utilities/streetlight concern';
      case 'TRAPIKO':
      case 'TRAFFIC':
        return 'traffic concern';
      case 'SAFETY_&_EMERGENCY':
      case 'SAFETY_AND_EMERGENCY':
      case 'EMERGENCY':
        return 'safety/emergency concern';
      case 'IBA_PA':
      case 'PUBLIC_CONCERN':
      default:
        final clean = rawCategory.trim();
        return clean.isEmpty
            ? 'public concern'
            : '${clean.toUpperCase()} concern';
    }
  }

  factory CaseModel.fromJson(Map<String, dynamic> json) {
    final timeline = json['timeline'] is Map<String, dynamic>
        ? json['timeline'] as Map<String, dynamic>
        : const <String, dynamic>{};
    final createdAt = _parseDateTime(
      json['createdAt'] ?? json['created_at'] ?? json['timestamp'],
    );

    return CaseModel(
      id: json['id'].toString(),
      title: json['category'] ?? 'Report',
      location: json['city'] ?? 'Unknown',
      date: createdAt ?? DateTime.now(),
      status: _parseStatus(json['status']),
      category: json['category'] ?? 'General',
      description: json['description'] ?? '',
      severity: _parseSeverity(json['severity']),
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
      address: json['address'],
      mediaUrls: _parseStringList(json['mediaUrls'] ?? json['media_urls']),
      mediaTypes: _parseStringList(json['mediaTypes'] ?? json['media_types']),
      submittedAt:
          _parseDateTime(
            timeline['submitted_at'] ??
                json['submittedAt'] ??
                json['submitted_at'],
          ) ??
          createdAt,
      validatedAt: _parseDateTime(
        timeline['validated_at'] ?? json['validatedAt'] ?? json['validated_at'],
      ),
      assignedAt: _parseDateTime(
        timeline['assigned_at'] ?? json['assignedAt'] ?? json['assigned_at'],
      ),
      enrouteAt: _parseDateTime(
        timeline['enroute_at'] ?? json['enrouteAt'] ?? json['enroute_at'],
      ),
      arrivedAt: _parseDateTime(
        timeline['arrived_at'] ?? json['arrivedAt'] ?? json['arrived_at'],
      ),
      resolvedAt: _parseDateTime(
        timeline['resolved_at'] ?? json['resolvedAt'] ?? json['resolved_at'],
      ),
      resolutionNote: json['resolutionNote'],
      resolvedBy: json['resolvedBy'],
      rawStatus: json['raw_status']?.toString(),
      workflowStatus: json['workflow_status']?.toString(),
      aiNarration:
          json['ai_narration']?.toString() ?? json['aiNarration']?.toString(),
    );
  }

  static CaseStatus _parseStatus(String? status) {
    switch (status?.toLowerCase()) {
      case 'submitted':
      case 'pending':
      case 'new':
        return CaseStatus.submitted;
      case 'validated':
      case 'verified':
      case 'reviewed':
        return CaseStatus.validated;
      case 'in_progress':
      case 'in progress':
      case 'dispatched':
      case 'assigned':
      case 'acknowledged':
      case 'en route':
      case 'enroute':
      case 'arrived':
      case 'ongoing':
      case 'pending verification':
      case 'semi resolved':
      case 'needs more proof':
      case 'verification rejected':
        return CaseStatus.inProgress;
      case 'resolved':
      case 'closed':
      case 'completed':
        return CaseStatus.resolved;
      default:
        return CaseStatus.submitted;
    }
  }

  static Severity _parseSeverity(String? severity) {
    switch (severity?.toLowerCase()) {
      case 'low':
        return Severity.low;
      case 'high':
        return Severity.high;
      default:
        return Severity.medium;
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

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .where((item) => item != null)
          .map((item) => item.toString())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    final text = value.toString().trim();
    if (text.isEmpty) return const [];
    return text
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }
}
