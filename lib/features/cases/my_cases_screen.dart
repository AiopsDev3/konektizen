import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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
    // Load cases when screen appears
    Future.microtask(() => ref.read(caseListProvider.notifier).loadCases());
  }

  @override
  Widget build(BuildContext context) {
    final allCases = ref.watch(caseListProvider);
    final t = ref.watch(appStringsProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(t.text('cases.title')),
          bottom: TabBar(
            tabs: [
              Tab(text: t.text('cases.active')),
              Tab(text: t.text('cases.inProgress')),
              Tab(text: t.text('cases.history')),
            ],
            labelColor: AppTheme.tertiary,
            unselectedLabelColor: Colors.white70,
            indicatorColor: AppTheme.tertiary,
            indicatorSize: TabBarIndicatorSize.tab,
          ),
        ),
        body: TabBarView(
          children: [
            _buildCaseList(context, ref, allCases, [
              CaseStatus.submitted,
              CaseStatus.validated,
            ], t),
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
    final filteredCases = cases
        .where((c) => statuses.contains(c.status))
        .toList();

    return RefreshIndicator(
      onRefresh: () async {
        await ref.read(caseListProvider.notifier).loadCases();
      },
      child: filteredCases.isEmpty
          ? SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.7,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.folder_open,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        t.text('cases.empty'),
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredCases.length,
              itemBuilder: (context, index) {
                final item = filteredCases[index];
                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: InkWell(
                    onTap: () {
                      context.push('/my-cases/detail/${item.id}');
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: item.statusColor.withValues(
                                    alpha: 0.1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item.statusLabel,
                                  style: TextStyle(
                                    color: item.statusColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Text(
                                DateFormat('MMM d, yyyy').format(item.date),
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            item.title,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                item.location,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Divider(color: Colors.grey[200]),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'ID: ${item.id}',
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 12,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(
                                Icons.chevron_right,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
