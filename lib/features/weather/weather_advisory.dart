class WeatherAdvisory {
  const WeatherAdvisory({
    required this.id,
    required this.signalId,
    required this.title,
    required this.summary,
    required this.severityLevel,
    required this.urgencyLevel,
    required this.issuedAt,
    this.preparedness,
    this.locationText,
    this.sourceName,
    this.sourceItemId,
    this.metrics = const {},
  });

  final int id;
  final String signalId;
  final String title;
  final String summary;
  final String? preparedness;
  final String severityLevel;
  final String urgencyLevel;
  final String? locationText;
  final String? sourceName;
  final String? sourceItemId;
  final Map<String, dynamic> metrics;
  final DateTime issuedAt;

  factory WeatherAdvisory.fromJson(Map<String, dynamic> json) {
    return WeatherAdvisory(
      id: _asInt(json['id']),
      signalId: _asString(json['signalId'], fallback: 'weather-advisory'),
      title: _asString(json['title'], fallback: 'Weather Advisory'),
      summary: _asString(json['summary'], fallback: 'Monitor weather updates.'),
      preparedness: _optionalString(json['preparedness']),
      severityLevel: _asString(json['severityLevel'], fallback: 'moderate'),
      urgencyLevel: _asString(json['urgencyLevel'], fallback: 'monitor'),
      locationText: _optionalString(json['locationText']),
      sourceName: _optionalString(json['sourceName']),
      sourceItemId: _optionalString(json['sourceItemId']),
      metrics: _asMap(json['metrics']),
      issuedAt:
          _asDate(json['issuedAt']) ??
          _asDate(json['createdAt']) ??
          DateTime.now(),
    );
  }

  int get severityRank {
    switch (severityLevel.toLowerCase()) {
      case 'critical':
        return 4;
      case 'high':
        return 3;
      case 'moderate':
        return 2;
      case 'low':
        return 1;
      default:
        return 0;
    }
  }

  bool get shouldNotify => severityRank >= 3;
}

int _asInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

String _asString(dynamic value, {required String fallback}) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
}

String? _optionalString(dynamic value) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? null : text;
}

DateTime? _asDate(dynamic value) {
  if (value == null) return null;
  return DateTime.tryParse(value.toString())?.toLocal();
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((key, mapValue) => MapEntry(key.toString(), mapValue));
  }
  return const {};
}
