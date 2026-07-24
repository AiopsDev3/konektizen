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
    final hazards = [
      _Opt(
        Icons.cloudy_snowing,
        'Heavy Rainfall',
        showRainRadar,
        onToggleRainRadar,
        const Color(0xFF10B981),
      ),
      _Opt(
        Icons.cyclone_outlined,
        'Typhoon',
        showTyphoon,
        onToggleTyphoon,
        const Color(0xFFEF4444),
      ),
      _Opt(
        Icons.water_drop_outlined,
        'Flood',
        showFlood,
        onToggleFlood,
        const Color(0xFF14B8A6),
      ),
      _Opt(
        Icons.landslide_outlined,
        'Landslide',
        showLandslide,
        onToggleLandslide,
        const Color(0xFF3B82F6),
      ),
      _Opt(
        Icons.waves,
        'Storm Surge',
        showStormSurge,
        onToggleStormSurge,
        const Color(0xFF0EA5E9),
      ),
      _Opt(
        Icons.air,
        'Air Quality Index',
        showAqi,
        onToggleAqi,
        const Color(0xFF10B981),
      ),
      _Opt(
        Icons.sensors_rounded,
        'Earthquake',
        showQuakes,
        onToggleQuakes,
        const Color(0xFF10B981),
      ),
    ];
    final localOverlays = [
      _Opt(
        Icons.business_outlined,
        'Facilities',
        showLocalFacilities,
        onToggleLocalFacilities,
      ),
      _Opt(
        Icons.warning_amber_rounded,
        'Hazard Areas',
        showLocalHazards,
        onToggleLocalHazards,
      ),
      _Opt(
        Icons.map_outlined,
        'Barangay Boundaries',
        showBarangays,
        onToggleBarangays,
      ),
      _Opt(Icons.show_chart, 'Active Faults', showFaults, onToggleFaults),
    ];

    return Container(
      width: 268,
      constraints: const BoxConstraints(maxHeight: 540),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Map Layers',
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF0F172A),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.close,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(14, 2, 14, 12),
              children: [
                _SectionLabel('Select Hazard to View (${hazards.length})'),
                const SizedBox(height: 8),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final itemWidth = (constraints.maxWidth - 8) / 2;
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: hazards
                          .map(
                            (opt) => SizedBox(
                              width: itemWidth,
                              child: _HazardChip(option: opt),
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Divider(height: 1, color: Color(0xFFE2E8F0)),
                ),
                const _SectionLabel('Local Map Overlays'),
                const SizedBox(height: 6),
                for (final opt in localOverlays) _OverlayRow(option: opt),
              ],
            ),
          ),
          const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
          InkWell(
            onTap: onToggleSettings,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.settings_outlined,
                    size: 18,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Layer Settings',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: Color(0xFF94A3B8),
                  ),
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
  const _Opt(
    this.icon,
    this.label,
    this.active,
    this.onTap, [
    this.accent = const Color(0xFF64748B),
  ]);
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color accent;
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: GoogleFonts.inter(
      fontSize: 9.5,
      fontWeight: FontWeight.w800,
      letterSpacing: 0.7,
      color: const Color(0xFF64748B),
    ),
  );
}

class _HazardChip extends StatelessWidget {
  const _HazardChip({required this.option});
  final _Opt option;

  @override
  Widget build(BuildContext context) {
    const selected = Color(0xFF2563EB);
    return Material(
      color: option.active ? const Color(0xFFEFF6FF) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: option.onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: option.active
                  ? const Color(0xFF93C5FD)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Icon(
                option.icon,
                size: 17,
                color: option.active ? selected : option.accent,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  option.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 10.5,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    color: option.active
                        ? const Color(0xFF1D4ED8)
                        : const Color(0xFF475569),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayRow extends StatelessWidget {
  const _OverlayRow({required this.option});
  final _Opt option;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: option.onTap,
    borderRadius: BorderRadius.circular(9),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      child: Row(
        children: [
          Icon(option.icon, size: 17, color: const Color(0xFF64748B)),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              option.label,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF334155),
              ),
            ),
          ),
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: option.active
                  ? const Color(0xFF2563EB)
                  : Colors.transparent,
              border: option.active
                  ? null
                  : Border.all(color: const Color(0xFFCBD5E1), width: 1.4),
              borderRadius: BorderRadius.circular(5),
            ),
            child: option.active
                ? const Icon(Icons.check, size: 13, color: Colors.white)
                : null,
          ),
        ],
      ),
    ),
  );
}
