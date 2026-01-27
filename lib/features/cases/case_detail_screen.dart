import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:konektizen/core/api/api_service.dart';
import 'package:konektizen/features/cases/case_model.dart';
import 'package:konektizen/features/cases/cases_provider.dart';
import 'package:konektizen/theme/app_theme.dart';
import 'package:intl/intl.dart';

class CaseDetailScreen extends ConsumerWidget {
  final String caseId;

  const CaseDetailScreen({super.key, required this.caseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cases = ref.watch(caseListProvider);
    
    // Find the case by ID
    final item = cases.firstWhere(
      (element) => element.id == caseId,
      orElse: () => CaseModel(
        id: caseId,
        title: 'Unknown',
        location: 'Unknown',
        date: DateTime.now(),
        status: CaseStatus.submitted,
        category: 'Unknown',
        description: '',
      ),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Case Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildStatusHeader(context, item),
            _buildTimeline(context, item),
            _buildDetails(context, ref, item),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader(BuildContext context, CaseModel item) {
    return Container(
      padding: const EdgeInsets.all(24),
      color: Colors.white,
      child: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: item.statusColor.withOpacity(0.1),
            child: Icon(Icons.assignment, size: 32, color: item.statusColor),
          ),
          const SizedBox(height: 16),
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
             decoration: BoxDecoration(
               color: item.statusColor,
               borderRadius: BorderRadius.circular(16),
             ),
             child: Text(
               item.statusLabel.toUpperCase(),
               style: const TextStyle(
                 color: Colors.white,
                 fontWeight: FontWeight.bold,
                 fontSize: 12,
               ),
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildTimeline(BuildContext context, CaseModel item) {
    // Mock timeline steps
    final steps = [
      {'label': 'Submitted', 'date': item.date, 'completed': true},
      {'label': 'Validated', 'date': null, 'completed': item.status != CaseStatus.submitted},
      {'label': 'Assigned', 'date': null, 'completed': item.status == CaseStatus.inProgress || item.status == CaseStatus.resolved},
      {'label': 'Resolved', 'date': null, 'completed': item.status == CaseStatus.resolved},
    ];

    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Timeline',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: steps.length,
            itemBuilder: (context, index) {
              final step = steps[index];
              final isCompleted = step['completed'] as bool;
              final isLast = index == steps.length - 1;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Icon(
                          isCompleted ? Icons.check_circle : Icons.circle_outlined,
                          color: isCompleted ? AppTheme.primary : Colors.grey[300],
                          size: 20,
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: isCompleted ? AppTheme.primary : Colors.grey[300],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step['label'] as String,
                              style: TextStyle(
                                fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                                color: isCompleted ? Colors.black87 : Colors.grey[500],
                              ),
                            ),
                            if (step['date'] != null)
                               Text(
                                DateFormat('MMM d, h:mm a').format(step['date'] as DateTime),
                                style: TextStyle(color: Colors.grey[500], fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetails(BuildContext context, WidgetRef ref, CaseModel item) {
    return Container(
       margin: const EdgeInsets.only(top: 16),
       padding: const EdgeInsets.all(16),
       color: Colors.white,
       width: double.infinity,
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Text(
             'Details',
             style: Theme.of(context).textTheme.titleMedium?.copyWith(
               fontWeight: FontWeight.bold,
             ),
           ),
           const SizedBox(height: 16),
           _detailRow('Case ID', item.id),
           _detailRow('Category', item.category),
           _detailRow('Location', item.location),
           _detailRow('Severity', item.severity.name.toUpperCase()),
           const SizedBox(height: 32),
           if (item.status == CaseStatus.submitted)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  // Show confirmation dialog
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Bawiin ang Ulat?'),
                      content: const Text('Sigurado ka ba na gusto mong bawiin ang ulat na ito?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Hindi'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          child: const Text('Oo, Bawiin'),
                        ),
                      ],
                    ),
                  );

                  if (confirmed == true && context.mounted) {
                    // Show loading
                    showDialog(
                      context: context,
                      barrierDismissible: false,
                      builder: (c) => const Center(child: CircularProgressIndicator()),
                    );

                    try {
                      // Actually delete the case from backend
                      final success = await apiService.deleteCase(item.id);
                      
                      if (context.mounted) {
                        Navigator.of(context).pop(); // Dismiss loading
                        
                        if (success) {
                          // Show success message
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Binawi ang ulat'),
                              duration: Duration(seconds: 2),
                              backgroundColor: Colors.green,
                            ),
                          );
                          
                          // Navigate back
                          context.pop();
                          
                          // Refresh the cases list
                          ref.read(caseListProvider.notifier).loadCases();
                        } else {
                          // Show error message
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Hindi mabawi ang ulat. Subukan muli.'),
                              duration: Duration(seconds: 3),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.of(context).pop(); // Dismiss loading
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: ${e.toString()}'),
                            duration: const Duration(seconds: 3),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  }
                },
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                label: const Text('Bawiin ang Ulat', style: TextStyle(color: Colors.red)),
              ),
            ),
         ],
       ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
