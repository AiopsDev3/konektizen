import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CityAdvisoryMetrics extends StatelessWidget {
  const CityAdvisoryMetrics({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildMetricColumn(
            icon: Icons.warning_amber_rounded,
            iconColor: const Color(0xFFEF4444),
            value: '3',
            label: 'Active\nAdvisories',
          ),
          _buildDivider(),
          _buildMetricColumn(
            icon: Icons.campaign_outlined,
            iconColor: const Color(0xFF16A34A),
            value: '12',
            label: 'City\nUpdates',
          ),
          _buildDivider(),
          _buildMetricColumn(
            icon: Icons.article_outlined,
            iconColor: const Color(0xFFEA580C),
            value: '8',
            label: 'News\nUpdates',
          ),
          _buildDivider(),
          _buildMetricColumn(
            icon: Icons.verified_user_outlined,
            iconColor: const Color(0xFF0D9488),
            value: '4',
            label: 'Verified\nSources',
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 36,
      color: const Color(0xFFE2E8F0),
    );
  }

  Widget _buildMetricColumn({
    required IconData icon,
    required Color iconColor,
    required String value,
    required String label,
  }) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 18),
              const SizedBox(width: 4),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
