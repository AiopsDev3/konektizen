import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:konektizen/features/cases/case_model.dart';
import 'package:konektizen/features/cases/widgets/category_illustrations.dart';

class CaseStatusHeader extends StatelessWidget {
  final CaseModel item;

  const CaseStatusHeader({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    Color mainColor;
    Color gradientStart;
    Color gradientEnd;
    IconData categoryIcon;

    switch (item.category.toUpperCase()) {
      case 'BASURA':
        mainColor = const Color(0xFF10B981);
        gradientStart = const Color(0xFFF0FDF4);
        gradientEnd = const Color(0xFFDCFCE7);
        categoryIcon = Icons.delete_outline_rounded;
        break;
      case 'KALSADA':
        mainColor = const Color(0xFFF59E0B);
        gradientStart = const Color(0xFFFFFBEB);
        gradientEnd = const Color(0xFFFEF3C7);
        categoryIcon = Icons.construction_rounded;
        break;
      case 'PAGBAHA':
        mainColor = const Color(0xFF0EA5E9);
        gradientStart = const Color(0xFFF0F9FF);
        gradientEnd = const Color(0xFFE0F2FE);
        categoryIcon = Icons.water_drop_rounded;
        break;
      case 'ILAW_SA_KALYE':
        mainColor = const Color(0xFF8B5CF6);
        gradientStart = const Color(0xFFFAF5FF);
        gradientEnd = const Color(0xFFF3E8FF);
        categoryIcon = Icons.lightbulb_outline_rounded;
        break;
      case 'TRAPIKO':
        mainColor = const Color(0xFFEF4444);
        gradientStart = const Color(0xFFFFF1F2);
        gradientEnd = const Color(0xFFFFE4E6);
        categoryIcon = Icons.traffic_rounded;
        break;
      default:
        mainColor = const Color(0xFF64748B);
        gradientStart = const Color(0xFFF8FAFC);
        gradientEnd = const Color(0xFFF1F5F9);
        categoryIcon = Icons.assignment_rounded;
    }

    return Container(
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [gradientStart, gradientEnd],
        ),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Stack(
        children: [
          // Left faded cloud decoration
          Positioned(
            left: 20,
            top: 40,
            child: Opacity(
              opacity: 0.15,
              child: Icon(Icons.cloud_rounded, size: 48, color: mainColor),
            ),
          ),
          Positioned(
            left: 45,
            top: 25,
            child: Opacity(
              opacity: 0.10,
              child: Icon(Icons.cloud_rounded, size: 36, color: mainColor),
            ),
          ),
          // Right illustration
          Positioned(
            right: 16,
            bottom: 16,
            child: CategoryIllustration(category: item.category),
          ),
          // Center content
          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon Avatar
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      )
                    ],
                  ),
                  child: Icon(
                    categoryIcon,
                    color: mainColor,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                // Title
                Text(
                  item.category.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 10),
                // Status Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4EA),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: Color(0xFF10B981),
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        item.statusLabel.toUpperCase(),
                        style: GoogleFonts.inter(
                          color: const Color(0xFF10B981),
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
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
