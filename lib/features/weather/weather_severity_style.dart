import 'package:flutter/material.dart';
import 'package:konektizen/theme/app_theme.dart';

class WeatherSeverityStyle {
  const WeatherSeverityStyle(this.label, this.color, this.icon);

  final String label;
  final Color color;
  final IconData icon;
}

class WeatherSeverityBadge extends StatelessWidget {
  const WeatherSeverityBadge({super.key, required this.style});

  final WeatherSeverityStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        style.label,
        style: TextStyle(
          color: style.color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class WeatherSeverityIcon extends StatelessWidget {
  const WeatherSeverityIcon({super.key, required this.style});

  final WeatherSeverityStyle style;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: style.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(style.icon, color: style.color),
    );
  }
}

WeatherSeverityStyle weatherSeverityStyle(String level) {
  switch (level.toLowerCase()) {
    case 'critical':
      return const WeatherSeverityStyle(
        'CRITICAL',
        AppTheme.error,
        Icons.warning,
      );
    case 'high':
      return const WeatherSeverityStyle(
        'HIGH',
        AppTheme.alert,
        Icons.thunderstorm,
      );
    case 'moderate':
      return const WeatherSeverityStyle(
        'MODERATE',
        Color(0xFFB7791F),
        Icons.cloud,
      );
    default:
      return const WeatherSeverityStyle(
        'LOW',
        AppTheme.success,
        Icons.check_circle,
      );
  }
}
