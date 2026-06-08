import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:konektizen/features/map/citizen_map_glass.dart';
import 'package:konektizen/theme/app_theme.dart';

class CitizenMapLayersMenu extends StatelessWidget {
  const CitizenMapLayersMenu({
    super.key,
    required this.onClose,
    required this.showFlood,
    required this.showLandslide,
    required this.showStormSurge,
    required this.showTyphoon,
    required this.showQuakes,
    required this.showRainRadar,
    required this.showBarangayRain,
    required this.showFaults,
    required this.showAqi,
    required this.showSevereWeather,
    required this.showLocalFacilities,
    required this.showLocalHazards,
    required this.onToggleFlood,
    required this.onToggleLandslide,
    required this.onToggleStormSurge,
    required this.onToggleTyphoon,
    required this.onToggleQuakes,
    required this.onToggleRainRadar,
    required this.onToggleBarangayRain,
    required this.onToggleFaults,
    required this.onToggleAqi,
    required this.onToggleSevereWeather,
    required this.onToggleLocalFacilities,
    required this.onToggleLocalHazards,
  });

  final VoidCallback onClose;
  final bool showFlood;
  final bool showLandslide;
  final bool showStormSurge;
  final bool showTyphoon;
  final bool showQuakes;
  final bool showRainRadar;
  final bool showBarangayRain;
  final bool showFaults;
  final bool showAqi;
  final bool showSevereWeather;
  final bool showLocalFacilities;
  final bool showLocalHazards;
  final VoidCallback onToggleFlood;
  final VoidCallback onToggleLandslide;
  final VoidCallback onToggleStormSurge;
  final VoidCallback onToggleTyphoon;
  final VoidCallback onToggleQuakes;
  final VoidCallback onToggleRainRadar;
  final VoidCallback onToggleBarangayRain;
  final VoidCallback onToggleFaults;
  final VoidCallback onToggleAqi;
  final VoidCallback onToggleSevereWeather;
  final VoidCallback onToggleLocalFacilities;
  final VoidCallback onToggleLocalHazards;

  @override
  Widget build(BuildContext context) {
    final options = [
      _LayerOptionData(
        Icons.local_hospital_outlined,
        'Facilities',
        showLocalFacilities,
        onToggleLocalFacilities,
      ),
      _LayerOptionData(
        Icons.warning_amber_outlined,
        'Hazard Areas',
        showLocalHazards,
        onToggleLocalHazards,
      ),
      _LayerOptionData(
        Icons.radar,
        'Rain Radar',
        showRainRadar,
        onToggleRainRadar,
      ),
      _LayerOptionData(
        Icons.water_drop,
        'Barangay Rain Threat',
        showBarangayRain,
        onToggleBarangayRain,
      ),
      _LayerOptionData(
        Icons.water_drop_outlined,
        'Flood Susceptibility',
        showFlood,
        onToggleFlood,
      ),
      _LayerOptionData(
        Icons.landslide_outlined,
        'Landslide Hazard',
        showLandslide,
        onToggleLandslide,
      ),
      _LayerOptionData(
        Icons.waves,
        'Storm Surge',
        showStormSurge,
        onToggleStormSurge,
      ),
      _LayerOptionData(
        Icons.cyclone_outlined,
        'Typhoon',
        showTyphoon,
        onToggleTyphoon,
      ),
      _LayerOptionData(
        Icons.timeline,
        'Active Faults',
        showFaults,
        onToggleFaults,
      ),
      _LayerOptionData(
        Icons.public_outlined,
        'Earthquakes',
        showQuakes,
        onToggleQuakes,
      ),
      _LayerOptionData(Icons.air, 'Air Quality', showAqi, onToggleAqi),
      _LayerOptionData(
        Icons.warning_amber,
        'Severe Weather',
        showSevereWeather,
        onToggleSevereWeather,
      ),
    ];

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: 220,
          constraints: const BoxConstraints(maxHeight: 430),
          decoration: mapGlassDecoration(16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Map Layers',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    GestureDetector(
                      onTap: onClose,
                      child: const Icon(
                        Icons.close,
                        size: 18,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemBuilder: (_, index) => _LayerOption(data: options[index]),
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 14),
                  itemCount: options.length,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LayerOptionData {
  const _LayerOptionData(this.icon, this.label, this.active, this.onTap);

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
}

class _LayerOption extends StatelessWidget {
  const _LayerOption({required this.data});

  final _LayerOptionData data;

  @override
  Widget build(BuildContext context) {
    final color = data.active ? AppTheme.primary : Colors.black54;
    return GestureDetector(
      onTap: data.onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Icon(data.icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              data.label,
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: data.active ? FontWeight.w600 : FontWeight.w500,
                color: data.active ? AppTheme.primary : Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
