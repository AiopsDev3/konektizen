import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:konektizen/features/report/report_provider.dart';
import 'package:konektizen/theme/app_theme.dart';

class ReportDescriptionScreen extends ConsumerStatefulWidget {
  final String? initialQuery;
  final String? initialCategory;

  const ReportDescriptionScreen({
    super.key, 
    this.initialQuery, 
    this.initialCategory
  });

  @override
  ConsumerState<ReportDescriptionScreen> createState() => _ReportDescriptionScreenState();
}

class _ReportDescriptionScreenState extends ConsumerState<ReportDescriptionScreen> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    // Initialize controller with current state description or initial query
    final currentDesc = ref.read(reportDraftProvider).description;
    _controller = TextEditingController(text: currentDesc.isNotEmpty ? currentDesc : widget.initialQuery);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // If initial query exists and draft is empty, update draft
      if (widget.initialQuery != null && currentDesc.isEmpty) {
         ref.read(reportDraftProvider.notifier).updateDescription(widget.initialQuery!);
      }
      // Set category if passed
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

  String _getPlaceholderText(String? category) {
    switch (category) {
      case 'BASURA':
        return 'Halimbawa: "May tambak ng basura sa gilid ng kalsada malapit sa barangay hall."';
      case 'KALSADA':
        return 'Halimbawa: "May malaking butas sa kalsada sa Rizal Street na nagiging sanhi ng trapiko."';
      case 'PAGBAHA':
        return 'Halimbawa: "May mataas na baha sa Quezon City na hindi madaanan ng mga sasakyan."';
      case 'ILAW_SA_KALYE':
        return 'Halimbawa: "Patay ang ilaw sa kalye sa Aurora Boulevard kaya delikado sa gabi."';
      case 'TRAPIKO':
        return 'Halimbawa: "Matinding trapiko sa EDSA dahil sa sirang traffic light."';
      default:
        return 'Halimbawa: "Ilarawan ang problema sa inyong lugar at kung saan ito nangyari."';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch current state
    final draft = ref.watch(reportDraftProvider);
    
    // If draft was cleared externally (e.g. after submit), reset controller
    if (draft.description.isEmpty && _controller.text.isNotEmpty) {
      _controller.text = '';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mag-ulat ng Problema'),
        leading: IconButton(
          icon: const Icon(Icons.close),
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
            child: const Text('Kanselahin', style: TextStyle(color: AppTheme.tertiary, fontWeight: FontWeight.bold)),
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
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const LinearProgressIndicator(value: 0.25, backgroundColor: AppTheme.tertiary),
                      const SizedBox(height: 24),
                      Text(
                        'Ilarawan ang problema',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sabihin sa amin ang nangyari. Tutulungan ka ng AI na ikategorya ito.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: const Color(0xFF424242)),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: _controller,
                        maxLines: 5,
                        onChanged: (value) {
                          ref.read(reportDraftProvider.notifier).updateDescription(value);
                        },
                        decoration: InputDecoration(
                          hintText: _getPlaceholderText(draft.category),
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          IconButton.filledTonal(
                            onPressed: () {
                              // TODO: Voice Input
                            },
                            icon: const Icon(Icons.mic),
                          ),
                        ],
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          if (_controller.text.isNotEmpty) {
                            ref.read(reportDraftProvider.notifier).updateDescription(_controller.text);
                            context.push('/report/category'); // No query params needed
                          }
                        },
                        child: const Text('Susunod'),
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
