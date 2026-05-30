import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:konektizen/features/map/citizen_map_glass.dart';

class CitizenMapLegends extends StatelessWidget {
  const CitizenMapLegends({
    super.key,
    required this.showFlood,
    required this.showLandslide,
    required this.showQuakes,
    required this.showFire,
    required this.showRainRadar,
    required this.showBarangayRain,
    required this.showFaults,
    required this.showVolcanoes,
    required this.showAqi,
    required this.showSevereWeather,
  });

  final bool showFlood;
  final bool showLandslide;
  final bool showQuakes;
  final bool showFire;
  final bool showRainRadar;
  final bool showBarangayRain;
  final bool showFaults;
  final bool showVolcanoes;
  final bool showAqi;
  final bool showSevereWeather;

  @override
  Widget build(BuildContext context) {
    if (!showFlood &&
        !showLandslide &&
        !showQuakes &&
        !showFire &&
        !showRainRadar &&
        !showBarangayRain &&
        !showFaults &&
        !showVolcanoes &&
        !showAqi &&
        !showSevereWeather) {
      return const SizedBox.shrink();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: 220,
          padding: const EdgeInsets.all(12),
          decoration: mapGlassDecoration(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Layer Legends',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              if (showRainRadar)
                const _LegendItem(
                  color: Colors.blueAccent,
                  label: 'Rainfall Radar (RainViewer)',
                ),
              if (showBarangayRain) ...[
                const _LegendItem(
                  color: Color(0xFF22c55e),
                  label: 'Low Rain Threat',
                ),
                const _LegendItem(
                  color: Color(0xFFeab308),
                  label: 'Moderate Rain Threat',
                ),
                const _LegendItem(
                  color: Color(0xFFef4444),
                  label: 'Heavy Rain Threat',
                ),
              ],
              if (showFlood)
                const _LegendItem(
                  color: Color(0xFFC51B8A),
                  label: 'MGB Flood Susceptibility',
                ),
              if (showLandslide)
                const _LegendItem(
                  color: Color(0xFFE31A1C),
                  label: 'MGB Landslide Hazard',
                ),
              if (showFaults)
                const _LegendItem(
                  color: Color(0xFFEF4444),
                  label: 'Active Fault Line',
                ),
              if (showFire)
                const _LegendItem(
                  color: Color(0xFFF97316),
                  label: 'Fire Status (NASA EONET)',
                  isCircle: true,
                ),
              if (showQuakes)
                const _LegendItem(
                  color: Color(0xFFEF4444),
                  label: 'Live Earthquake (USGS)',
                  isCircle: true,
                ),
              if (showVolcanoes)
                const _LegendItem(
                  color: Color(0xFFB91C1C),
                  label: 'Tectonic Boundary',
                  isCircle: true,
                ),
              if (showAqi)
                const _LegendItem(
                  color: Color(0xFF22C55E),
                  label: 'Air Quality Status',
                  isCircle: true,
                ),
              if (showSevereWeather)
                const _LegendItem(
                  color: Color(0xFF8B5CF6),
                  label: 'Severe Weather Status',
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    this.isCircle = false,
  });

  final Color color;
  final String label;
  final bool isCircle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: color,
              shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
              borderRadius: isCircle ? null : BorderRadius.circular(3),
              border: Border.all(color: Colors.black12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
