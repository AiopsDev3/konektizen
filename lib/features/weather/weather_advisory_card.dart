import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:konektizen/features/weather/weather_advisory.dart';
import 'package:konektizen/features/weather/weather_severity_style.dart';
import 'package:konektizen/theme/app_theme.dart';

class WeatherAdvisoryCard extends StatelessWidget {
  const WeatherAdvisoryCard({super.key, required this.advisory});

  final WeatherAdvisory advisory;

  @override
  Widget build(BuildContext context) {
    final severity = weatherSeverityStyle(advisory.severityLevel);
    final issued = DateFormat('MMM d, yyyy • h:mm a').format(advisory.issuedAt);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: severity.color.withValues(alpha: 0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              WeatherSeverityIcon(style: severity),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      advisory.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1D2B20),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      advisory.locationText ?? 'Monitored area',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              WeatherSeverityBadge(style: severity),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            advisory.summary,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF344238),
              height: 1.45,
            ),
          ),
          if (advisory.preparedness != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                advisory.preparedness!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.primary,
                  height: 1.4,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: Colors.black45),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  issued,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ),
              Text(
                advisory.sourceName ?? 'C3 Weather',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.black45,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
