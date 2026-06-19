import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:konektizen/core/localization/app_localizations.dart';
import 'package:konektizen/features/report/report_provider.dart';
import 'package:konektizen/theme/app_theme.dart';

class ReportCategoryPicker extends ConsumerWidget {
  const ReportCategoryPicker({super.key});

  IconData _getCategoryIcon(String category) {
    switch (category.toUpperCase()) {
      case 'BASURA':
        return Icons.delete_outline_rounded;
      case 'KALSADA':
        return Icons.edit_road_rounded;
      case 'PAGBAHA':
        return Icons.water_drop_rounded;
      case 'ILAW_SA_KALYE':
        return Icons.lightbulb_outline_rounded;
      case 'TRAPIKO':
        return Icons.traffic_rounded;
      default:
        return Icons.assignment_add;
    }
  }

  String _getLocalizedCategoryName(String category, AppStrings strings) {
    switch (category.toUpperCase()) {
      case 'BASURA':
        return 'Sanitation (${strings.text('home.category.garbage')})';
      case 'KALSADA':
        return 'Roads & Infra (${strings.text('home.category.road')})';
      case 'PAGBAHA':
        return 'Flooding (${strings.text('home.category.flood')})';
      case 'ILAW_SA_KALYE':
        return 'Utilities (${strings.text('home.category.streetLight')})';
      case 'TRAPIKO':
        return 'Traffic (${strings.text('home.category.traffic')})';
      default:
        return 'Public Concern (${strings.text('home.category.report')})';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);
    final categoryOptions = ['BASURA', 'KALSADA', 'PAGBAHA', 'ILAW_SA_KALYE', 'TRAPIKO', 'IBA_PA'];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              strings.text('report.selectCategory'),
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 16),
            ...categoryOptions.map((cat) {
              final isSelected = ref.read(reportDraftProvider).category == cat;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.primary.withValues(alpha: 0.06) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isSelected ? AppTheme.primary.withValues(alpha: 0.1) : const Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getCategoryIcon(cat), 
                      color: isSelected ? AppTheme.primary : const Color(0xFF475569),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    _getLocalizedCategoryName(cat, strings),
                    style: GoogleFonts.inter(
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 14.5,
                      color: isSelected ? AppTheme.primary : const Color(0xFF1E293B),
                    ),
                  ),
                  trailing: isSelected 
                      ? Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 22)
                      : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    ref.read(reportDraftProvider.notifier).updateCategory(cat);
                    ref.read(reportDraftProvider.notifier).analyzeDraft();
                    context.pop();
                  },
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
