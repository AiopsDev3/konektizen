import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:konektizen/features/map/citizen_map_glass.dart';
import 'package:konektizen/theme/app_theme.dart';

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
    required this.showBarangayRain,
    required this.showFaults,
    required this.showAqi,
    required this.showSevereWeather,
    required this.layerOpacityPercent,
    required this.onToggleFloodReturnPeriod,
    required this.onToggleStormSurgeAdvisory,
    required this.onLayerOpacityChanged,
  });

  final bool showFlood;
  final List<int> floodReturnPeriods;
  final bool showLandslide;
  final bool showStormSurge;
  final List<int> stormSurgeAdvisories;
  final bool showTyphoon;
  final bool showQuakes;
  final bool showRainRadar;
  final bool showBarangayRain;
  final bool showFaults;
  final bool showAqi;
  final bool showSevereWeather;
  final int layerOpacityPercent;
  final ValueChanged<int> onToggleFloodReturnPeriod;
  final ValueChanged<int> onToggleStormSurgeAdvisory;
  final ValueChanged<int> onLayerOpacityChanged;

  @override
  Widget build(BuildContext context) {
    final hasLayer =
        showFlood ||
        showLandslide ||
        showStormSurge ||
        showTyphoon ||
        showQuakes ||
        showRainRadar ||
        showBarangayRain ||
        showFaults ||
        showAqi ||
        showSevereWeather;
    if (!hasLayer) return const SizedBox.shrink();

    final maxHeight = MediaQuery.sizeOf(context).height * 0.58;
    final showOpacity = showFlood || showLandslide || showStormSurge;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: 264,
          constraints: BoxConstraints(maxHeight: maxHeight.clamp(260, 480)),
          padding: const EdgeInsets.all(12),
          decoration: mapGlassDecoration(16),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
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
                if (showRainRadar || showBarangayRain)
                  const _LegendSection(
                    title: 'Rainfall Forecast',
                    rows: _rainfallRows,
                  ),
                if (showFlood) ...[
                  const _LegendSection(
                    title: 'NOAH Flood Hazard',
                    rows: _floodRows,
                  ),
                  _ToggleGroup(
                    title: 'NOAH Return Periods',
                    options: _floodOptions,
                    selected: floodReturnPeriods,
                    disabled: const [100],
                    onToggle: onToggleFloodReturnPeriod,
                  ),
                ],
                if (showLandslide)
                  const _LegendSection(
                    title: 'NOAH Landslide Hazard',
                    rows: _landslideRows,
                  ),
                if (showStormSurge) ...[
                  const _LegendSection(
                    title: 'NOAH Storm Surge Hazard',
                    rows: _stormSurgeRows,
                  ),
                  _ToggleGroup(
                    title: 'Storm Surge Height Bands',
                    options: _stormSurgeOptions,
                    selected: stormSurgeAdvisories,
                    onToggle: onToggleStormSurgeAdvisory,
                  ),
                ],
                if (showOpacity)
                  _OpacityControl(
                    value: layerOpacityPercent,
                    onChanged: onLayerOpacityChanged,
                  ),
                if (showTyphoon)
                  const _LegendSection(
                    title: 'Typhoon & Tropical Cyclone',
                    rows: _typhoonRows,
                  ),
                if (showQuakes)
                  const _LegendSection(
                    title: 'Earthquake Monitoring',
                    rows: _earthquakeRows,
                  ),
                if (showAqi)
                  const _LegendSection(
                    title: 'Air Quality Index',
                    rows: _aqiRows,
                  ),
                if (showFaults)
                  const _LegendSection(
                    title: 'Active Fault Line',
                    rows: [
                      _LegendRowData(
                        'Fault Trace',
                        'PHIVOLCS local asset',
                        Color(0xFFEF4444),
                      ),
                    ],
                  ),
                if (showSevereWeather)
                  const _LegendSection(
                    title: 'Severe Weather Status',
                    rows: [
                      _LegendRowData(
                        'Severe possible',
                        'Open-Meteo weather code >= 80',
                        Color(0xFF8B5CF6),
                      ),
                      _LegendRowData(
                        'No severe signal',
                        'Current screening point',
                        Color(0xFF22C55E),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LegendSection extends StatelessWidget {
  const _LegendSection({required this.title, required this.rows});

  final String title;
  final List<_LegendRowData> rows;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          for (final row in rows) _LegendItem(row: row),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.row});

  final _LegendRowData row;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: row.color,
              borderRadius: BorderRadius.circular(3),
              border: Border.all(color: Colors.black12),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${row.label}  ${row.range}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 10.5,
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

class _ToggleGroup extends StatelessWidget {
  const _ToggleGroup({
    required this.title,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.disabled = const [],
  });

  final String title;
  final List<_ControlOption> options;
  final List<int> selected;
  final List<int> disabled;
  final ValueChanged<int> onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: Colors.black54,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final option in options)
                _ToggleChip(
                  option: option,
                  selected: selected.contains(option.id),
                  disabled: disabled.contains(option.id),
                  onTap: () => onToggle(option.id),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({
    required this.option,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  final _ControlOption option;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = disabled
        ? Colors.black38
        : selected
        ? AppTheme.primary
        : Colors.black54;
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        width: 112,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          color: disabled
              ? Colors.black.withValues(alpha: 0.04)
              : selected
              ? AppTheme.primary.withValues(alpha: 0.10)
              : Colors.white.withValues(alpha: 0.65),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: disabled
                ? Colors.black12
                : selected
                ? AppTheme.primary.withValues(alpha: 0.55)
                : Colors.black12,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              option.label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              disabled ? option.disabledDetail ?? option.detail : option.detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: color.withValues(alpha: 0.72),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OpacityControl extends StatelessWidget {
  const _OpacityControl({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Layer Opacity',
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.black54,
                ),
              ),
              Text(
                '$value%',
                style: GoogleFonts.inter(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w900,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
            ),
            child: Slider(
              value: value.toDouble(),
              min: 0,
              max: 100,
              divisions: 10,
              activeColor: AppTheme.primary,
              inactiveColor: Colors.black12,
              onChanged: (next) => onChanged(next.round()),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendRowData {
  const _LegendRowData(this.label, this.range, this.color);

  final String label;
  final String range;
  final Color color;
}

class _ControlOption {
  const _ControlOption(this.id, this.label, this.detail, {this.disabledDetail});

  final int id;
  final String label;
  final String detail;
  final String? disabledDetail;
}

const _rainfallRows = [
  _LegendRowData('No / Light', '0-1 mm/h', Color(0xFF88C6FF)),
  _LegendRowData('Light', '1-2 mm/h', Color(0xFF3B82F6)),
  _LegendRowData('Moderate', '2-10 mm/h', Color(0xFF22C55E)),
  _LegendRowData('Heavy', '10-30 mm/h', Color(0xFFFACC15)),
  _LegendRowData('Intense', '30-50 mm/h', Color(0xFFF97316)),
  _LegendRowData('Torrential', '> 50 mm/h', Color(0xFFEF4444)),
];

const _floodRows = [
  _LegendRowData('Low Hazard', 'Var 1', Color(0xFF9FCFE6)),
  _LegendRowData('Medium Hazard', 'Var 2', Color(0xFF4F97C6)),
  _LegendRowData('High Hazard', 'Var 3', Color(0xFF0B5F8E)),
];

const _landslideRows = [
  _LegendRowData('Low Hazard', 'LH 1', Color(0xFF86EFAC)),
  _LegendRowData('Medium Hazard', 'LH 2', Color(0xFF22C55E)),
  _LegendRowData('High Hazard', 'LH 3', Color(0xFF15803D)),
];

const _stormSurgeRows = [
  _LegendRowData('Low Hazard', 'HAZ 1', Color(0xFFFACC15)),
  _LegendRowData('Medium Hazard', 'HAZ 2', Color(0xFFFB923C)),
  _LegendRowData('High Hazard', 'HAZ 3', Color(0xFFEF4444)),
];

const _typhoonRows = [
  _LegendRowData('TD / LPA', '< 62 km/h', Color(0xFF2563EB)),
  _LegendRowData('Tropical Storm', '62-88 km/h', Color(0xFF10B981)),
  _LegendRowData('STS / TY', '89-184 km/h', Color(0xFFEF4444)),
  _LegendRowData('Super Typhoon', '>= 185 km/h', Color(0xFF4C1D95)),
];

const _earthquakeRows = [
  _LegendRowData('Deep', '> 70 km depth', Color(0xFF3B82F6)),
  _LegendRowData('Intermediate', '30-70 km depth', Color(0xFFF59E0B)),
  _LegendRowData('Shallow', '< 30 km depth', Color(0xFFEF4444)),
  _LegendRowData('Heat Core', 'High density', Color(0xFFB2182B)),
];

const _aqiRows = [
  _LegendRowData('Good', '0-50 AQI', Color(0xFF00E400)),
  _LegendRowData('Moderate', '51-100 AQI', Color(0xFFFFFF00)),
  _LegendRowData('USG', '101-150 AQI', Color(0xFFFF7E00)),
  _LegendRowData('Unhealthy', '151-200 AQI', Color(0xFFFF0000)),
  _LegendRowData('Very Unhealthy', '201-300 AQI', Color(0xFF8F3F97)),
  _LegendRowData('Hazardous', '301+ AQI', Color(0xFF7E0023)),
];

const _floodOptions = [
  _ControlOption(5, '5-Year', 'Frequent scenario'),
  _ControlOption(25, '25-Year', 'Moderate period'),
  _ControlOption(
    100,
    '100-Year',
    'Rare period',
    disabledDetail: 'No Laoag file',
  ),
];

const _stormSurgeOptions = [
  _ControlOption(1, 'Up to 2 m', 'Advisory 1'),
  _ControlOption(2, 'Up to 3 m', 'Advisory 2'),
  _ControlOption(3, 'Up to 4 m', 'Advisory 3'),
  _ControlOption(4, 'Above 4 m', 'Advisory 4'),
];
