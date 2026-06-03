import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:konektizen/core/localization/app_localizations.dart';
import 'package:konektizen/features/cases/cases_provider.dart';
import 'package:konektizen/features/cases/case_model.dart';
import 'package:konektizen/theme/app_theme.dart';

class HomeActiveReports extends ConsumerWidget {
  const HomeActiveReports({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allCases = ref.watch(caseListProvider);
    final t = ref.watch(appStringsProvider);
    final activeCases = allCases
        .where((c) => c.status != CaseStatus.resolved)
        .toList();
    final recentCases = activeCases.take(3).toList();

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                t.text('home.activeReports'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              if (activeCases.isNotEmpty)
                TextButton(
                  onPressed: () {
                    StatefulNavigationShell.of(context).goBranch(1);
                  },
                  child: Text(
                    t.text('home.viewAll'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (recentCases.isEmpty)
            _buildEmptyState(context, t)
          else
            Column(
              children: recentCases
                  .map((item) => _buildCaseItem(context, item))
                  .toList(),
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
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(
            Icons.assignment_turned_in_outlined,
            size: 48,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 12),
          Text(
            t.text('home.noActiveReports'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
          TextButton(
            onPressed: () {
              StatefulNavigationShell.of(context).goBranch(1);
            },
            child: Text(t.text('home.checkHistory')),
          ),
        ],
      ),
    );
  }

  Widget _buildCaseItem(BuildContext context, dynamic item) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: () {
          context.push('/my-cases/detail/${item.id}');
        },
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.description_outlined,
            color: AppTheme.primary,
          ),
        ),
        title: Text(
          item.category,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          item.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStatusColor(item.status).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            item.statusLabel.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _getStatusColor(item.status),
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(dynamic status) {
    switch (status) {
      case CaseStatus.submitted:
        return Colors.blue;
      case CaseStatus.validated:
        return Colors.orange;
      case CaseStatus.inProgress:
        return Colors.purple;
      case CaseStatus.resolved:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
