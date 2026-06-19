import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:konektizen/core/localization/app_localizations.dart';
import 'package:konektizen/features/report/report_provider.dart';
import 'package:konektizen/features/report/widgets/report_category_picker.dart';
import 'package:konektizen/theme/app_theme.dart';

class ReportCategoryScreen extends ConsumerStatefulWidget {
  final String description;

  const ReportCategoryScreen({super.key, required this.description});

  @override
  ConsumerState<ReportCategoryScreen> createState() => _ReportCategoryScreenState();
}

class _ReportCategoryScreenState extends ConsumerState<ReportCategoryScreen> {
  
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(reportDraftProvider.notifier).analyzeDraft());
  }

  String _getCategoryDisplayName(String category, AppStrings strings) {
    switch (category.toUpperCase()) {
      case 'BASURA':
      case 'SANITATION':
        return 'Sanitation (${strings.text('home.category.garbage')})';
      case 'KALSADA':
      case 'ROADS & INFRA':
        return 'Roads & Infra (${strings.text('home.category.road')})';
      case 'PAGBAHA':
      case 'FLOODING':
        return 'Flooding (${strings.text('home.category.flood')})';
      case 'ILAW_SA_KALYE':
      case 'UTILITIES':
        return 'Utilities (${strings.text('home.category.streetLight')})';
      case 'TRAPIKO':
      case 'TRAFFIC':
        return 'Traffic (${strings.text('home.category.traffic')})';
      case 'IBA_PA':
      case 'PUBLIC CONCERN':
        return 'Public Concern (${strings.text('home.category.report')})';
      default:
        return category;
    }
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toUpperCase()) {
      case 'BASURA':
      case 'SANITATION':
        return Icons.delete_outline_rounded;
      case 'KALSADA':
      case 'ROADS & INFRA':
        return Icons.edit_road_rounded;
      case 'PAGBAHA':
      case 'FLOODING':
        return Icons.water_drop_rounded;
      case 'ILAW_SA_KALYE':
      case 'UTILITIES':
        return Icons.lightbulb_outline_rounded;
      case 'TRAPIKO':
      case 'TRAFFIC':
        return Icons.traffic_rounded;
      default:
        return Icons.assignment_add;
    }
  }

  void _showCategoryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const ReportCategoryPicker(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(reportDraftProvider);
    final strings = ref.watch(appStringsProvider);

    // 1. Loading State
    if (draft.isAnalyzing) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(strings.text('report.analyzing'), style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E293B),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                color: AppTheme.primary,
                strokeWidth: 3,
              ),
              const SizedBox(height: 24),
              Text(
                strings.text('report.analyzingSubtitle'),
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                strings.text('report.pleaseWait'),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Error State
    if (draft.analysisError != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(strings.text('report.error'), style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E293B),
        ),
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.error_outline_rounded, size: 64, color: AppTheme.error),
              const SizedBox(height: 24),
              Text(
                draft.analysisError!,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF334155),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(reportDraftProvider.notifier).analyzeDraft();
                },
                icon: const Icon(Icons.refresh_rounded),
                label: Text(strings.text('report.tryAgain')),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => context.pop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 48),
                  side: const BorderSide(color: Color(0xFFCBD5E1)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  strings.text('report.back'),
                  style: GoogleFonts.inter(
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final analysis = draft.aiAnalysis;
    if (analysis == null) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final displayCategoryName = _getCategoryDisplayName(analysis.category, strings);
    final displayCategoryIcon = _getCategoryIcon(analysis.category);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          strings.text('report.title'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Linear progress indicator at 50%
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: 0.50, 
                    color: AppTheme.primary,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                    minHeight: 5,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Icon(Icons.auto_awesome_rounded, color: AppTheme.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  strings.text('report.aiComplete'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              strings.text('report.aiGuess'),
              style: GoogleFonts.inter(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 16),
            
            // Category Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: Row(
                children: [
                   Container(
                     padding: const EdgeInsets.all(12),
                     decoration: BoxDecoration(
                       color: AppTheme.primary.withValues(alpha: 0.08),
                       shape: BoxShape.circle,
                     ),
                     child: Icon(displayCategoryIcon, size: 28, color: AppTheme.primary),
                   ),
                   const SizedBox(width: 16),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           displayCategoryName,
                           style: GoogleFonts.inter(
                             fontWeight: FontWeight.w800,
                             fontSize: 16,
                             color: const Color(0xFF1E293B),
                           ),
                         ),
                         const SizedBox(height: 4),
                         Row(
                           children: [
                             Text(
                               '${strings.text('report.urgency')}: ',
                               style: GoogleFonts.inter(
                                 fontSize: 13,
                                 fontWeight: FontWeight.w500,
                                 color: const Color(0xFF64748B),
                               ),
                             ),
                             Text(
                               analysis.urgencyLabel,
                               style: GoogleFonts.inter(
                                 fontSize: 13,
                                 color: (analysis.urgencyLabel.toLowerCase() == 'high') ? AppTheme.error : AppTheme.warning,
                                 fontWeight: FontWeight.w700,
                               ),
                             ),
                           ],
                         ),
                         if (draft.isCityDetected) ...[
                           const SizedBox(height: 4),
                           Row(
                             children: [
                               Icon(Icons.location_on_rounded, size: 13, color: AppTheme.primary),
                               const SizedBox(width: 3),
                               Text(
                                 '${strings.text('report.detectedCity')}: ${draft.city}',
                                 style: GoogleFonts.inter(
                                   fontSize: 12, 
                                   color: AppTheme.primary, 
                                   fontWeight: FontWeight.w700,
                                 ),
                               ),
                             ],
                           ),
                         ],
                       ],
                     ),
                   ),
                   Icon(Icons.check_circle_rounded, color: AppTheme.primary, size: 24),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              strings.text('report.isCorrect'),
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF1E293B),
              ),
            ),
            const Spacer(),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showCategoryPicker(context),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      side: const BorderSide(color: Color(0xFFCBD5E1)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(
                      strings.text('report.changeCategory'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF475569),
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => context.push('/report/evidence'),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: Text(
                      strings.text('report.confirm'),
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
