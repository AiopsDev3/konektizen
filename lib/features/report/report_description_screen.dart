import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:konektizen/core/localization/app_localizations.dart';
import 'package:konektizen/features/report/report_provider.dart';
import 'package:konektizen/features/report/widgets/report_voice_input_button.dart';
import 'package:konektizen/theme/app_theme.dart';

class ReportDescriptionScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  final String? initialCategory;

  const ReportDescriptionScreen({
    super.key, 
    this.initialQuery, 
    this.initialCategory,
  });

  @override
  ConsumerState<ReportDescriptionScreen> createState() => _ReportDescriptionScreenState();
}

class _ReportDescriptionScreenState extends ConsumerState<ReportDescriptionScreen> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    final currentDesc = ref.read(reportDraftProvider).description;
    _controller = TextEditingController(text: currentDesc.isNotEmpty ? currentDesc : widget.initialQuery);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialQuery != null && currentDesc.isEmpty) {
        ref.read(reportDraftProvider.notifier).updateDescription(widget.initialQuery!);
      }
      if (widget.initialCategory != null) {
        ref.read(reportDraftProvider.notifier).updateCategory(widget.initialCategory!);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _getPlaceholderText(String? category, AppStrings strings) {
    switch (category) {
      case 'BASURA':
        return strings.text('report.placeholderBasura');
      case 'KALSADA':
        return strings.text('report.placeholderKalsada');
      case 'PAGBAHA':
        return strings.text('report.placeholderPagbaha');
      case 'ILAW_SA_KALYE':
        return strings.text('report.placeholderIlaw');
      case 'TRAPIKO':
        return strings.text('report.placeholderTrapiko');
      default:
        return strings.text('report.placeholderDefault');
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(reportDraftProvider);
    final strings = ref.watch(appStringsProvider);
    
    if (draft.description.isEmpty && _controller.text.isNotEmpty) {
      _controller.text = '';
    }

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
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () {
            ref.read(reportDraftProvider.notifier).clearDraft();
            context.pop();
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(reportDraftProvider.notifier).clearDraft();
              context.pop();
            }, 
            child: Text(
              strings.text('report.cancel'),
              style: GoogleFonts.inter(
                color: const Color(0xFF64748B), 
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Linear step indicator
                      Row(
                        children: [
                          Expanded(
                            child: LinearProgressIndicator(
                              value: 0.25, 
                              color: AppTheme.primary,
                              backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                              minHeight: 5,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        strings.text('report.stepDescription'),
                        style: GoogleFonts.inter(
                          fontWeight: FontWeight.w800,
                          fontSize: 22,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        strings.text('report.stepDescriptionSubtitle'),
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF64748B),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Modern Card wrapper for TextField
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.02),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            )
                          ],
                        ),
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _controller,
                              maxLines: 6,
                              onChanged: (value) {
                                ref.read(reportDraftProvider.notifier).updateDescription(value);
                              },
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                color: const Color(0xFF1E293B),
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                hintText: _getPlaceholderText(draft.category, strings),
                                hintStyle: GoogleFonts.inter(
                                  color: const Color(0xFF94A3B8), 
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                ReportVoiceInputButton(
                                  onTextChanged: (text) {
                                    _controller.text = text;
                                    ref.read(reportDraftProvider.notifier).updateDescription(text);
                                  },
                                  tapToSpeakLabel: strings.text('report.tapToSpeak'),
                                  listeningLabel: strings.text('report.listening'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _controller.text.isNotEmpty
                            ? () {
                                ref.read(reportDraftProvider.notifier).updateDescription(_controller.text);
                                context.push('/report/category');
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          strings.text('report.next'),
                          style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }
      ),
    );
  }
}
