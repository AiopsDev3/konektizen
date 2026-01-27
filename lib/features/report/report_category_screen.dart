import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:konektizen/features/report/report_provider.dart';
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
    // Trigger analysis on load
    Future.microtask(() => ref.read(reportDraftProvider.notifier).analyzeDraft());
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(reportDraftProvider);

    // Show loading state
    if (draft.isAnalyzing) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Sinusuri...'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                'Sinusuri ng AI ang iyong ulat...',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Sandali lang po.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF424242),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show error state
    if (draft.analysisError != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('May Error'),
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.error_outline, size: 64, color: AppTheme.error),
              const SizedBox(height: 24),
              Text(
                draft.analysisError!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(reportDraftProvider.notifier).analyzeDraft();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Subukan Muli'),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () {
                  context.pop();
                },
                child: const Text('Bumalik'),
              ),
            ],
          ),
        ),
      );
    }

    final analysis = draft.aiAnalysis;

    if (analysis == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }


    return Scaffold(
      appBar: AppBar(
        title: const Text('Categorization'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LinearProgressIndicator(value: 0.50, backgroundColor: AppTheme.tertiary),
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppTheme.primary),
                const SizedBox(width: 8),
                Text(
                  'AI Analysis Complete',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Batay sa iyong paglalarawan, ito ay mukhang:',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primary, width: 2),
              ),
              child: Row(
                children: [
                   Icon(analysis.icon, size: 32, color: AppTheme.primary),
                   const SizedBox(width: 16),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           analysis.category,
                           style: Theme.of(context).textTheme.titleLarge?.copyWith(
                             fontWeight: FontWeight.bold,
                           ),
                         ),
                         Text(
                           'Urgency: ${analysis.urgencyLabel}',
                           style: TextStyle(
                            color: (analysis.urgencyLabel == 'High') ? AppTheme.error : AppTheme.warning,
                            fontWeight: FontWeight.w600,
                           ),
                         ),
                         if (draft.isCityDetected)
                           Padding(
                             padding: const EdgeInsets.only(top: 4.0),
                             child: Row(
                               children: [
                                 const Icon(Icons.location_on, size: 14, color: AppTheme.primary),
                                 Text(
                                   ' Detected: ${draft.city}',
                                   style: const TextStyle(fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.bold),
                                 ),
                               ],
                             ),
                           ),
                       ],
                     ),
                   ),
                   const Icon(Icons.check_circle, color: AppTheme.primary),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Is this correct?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                       _showCategoryPicker(context, ref);
                    },
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.grey),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                       padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Change Category', style: TextStyle(color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      context.push('/report/evidence');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.secondary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Confirm & Continue'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showCategoryPicker(BuildContext context, WidgetRef ref) {
    final categories = ['Roads & Infra', 'Flooding', 'Sanitation', 'Public Concern', 'Traffic', 'Utilities'];
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Select Category', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              ...categories.map((cat) => ListTile(
                title: Text(cat),
                onTap: () {
                  ref.read(reportDraftProvider.notifier).updateCategory(cat);
                  context.pop();
                },
              )),
            ],
          ),
        );
      },
    );
  }
}
