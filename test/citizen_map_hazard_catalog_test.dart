import 'package:flutter_test/flutter_test.dart';
import 'package:konektizen/features/map/citizen_map_hazard_catalog.dart';

void main() {
  test('hazard legends match the AIOPSYS category counts', () {
    expect(heavyRainfallLegend, hasLength(6));
    expect(floodLegend, hasLength(3));
    expect(landslideLegend, hasLength(4));
    expect(stormSurgeLegend, hasLength(3));
    expect(earthquakeLegend, hasLength(5));
    expect(airQualityLegend, hasLength(6));
  });

  test('earthquakes use magnitude-based AIOPSYS colors', () {
    expect(earthquakeMagnitudeColor(3.9), '#22c55e');
    expect(earthquakeMagnitudeColor(4.0), '#eab308');
    expect(earthquakeMagnitudeColor(5.0), '#f97316');
    expect(earthquakeMagnitudeColor(6.0), '#ef4444');
    expect(earthquakeMagnitudeColor(7.0), '#7f1d1d');
  });

  test('AQI colors cover every AIOPSYS boundary', () {
    expect(aqiColor(50), '#00e400');
    expect(aqiColor(51), '#ffff00');
    expect(aqiColor(101), '#ff7e00');
    expect(aqiColor(151), '#ff0000');
    expect(aqiColor(201), '#8f3f97');
    expect(aqiColor(301), '#7e0023');
  });
}
