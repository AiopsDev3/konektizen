import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CitizenMapLayerSettingsSheet extends StatefulWidget {
  const CitizenMapLayerSettingsSheet({
    super.key,
    required this.opacityPercent,
    required this.floodReturnPeriods,
    required this.stormSurgeAdvisories,
    required this.showFlood,
    required this.showLandslide,
    required this.showStormSurge,
    required this.showBarangays,
    required this.onOpacityChanged,
    required this.onFloodReturnPeriodToggled,
    required this.onStormSurgeAdvisoryToggled,
    required this.onToggleFlood,
    required this.onToggleLandslide,
    required this.onToggleStormSurge,
    required this.onToggleBarangays,
  });

  final int opacityPercent;
  final List<int> floodReturnPeriods, stormSurgeAdvisories;
  final bool showFlood, showLandslide, showStormSurge, showBarangays;
  final ValueChanged<int> onOpacityChanged, onFloodReturnPeriodToggled, onStormSurgeAdvisoryToggled;
  final VoidCallback onToggleFlood, onToggleLandslide, onToggleStormSurge, onToggleBarangays;

  @override
  State<CitizenMapLayerSettingsSheet> createState() => _CitizenMapLayerSettingsSheetState();
}

class _CitizenMapLayerSettingsSheetState extends State<CitizenMapLayerSettingsSheet> {
  late int _opacity;
  late List<int> _floodPeriods, _stormAdvisories;
  late bool _floodActive, _landslideActive, _stormSurgeActive, _barangaysActive;

  @override
  void initState() {
    super.initState();
    _opacity = widget.opacityPercent;
    _floodPeriods = List<int>.from(widget.floodReturnPeriods);
    _stormAdvisories = List<int>.from(widget.stormSurgeAdvisories);
    _floodActive = widget.showFlood;
    _landslideActive = widget.showLandslide;
    _stormSurgeActive = widget.showStormSurge;
    _barangaysActive = widget.showBarangays;
  }

  @override
  Widget build(BuildContext context) {
    final hasOpacity = _floodActive || _landslideActive || _stormSurgeActive || _barangaysActive;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Layer Settings',
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLayerSettingCard(
                        title: 'Flood Susceptibility',
                        icon: Icons.water_drop_outlined,
                        isActive: _floodActive,
                        onToggle: (val) {
                          setState(() => _floodActive = val);
                          widget.onToggleFlood();
                        },
                        child: _floodActive
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 12),
                                  Text(
                                    'NOAH Flood Return Periods',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      _buildChip('5-Year', _floodPeriods.contains(5), () {
                                        setState(() => _floodPeriods.contains(5)
                                            ? _floodPeriods.remove(5)
                                            : _floodPeriods.add(5));
                                        widget.onFloodReturnPeriodToggled(5);
                                      }),
                                      const SizedBox(width: 8),
                                      _buildChip('25-Year', _floodPeriods.contains(25), () {
                                        setState(() => _floodPeriods.contains(25)
                                            ? _floodPeriods.remove(25)
                                            : _floodPeriods.add(25));
                                        widget.onFloodReturnPeriodToggled(25);
                                      }),
                                      const SizedBox(width: 8),
                                      _buildChip('100-Year (N/A)', false, () {}, disabled: true),
                                    ],
                                  ),
                                ],
                              )
                            : null,
                      ),
                      _buildLayerSettingCard(
                        title: 'Storm Surge Hazard',
                        icon: Icons.waves,
                        isActive: _stormSurgeActive,
                        onToggle: (val) {
                          setState(() => _stormSurgeActive = val);
                          widget.onToggleStormSurge();
                        },
                        child: _stormSurgeActive
                            ? Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 12),
                                  Text(
                                    'Storm Surge Height Bands',
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF475569),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        for (int i = 1; i <= 4; i++) ...[
                                          _buildChip('Advisory $i', _stormAdvisories.contains(i), () {
                                            setState(() => _stormAdvisories.contains(i)
                                                ? _stormAdvisories.remove(i)
                                                : _stormAdvisories.add(i));
                                            widget.onStormSurgeAdvisoryToggled(i);
                                          }),
                                          if (i < 4) const SizedBox(width: 8),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : null,
                      ),
                      _buildLayerSettingCard(
                        title: 'Landslide Hazard',
                        icon: Icons.landslide_outlined,
                        isActive: _landslideActive,
                        onToggle: (val) {
                          setState(() => _landslideActive = val);
                          widget.onToggleLandslide();
                        },
                      ),
                      _buildLayerSettingCard(
                        title: 'Barangay Boundaries',
                        icon: Icons.map_outlined,
                        isActive: _barangaysActive,
                        onToggle: (val) {
                          setState(() => _barangaysActive = val);
                          widget.onToggleBarangays();
                        },
                      ),
                      if (hasOpacity) ...[
                        const SizedBox(height: 12),
                        const Divider(color: Color(0xFFF1F5F9), thickness: 1.5),
                        const SizedBox(height: 12),
                        Text(
                          'Layer Opacity',
                          style: GoogleFonts.inter(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF475569),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 3,
                                  activeTrackColor: const Color(0xFF15803D),
                                  inactiveTrackColor: const Color(0xFFE2E8F0),
                                  thumbColor: const Color(0xFF15803D),
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                ),
                                child: Slider(
                                  value: _opacity.toDouble(),
                                  min: 0,
                                  max: 100,
                                  onChanged: (val) {
                                    setState(() => _opacity = val.round());
                                    widget.onOpacityChanged(val.round());
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '$_opacity%',
                              style: GoogleFonts.inter(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFF15803D),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        const SizedBox(height: 20),
                        Center(
                          child: Text(
                            'Enable a layer above to adjust its opacity.',
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLayerSettingCard({
    required String title,
    required IconData icon,
    required bool isActive,
    required ValueChanged<bool> onToggle,
    Widget? child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? const Color(0xFF86EFAC).withValues(alpha: 0.5) : const Color(0xFFE2E8F0),
          width: 1.5,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: const Color(0xFF15803D).withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 20,
                  color: isActive ? const Color(0xFF15803D) : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: isActive ? const Color(0xFF1E293B) : const Color(0xFF475569),
                  ),
                ),
              ),
              Switch.adaptive(
                value: isActive,
                activeThumbColor: const Color(0xFF15803D),
                activeTrackColor: const Color(0xFFDCFCE7),
                inactiveThumbColor: const Color(0xFF94A3B8),
                inactiveTrackColor: const Color(0xFFE2E8F0),
                onChanged: onToggle,
              ),
            ],
          ),
          if (child != null) child,
        ],
      ),
    );
  }

  Widget _buildChip(String label, bool active, VoidCallback onTap, {bool disabled = false}) {
    final color = disabled ? Colors.black38 : active ? const Color(0xFF15803D) : const Color(0xFF64748B);
    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: disabled ? const Color(0xFFF1F5F9) : active ? const Color(0xFFF0FDF4) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? const Color(0xFF86EFAC) : const Color(0xFFE2E8F0)),
        ),
        child: Text(label, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
      ),
    );
  }
}
