import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:konektizen/core/localization/app_localizations.dart';
import 'package:konektizen/features/cases/cases_provider.dart';
import 'package:konektizen/features/cases/case_model.dart';

class HomeActiveReports extends ConsumerWidget {
  const HomeActiveReports({super.key});

  IconData _getCatIcon(String c) {
    final l = c.toLowerCase();
    if (l == 'garbage' || l == 'basura') return Icons.delete_outline_rounded;
    if (l == 'road' || l == 'kalsada') return Icons.construction_rounded;
    if (l == 'flood' || l == 'pagbaha' || l == 'layus') return Icons.water_drop_outlined;
    if (l.contains('light')) return Icons.lightbulb_outline_rounded;
    if (l == 'traffic' || l == 'trapiko') return Icons.traffic_outlined;
    return Icons.assignment_outlined;
  }

  Color _getCatColor(String c) {
    final l = c.toLowerCase();
    if (l == 'garbage' || l == 'basura') return const Color(0xFF64748B);
    if (l == 'road' || l == 'kalsada') return const Color(0xFFD97706);
    if (l == 'flood' || l == 'pagbaha' || l == 'layus') return const Color(0xFF0284C7);
    if (l.contains('light')) return const Color(0xFFEAB308);
    if (l == 'traffic' || l == 'trapiko') return const Color(0xFFEA580C);
    return const Color(0xFF16A34A);
  }

  Color _getCatBg(String c) {
    final l = c.toLowerCase();
    if (l == 'garbage' || l == 'basura') return const Color(0xFFF1F5F9);
    if (l == 'road' || l == 'kalsada') return const Color(0xFFFEF3C7);
    if (l == 'flood' || l == 'pagbaha' || l == 'layus') return const Color(0xFFE0F2FE);
    if (l.contains('light')) return const Color(0xFFFEF9C3);
    if (l == 'traffic' || l == 'trapiko') return const Color(0xFFFFEDD5);
    return const Color(0xFFF0FDF4);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allCases = ref.watch(caseListProvider);
    final t = ref.watch(appStringsProvider);
    final activeCases = allCases.where((c) => c.status != CaseStatus.resolved).toList();
    final recentCases = activeCases.take(3).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t.text('home.activeReports'),
                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
              ),
              TextButton(
                onPressed: () => context.push('/my-cases'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  children: [
                    Text(t.text('home.viewAll'), style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF166534))),
                    const SizedBox(width: 2),
                    const Icon(Icons.chevron_right, color: Color(0xFF166534), size: 14),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recentCases.isEmpty)
            _buildEmptyState(context, t)
          else
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: Column(
                children: List.generate(recentCases.length * 2 - 1, (index) {
                  if (index.isOdd) return const Divider(height: 1, thickness: 1, color: Color(0xFFF1F5F9), indent: 64);
                  final item = recentCases[index ~/ 2];
                  return InkWell(
                    onTap: () => context.push('/my-cases/detail/${item.id}'),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: _getCatBg(item.category), shape: BoxShape.circle),
                            child: Icon(_getCatIcon(item.category), color: _getCatColor(item.category), size: 20),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(item.category, style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B))),
                                const SizedBox(height: 2),
                                Text(item.description, style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w400, color: const Color(0xFF64748B), height: 1.3), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: item.statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                            child: Text(item.statusLabel.toUpperCase(), style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: item.statusColor)),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppStrings t) {
    return Container(
      padding: const EdgeInsets.all(24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.01), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
            child: const Icon(Icons.assignment_turned_in_outlined, size: 32, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          Text(t.text('home.noActiveReports'), style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: const Color(0xFF64748B))),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () => context.push('/my-cases'),
            style: TextButton.styleFrom(foregroundColor: const Color(0xFF166534), textStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
            child: Text(t.text('home.checkHistory')),
          ),
        ],
      ),
    );
  }
}
