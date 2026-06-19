import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:konektizen/core/localization/app_localizations.dart';
import 'package:konektizen/features/cases/case_model.dart';
import 'package:konektizen/features/cases/cases_provider.dart';
import 'package:konektizen/theme/app_theme.dart';
import 'package:intl/intl.dart';

class MyCasesScreen extends ConsumerStatefulWidget {
  const MyCasesScreen({super.key});

  @override
  ConsumerState<MyCasesScreen> createState() => _MyCasesScreenState();
}

class _MyCasesScreenState extends ConsumerState<MyCasesScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(caseListProvider.notifier).loadCases());
  }

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
  Widget build(BuildContext context) {
    final allCases = ref.watch(caseListProvider);
    final t = ref.watch(appStringsProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(
            t.text('cases.title'),
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1E293B),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
          bottom: TabBar(
            tabs: [
              Tab(text: t.text('cases.active')),
              Tab(text: t.text('cases.inProgress')),
              Tab(text: t.text('cases.history')),
            ],
            labelColor: AppTheme.primary,
            unselectedLabelColor: const Color(0xFF64748B),
            indicatorColor: AppTheme.primary,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13),
            unselectedLabelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13),
          ),
        ),
        body: TabBarView(
          children: [
            _buildCaseList(context, ref, allCases, [CaseStatus.submitted, CaseStatus.validated], t),
            _buildCaseList(context, ref, allCases, [CaseStatus.inProgress], t),
            _buildCaseList(context, ref, allCases, [CaseStatus.resolved], t),
          ],
        ),
      ),
    );
  }

  Widget _buildCaseList(
    BuildContext context,
    WidgetRef ref,
    List<CaseModel> cases,
    List<CaseStatus> statuses,
    AppStrings t,
  ) {
    final filteredCases = cases.where((c) => statuses.contains(c.status)).toList();

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(caseListProvider.notifier).loadCases();
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: filteredCases.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: constraints.maxHeight * 0.8,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                                child: const Icon(Icons.folder_open_rounded, size: 40, color: Color(0xFF94A3B8)),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                t.text('cases.empty'),
                                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                      itemCount: filteredCases.length,
                      itemBuilder: (context, index) {
                        final item = filteredCases[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Stack(
                              children: [
                                Positioned(
                                  left: 0,
                                  top: 0,
                                  bottom: 0,
                                  width: 6,
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: item.statusColor,
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(20),
                                        bottomLeft: Radius.circular(20),
                                      ),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => context.push('/my-cases/detail/${item.id}'),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(20, 16, 14, 16),
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
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Text(
                                                    item.category,
                                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                                                  ),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                    decoration: BoxDecoration(
                                                      color: item.statusColor.withValues(alpha: 0.1),
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: Text(
                                                      item.statusLabel.toUpperCase(),
                                                      style: GoogleFonts.inter(fontSize: 8, fontWeight: FontWeight.w900, color: item.statusColor),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                item.description,
                                                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w500, color: const Color(0xFF475569), height: 1.35),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  const Icon(Icons.location_on_outlined, size: 12, color: Color(0xFF94A3B8)),
                                                  const SizedBox(width: 3),
                                                  Expanded(
                                                    child: Text(
                                                      item.location,
                                                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8)),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  const Icon(Icons.calendar_today_outlined, size: 10, color: Color(0xFF94A3B8)),
                                                  const SizedBox(width: 3),
                                                  Text(
                                                    DateFormat('MMM d, yyyy').format(item.date),
                                                    style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8)),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 20),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          );
        },
      ),
    );
  }
}
