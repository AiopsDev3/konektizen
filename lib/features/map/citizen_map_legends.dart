import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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
  final ValueChanged<int> onToggleFloodReturnPeriod, onToggleStormSurgeAdvisory, onLayerOpacityChanged;

  @override
  Widget build(BuildContext context) {
    final hasLayer = showFlood ||
        showLandslide ||
        showStormSurge ||
        showTyphoon ||
        showQuakes ||
        showRainRadar ||
        showFaults ||
        showAqi ||
        showBarangays;
    if (!hasLayer) return const SizedBox.shrink();

    final showOpacity = showFlood || showLandslide || showStormSurge || showBarangays;

    return Container(
      width: 264,
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 16, offset: const Offset(0, 8))],
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
                  Text('Layer Legends', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
                  const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF64748B)),
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
                     if (showRainRadar) _Section(title: 'Heavy Rainfall', rows: _legends['heavy']!),
                     if (showBarangays)
                       _Section(title: 'Barangay Districts', rows: const [
                         ('Districts 1-3', 'North / NE / NW', Color(0xFFE9C46A)),
                         ('Districts 4-6', 'East / South / SE', Color(0xFF4FD1C5)),
                         ('Districts 7-8', 'West / Central', Color(0xFFC084FC)),
                       ]),
                    if (showFlood) ...[
                      _Section(title: 'NOAH Flood Hazard', rows: _legends['flood']!),
                      _Toggles(title: 'NOAH Return Periods', options: _floodOpts, selected: floodReturnPeriods, onToggle: onToggleFloodReturnPeriod),
                    ],
                    if (showLandslide) _Section(title: 'NOAH Landslide Hazard', rows: _legends['landslide']!),
                    if (showStormSurge) ...[
                      _Section(title: 'NOAH Storm Surge Hazard', rows: _legends['storm']!),
                      _Toggles(title: 'Storm Surge Height Bands', options: _stormOpts, selected: stormSurgeAdvisories, onToggle: onToggleStormSurgeAdvisory),
                    ],
                    if (showOpacity) _Opacity(value: layerOpacityPercent, onChanged: onLayerOpacityChanged),
                    if (showTyphoon) _Section(title: 'Typhoon & Tropical Cyclone', rows: _legends['typhoon']!),
                    if (showQuakes) _Section(title: 'Earthquake Monitoring', rows: _legends['quake']!),
                    if (showAqi) _Section(title: 'Air Quality Index', rows: _legends['aqi']!),
                    if (showFaults) _Section(title: 'Active Fault Line', rows: [('Fault Trace', 'PHIVOLCS asset', const Color(0xFFEF4444))]),
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
  final List<(String, String, Color)> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF475569))),
          const SizedBox(height: 6),
          for (final row in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(color: row.$3, borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      row.$2.startsWith('(') ? '${row.$1} ${row.$2}' : '${row.$1}  ${row.$2}',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF334155)),
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
  const _Toggles({required this.title, required this.options, required this.selected, required this.onToggle});
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
          Text(title, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFF64748B))),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: options.map((opt) {
              final active = selected.contains(opt.$1);
              final disabled = opt.$1 == 100;
              final color = disabled ? Colors.black38 : active ? const Color(0xFF15803D) : const Color(0xFF64748B);
              return GestureDetector(
                onTap: disabled ? null : () => onToggle(opt.$1),
                child: Container(
                  width: 110,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: disabled ? const Color(0xFFF1F5F9) : active ? const Color(0xFFF0FDF4) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: active ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(opt.$2, style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: color)),
                      Text(disabled ? 'No Laoag file' : opt.$3, style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w600, color: color.withValues(alpha: 0.7))),
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
              Text('Layer Opacity', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF475569))),
              Text('$value%', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w900, color: const Color(0xFF15803D))),
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
            child: Slider(value: value.toDouble(), min: 0, max: 100, onChanged: (next) => onChanged(next.round())),
          ),
        ],
      ),
    );
  }
}

const _floodOpts = [(5, '5-Year', 'Frequent scenario'), (25, '25-Year', 'Moderate period'), (100, '100-Year', 'Rare period')];
const _stormOpts = [(1, 'Up to 2 m', 'Advisory 1'), (2, 'Up to 3 m', 'Advisory 2'), (3, 'Up to 4 m', 'Advisory 3'), (4, 'Above 4 m', 'Advisory 4')];
const _legends = {
  'heavy': [('No / Light', '0-1 mm/h', Color(0xFF88C6FF)), ('Light', '1-2 mm/h', Color(0xFF3B82F6)), ('Moderate', '2-10 mm/h', Color(0xFF22C55E)), ('Heavy', '10-30 mm/h', Color(0xFFFACC15)), ('Intense', '30-50 mm/h', Color(0xFFF97316)), ('Torrential', '> 50 mm/h', Color(0xFFEF4444))],
  'flood': [('Low Hazard', 'Var 1', Color(0xFF9FCFE6)), ('Medium Hazard', 'Var 2', Color(0xFF4F97C6)), ('High Hazard', 'Var 3', Color(0xFF0B5F8E))],
  'landslide': [('Low Hazard', '(LH 1)', Color(0xFF4CAF50)), ('Medium Hazard', '(LH 2)', Color(0xFFFFEB3B)), ('High Hazard', '(LH 3)', Color(0xFFF44336))],
  'storm': [('Low Hazard', 'HAZ 1', Color(0xFFFACC15)), ('Medium Hazard', 'HAZ 2', Color(0xFFFB923C)), ('High Hazard', 'HAZ 3', Color(0xFFEF4444))],
  'typhoon': [('TD / LPA', '< 62 km/h', Color(0xFF2563EB)), ('Tropical Storm', '62-88 km/h', Color(0xFF10B981)), ('STS / TY', '89-184 km/h', Color(0xFFEF4444)), ('Super Typhoon', '>= 185 km/h', Color(0xFF4C1D95))],
  'quake': [('Deep', '> 70 km depth', Color(0xFF3B82F6)), ('Intermediate', '30-70 km depth', Color(0xFFF59E0B)), ('Shallow', '< 30 km depth', Color(0xFFEF4444)), ('Heat Core', 'High density', Color(0xFFB2182B))],
  'aqi': [('Good', '0-50 AQI', Color(0xFF00E400)), ('Moderate', '51-100 AQI', Color(0xFFFFFF00)), ('USG', '101-150 AQI', Color(0xFFFF7E00)), ('Unhealthy', '151-200 AQI', Color(0xFFFF0000)), ('Very Unhealthy', '201-300 AQI', Color(0xFF8F3F97)), ('Hazardous', '301+ AQI', Color(0xFF7E0023))],
};
