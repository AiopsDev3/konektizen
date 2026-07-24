import 'package:flutter/material.dart';

/// Shared hazard colors and labels mirrored from C3 AIOPSYS.
///
/// Keeping the map paint rules and legend rows in one catalog prevents the
/// mobile map from drawing one classification while describing another.
class CitizenMapLegendEntry {
  const CitizenMapLegendEntry(this.label, this.range, this.color);

  final String label;
  final String range;
  final Color color;
}

const heavyRainfallLegend = <CitizenMapLegendEntry>[
  CitizenMapLegendEntry('No / Trace', '0 - 0.5 mm/h', Color(0xFF94A3B8)),
  CitizenMapLegendEntry('Light', '0.5 - 2 mm/h', Color(0xFF22C55E)),
  CitizenMapLegendEntry('Moderate', '2 - 10 mm/h', Color(0xFFA3E635)),
  CitizenMapLegendEntry('Heavy', '10 - 30 mm/h', Color(0xFFFACC15)),
  CitizenMapLegendEntry('Intense', '30 - 50 mm/h', Color(0xFFF97316)),
  CitizenMapLegendEntry('Torrential', '> 50 mm/h', Color(0xFFEF4444)),
];

const floodLegend = <CitizenMapLegendEntry>[
  CitizenMapLegendEntry('Low Hazard', 'Var 1', Color(0xFF9FCFE6)),
  CitizenMapLegendEntry('Medium Hazard', 'Var 2', Color(0xFF4F97C6)),
  CitizenMapLegendEntry('High Hazard', 'Var 3', Color(0xFF0B5F8E)),
];

const landslideLegend = <CitizenMapLegendEntry>[
  CitizenMapLegendEntry('Low Hazard', 'HAZ 1', Color(0xFFFACC15)),
  CitizenMapLegendEntry('Medium Hazard', 'HAZ 2', Color(0xFFFB923C)),
  CitizenMapLegendEntry('High Hazard', 'HAZ 3', Color(0xFFEF4444)),
  CitizenMapLegendEntry('Debris Flow', 'HAZ 4', Color(0xFF7F1D1D)),
];

const stormSurgeLegend = <CitizenMapLegendEntry>[
  CitizenMapLegendEntry('Low Hazard', 'HAZ 1', Color(0xFFFACC15)),
  CitizenMapLegendEntry('Medium Hazard', 'HAZ 2', Color(0xFFFB923C)),
  CitizenMapLegendEntry('High Hazard', 'HAZ 3', Color(0xFFEF4444)),
];

const earthquakeLegend = <CitizenMapLegendEntry>[
  CitizenMapLegendEntry('Minor', '< 4.0 M', Color(0xFF22C55E)),
  CitizenMapLegendEntry('Light', '4.0 - 4.9 M', Color(0xFFEAB308)),
  CitizenMapLegendEntry('Moderate', '5.0 - 5.9 M', Color(0xFFF97316)),
  CitizenMapLegendEntry('Strong', '6.0 - 6.9 M', Color(0xFFEF4444)),
  CitizenMapLegendEntry('Major', '>= 7.0 M', Color(0xFF7F1D1D)),
];

const airQualityLegend = <CitizenMapLegendEntry>[
  CitizenMapLegendEntry('Good', '0 - 50 AQI', Color(0xFF00E400)),
  CitizenMapLegendEntry('Moderate', '51 - 100 AQI', Color(0xFFFFFF00)),
  CitizenMapLegendEntry('USG', '101 - 150 AQI', Color(0xFFFF7E00)),
  CitizenMapLegendEntry('Unhealthy', '151 - 200 AQI', Color(0xFFFF0000)),
  CitizenMapLegendEntry('Very Unhealthy', '201 - 300 AQI', Color(0xFF8F3F97)),
  CitizenMapLegendEntry('Hazardous', '301+ AQI', Color(0xFF7E0023)),
];

String earthquakeMagnitudeColor(double? magnitude) {
  final value = magnitude ?? 0;
  if (value >= 7) return '#7f1d1d';
  if (value >= 6) return '#ef4444';
  if (value >= 5) return '#f97316';
  if (value >= 4) return '#eab308';
  return '#22c55e';
}

String aqiColor(num value) {
  if (value <= 50) return '#00e400';
  if (value <= 100) return '#ffff00';
  if (value <= 150) return '#ff7e00';
  if (value <= 200) return '#ff0000';
  if (value <= 300) return '#8f3f97';
  return '#7e0023';
}
