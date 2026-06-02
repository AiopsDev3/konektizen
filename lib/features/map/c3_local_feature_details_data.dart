typedef C3DetailRow = ({String label, String value});

Map<String, dynamic> c3FeatureProperties(Map<String, dynamic> feature) {
  final raw = feature['properties'];
  if (raw is Map) {
    return raw.map((key, value) => MapEntry(key.toString(), value));
  }
  return {};
}

List<C3DetailRow> c3FeatureDetailRows(
  Map<String, dynamic> properties,
  dynamic geometry,
) {
  final coordinates = c3CoordinatesLabel(geometry);
  return [
    (label: 'Status', value: c3Read(properties, 'status')),
    (label: 'Severity', value: c3Read(properties, 'severity')),
    (label: 'Barangay', value: c3Read(properties, 'barangay')),
    (label: 'Capacity', value: c3Read(properties, 'capacity')),
    (label: 'Contact Person', value: c3Read(properties, 'contactPerson')),
    (label: 'Contact Number', value: c3Read(properties, 'contactNumber')),
    (label: 'Source', value: c3Read(properties, 'sourceType')),
    (label: 'Description', value: c3Read(properties, 'description')),
    (label: 'Start Date', value: c3Read(properties, 'startDate')),
    (label: 'End Date', value: c3Read(properties, 'endDate')),
    if (coordinates.isNotEmpty) (label: 'Coordinates', value: coordinates),
  ].where((row) => row.value.trim().isNotEmpty).toList();
}

String c3Read(
  Map<String, dynamic> properties,
  String key, {
  String fallback = '',
}) {
  final value = properties[key]?.toString().trim() ?? '';
  return value.isEmpty ? fallback : value;
}

String c3CoordinatesLabel(dynamic geometry) {
  if (geometry is! Map) return '';
  final coordinates = geometry['coordinates'];
  if (coordinates is! List || coordinates.length < 2) return '';
  final lng = double.tryParse(coordinates[0].toString());
  final lat = double.tryParse(coordinates[1].toString());
  if (lat == null || lng == null) return '';
  return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}
