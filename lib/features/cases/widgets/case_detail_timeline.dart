import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:konektizen/features/cases/case_model.dart';

class CaseDetailTimeline extends StatelessWidget {
  final CaseModel item;

  const CaseDetailTimeline({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> steps = [];
    steps.add({
      'label': 'Submitted',
      'date': item.submittedAt ?? item.date,
      'completed': true,
    });
    steps.add({
      'label': 'Validated',
      'date': item.validatedAt,
      'completed': item.validatedAt != null || item.status != CaseStatus.submitted,
    });
    steps.add({
      'label': 'Assigned',
      'date': item.assignedAt,
      'completed': item.assignedAt != null ||
          item.status == CaseStatus.inProgress ||
          item.status == CaseStatus.resolved,
    });
    if (item.enrouteAt != null) {
      steps.add({
        'label': 'Responder En Route',
        'date': item.enrouteAt,
        'completed': true,
      });
    }
    if (item.arrivedAt != null) {
      steps.add({
        'label': 'Responder Arrived',
        'date': item.arrivedAt,
        'completed': true,
      });
    }
    steps.add({
      'label': 'Resolved',
      'date': item.resolvedAt,
      'completed': item.resolvedAt != null || item.status == CaseStatus.resolved,
    });

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFFE6F4EA),
                ),
                child: const Icon(
                  Icons.access_time_filled_rounded,
                  color: Color(0xFF10B981),
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Timeline',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: steps.length,
            itemBuilder: (context, index) {
              final step = steps[index];
              final isCompleted = step['completed'] as bool;
              final stepIdx = index + 1;
              final isLast = index == steps.length - 1;
              final date = step['date'] as DateTime?;

              // Determine if the line connecting to the next step should be green or grey
              final nextStepIsCompleted = !isLast && (steps[index + 1]['completed'] as bool);

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        if (isCompleted)
                          Container(
                            width: 24,
                            height: 24,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF10B981),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.check_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                            ),
                          )
                        else
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              border: Border.all(
                                color: const Color(0xFFCBD5E1),
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$stepIdx',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ),
                          ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2.5,
                              color: nextStepIsCompleted
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFE2E8F0),
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
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: isCompleted ? FontWeight.w800 : FontWeight.w600,
                                color: isCompleted ? const Color(0xFF1E293B) : const Color(0xFF94A3B8),
                              ),
                            ),
                            if (date != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                DateFormat('MMM d, yyyy • h:mm a').format(date),
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
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
}
