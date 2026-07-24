import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:konektizen/features/map/citizen_map_hazard_catalog.dart';

class CitizenMapLegends extends StatelessWidget {
  const CitizenMapLegends({
    super.key,
    required this.showFlood,
    required this.floodReturnPeriods,
    required this.showLandslide,
    required this.showStormSurge,
    required this.stormSurgeAdvisories,
    required this.showTyphoon,
    required this.showQuakes,
    required this.showRainRadar,
    required this.showFaults,
    required this.showAqi,
    required this.showBarangays,
    required this.layerOpacityPercent,
    required this.onToggleFloodReturnPeriod,
    required this.onToggleStormSurgeAdvisory,
    required this.onLayerOpacityChanged,
  });

  final bool showFlood,
      showLandslide,
      showStormSurge,
      showTyphoon,
      showQuakes,
      showRainRadar,
      showFaults,
      showAqi,
      showBarangays;
  final List<int> floodReturnPeriods, stormSurgeAdvisories;
  final int layerOpacityPercent;
  final ValueChanged<int> onToggleFloodReturnPeriod,
      onToggleStormSurgeAdvisory,
      onLayerOpacityChanged;

  @override
  Widget build(BuildContext context) {
    final activeLayerNames = <String>[
      if (showRainRadar) 'Heavy Rainfall',
      if (showFlood) 'Flood',
      if (showLandslide) 'Landslide',
      if (showStormSurge) 'Storm Surge',
      if (showTyphoon) 'Typhoon',
      if (showAqi) 'Air Quality Index',
      if (showQuakes) 'Earthquake',
      if (showFaults) 'Active Faults',
      if (showBarangays) 'Barangay Boundaries',
    ];
    final hasLayer =
        showFlood ||
        showLandslide ||
        showStormSurge ||
        showTyphoon ||
        showQuakes ||
        showRainRadar ||
        showFaults ||
        showAqi ||
        showBarangays;
    if (!hasLayer) return const SizedBox.shrink();

    final showOpacity =
        showFlood || showLandslide || showStormSurge || showBarangays;

    return Container(
      width: 264,
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeLayerNames.length == 1
                              ? '${activeLayerNames.first} Layer'
                              : 'Active Map Layers',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          'C3 AIOPSYS hazard view',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Color(0xFF64748B),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9)),
            Flexible(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showRainRadar)
                      const _Section(
                        title: 'Heavy Rainfall',
                        rows: heavyRainfallLegend,
                      ),
                    if (showBarangays)
                      _Section(
                        title: 'Barangay Districts',
                        rows: const [
                          CitizenMapLegendEntry(
                            'Districts 1-3',
                            'North / NE / NW',
                            Color(0xFFE9C46A),
                          ),
                          CitizenMapLegendEntry(
                            'Districts 4-6',
                            'East / South / SE',
                            Color(0xFF4FD1C5),
                          ),
                          CitizenMapLegendEntry(
                            'Districts 7-8',
                            'West / Central',
                            Color(0xFFC084FC),
                          ),
                        ],
                      ),
                    if (showFlood) ...[
                      const _Section(
                        title: 'NOAH Flood Hazard',
                        rows: floodLegend,
                      ),
                      _Toggles(
                        title: 'NOAH Return Periods',
                        options: _floodOpts,
                        selected: floodReturnPeriods,
                        onToggle: onToggleFloodReturnPeriod,
                      ),
                    ],
                    if (showLandslide)
                      const _Section(
                        title: 'NOAH Landslide Hazard',
                        rows: landslideLegend,
                      ),
                    if (showStormSurge) ...[
                      const _Section(
                        title: 'NOAH Storm Surge Hazard',
                        rows: stormSurgeLegend,
                      ),
                      _Toggles(
                        title: 'Storm Surge Height Bands',
                        options: _stormOpts,
                        selected: stormSurgeAdvisories,
                        onToggle: onToggleStormSurgeAdvisory,
                      ),
                    ],
                    if (showOpacity)
                      _Opacity(
                        value: layerOpacityPercent,
                        onChanged: onLayerOpacityChanged,
                      ),
                    if (showTyphoon)
                      const _Section(
                        title: 'Typhoon & Tropical Cyclone',
                        rows: _typhoonLegend,
                      ),
                    if (showQuakes)
                      const _Section(
                        title: 'Earthquake Monitoring',
                        rows: earthquakeLegend,
                      ),
                    if (showAqi)
                      const _Section(
                        title: 'Air Quality Index',
                        rows: airQualityLegend,
                      ),
                    if (showFaults)
                      const _Section(
                        title: 'Active Fault Line',
                        rows: [
                          CitizenMapLegendEntry(
                            'Fault Trace',
                            'PHIVOLCS asset',
                            Color(0xFFEF4444),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.rows});
  final String title;
  final List<CitizenMapLegendEntry> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: row.color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${row.label}  ${row.range}',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Toggles extends StatelessWidget {
  const _Toggles({
    required this.title,
    required this.options,
    required this.selected,
    required this.onToggle,
  });
  final String title;
  final List<(int, String, String)> options;
  final List<int> selected;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: options.map((opt) {
              final active = selected.contains(opt.$1);
              final color = active
                  ? const Color(0xFF15803D)
                  : const Color(0xFF64748B);
              return GestureDetector(
                onTap: () => onToggle(opt.$1),
                child: Container(
                  width: 110,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: active ? const Color(0xFFF0FDF4) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: active
                          ? const Color(0xFF86EFAC)
                          : const Color(0xFFE2E8F0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        opt.$2,
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: color,
                        ),
                      ),
                      Text(
                        opt.$3,
                        style: GoogleFonts.inter(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                          color: color.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _Opacity extends StatelessWidget {
  const _Opacity({required this.value, required this.onChanged});
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Layer Opacity',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF475569),
                ),
              ),
              Text(
                '$value%',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF15803D),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: const Color(0xFF15803D),
              inactiveTrackColor: const Color(0xFFE2E8F0),
              thumbColor: const Color(0xFF15803D),
              overlayColor: const Color(0xFF15803D).withValues(alpha: 0.12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 100,
              onChanged: (next) => onChanged(next.round()),
            ),
          ),
        ],
      ),
    );
  }
}

const _floodOpts = [
  (5, '5-Year', 'Frequent scenario'),
  (25, '25-Year', 'Moderate period'),
  (100, '100-Year', 'Rare period'),
];
const _stormOpts = [
  (1, 'Up to 2 m', 'Advisory 1'),
  (2, 'Up to 3 m', 'Advisory 2'),
  (3, 'Up to 4 m', 'Advisory 3'),
  (4, 'Above 4 m', 'Advisory 4'),
];
const _typhoonLegend = <CitizenMapLegendEntry>[
  CitizenMapLegendEntry('TD / LPA', '< 62 km/h', Color(0xFF2563EB)),
  CitizenMapLegendEntry('Tropical Storm', '62 - 88 km/h', Color(0xFF10B981)),
  CitizenMapLegendEntry('STS / TY', '89 - 184 km/h', Color(0xFFEF4444)),
  CitizenMapLegendEntry('Super Typhoon', '>= 185 km/h', Color(0xFF4C1D95)),
];
