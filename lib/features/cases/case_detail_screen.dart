import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:konektizen/features/cases/case_model.dart';
import 'package:konektizen/features/cases/cases_provider.dart';
import 'package:konektizen/features/cases/widgets/case_detail_info.dart';
import 'package:konektizen/features/cases/widgets/case_detail_timeline.dart';
import 'package:konektizen/features/cases/widgets/case_evidence_viewer.dart';
import 'package:konektizen/features/cases/widgets/case_status_header.dart';
import 'package:konektizen/features/cases/widgets/ai_analytics_card.dart';

class CaseDetailScreen extends ConsumerWidget {
  final String caseId;

  const CaseDetailScreen({super.key, required this.caseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cases = ref.watch(caseListProvider);

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
        submittedAt: DateTime.now(),
      ),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/my-cases');
            }
          },
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CaseStatusHeader(item: item),
              const SizedBox(height: 16),
              CaseDetailTimeline(item: item),
              const SizedBox(height: 16),
              CaseDetailInfo(item: item),
              AiAnalyticsCard(item: item),
              if (item.mediaUrls.isNotEmpty) ...[
                const SizedBox(height: 16),
                CaseEvidenceViewer(item: item),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
