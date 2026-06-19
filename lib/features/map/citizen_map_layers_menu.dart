import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
    required this.showFaults,
    required this.showAqi,
    required this.showLocalFacilities,
    required this.showLocalHazards,
    required this.showBarangays,
    required this.onToggleFlood,
    required this.onToggleLandslide,
    required this.onToggleStormSurge,
    required this.onToggleTyphoon,
    required this.onToggleQuakes,
    required this.onToggleRainRadar,
    required this.onToggleFaults,
    required this.onToggleAqi,
    required this.onToggleLocalFacilities,
    required this.onToggleLocalHazards,
    required this.onToggleBarangays,
    required this.onToggleSettings,
  });

  final VoidCallback onClose,
      onToggleFlood,
      onToggleLandslide,
      onToggleStormSurge,
      onToggleTyphoon,
      onToggleQuakes,
      onToggleRainRadar,
      onToggleFaults,
      onToggleAqi,
      onToggleLocalFacilities,
      onToggleLocalHazards,
      onToggleBarangays,
      onToggleSettings;
  final bool showFlood,
      showLandslide,
      showStormSurge,
      showTyphoon,
      showQuakes,
      showRainRadar,
      showFaults,
      showAqi,
      showLocalFacilities,
      showLocalHazards,
      showBarangays;

  @override
  Widget build(BuildContext context) {
    final options = [
      _Opt(Icons.business_outlined, 'Facilities', showLocalFacilities, onToggleLocalFacilities),
      _Opt(Icons.warning_amber_rounded, 'Hazard Areas', showLocalHazards, onToggleLocalHazards),
      _Opt(Icons.map_outlined, 'Barangay Boundaries', showBarangays, onToggleBarangays),
      _Opt(Icons.cloudy_snowing, 'Heavy Rainfall', showRainRadar, onToggleRainRadar),
      _Opt(Icons.water_drop_outlined, 'Flood Susceptibility', showFlood, onToggleFlood),
      _Opt(Icons.landslide_outlined, 'Landslide Hazard', showLandslide, onToggleLandslide),
      _Opt(Icons.waves, 'Storm Surge', showStormSurge, onToggleStormSurge),
      _Opt(Icons.cyclone_outlined, 'Typhoon', showTyphoon, onToggleTyphoon),
      _Opt(Icons.show_chart, 'Active Faults', showFaults, onToggleFaults),
      _Opt(Icons.sensors_rounded, 'Earthquakes', showQuakes, onToggleQuakes),
      _Opt(Icons.air, 'Air Quality', showAqi, onToggleAqi),
    ];

    return Container(
      width: 250,
      constraints: const BoxConstraints(maxHeight: 560),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Map Layers', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              itemCount: options.length,
              itemBuilder: (context, index) {
                final opt = options[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: InkWell(
                    onTap: opt.onTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: opt.active ? const Color(0xFFF0FDF4) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(opt.icon, size: 18, color: opt.active ? const Color(0xFF15803D) : const Color(0xFF64748B)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              opt.label,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: opt.active ? FontWeight.w700 : FontWeight.w500,
                                color: opt.active ? const Color(0xFF15803D) : const Color(0xFF334155),
                              ),
                            ),
                          ),
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: opt.active ? const Color(0xFF15803D) : Colors.transparent,
                              border: opt.active ? null : Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: opt.active ? const Icon(Icons.check, size: 13, color: Colors.white) : null,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          InkWell(
            onTap: onToggleSettings,
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Icon(Icons.settings_outlined, size: 18, color: Color(0xFF64748B)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Layer Settings', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF1E293B))),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Opt {
  const _Opt(this.icon, this.label, this.active, this.onTap);
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
}
