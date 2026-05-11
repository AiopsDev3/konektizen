import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:konektizen/core/api/api_service.dart';
import 'package:konektizen/features/cases/case_model.dart';
import 'package:konektizen/features/cases/cases_provider.dart';
import 'package:konektizen/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

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
        submittedAt: DateTime.now(),
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
            backgroundColor: item.statusColor.withValues(alpha: 0.1),
            child: Icon(Icons.assignment, size: 32, color: item.statusColor),
          ),
          const SizedBox(height: 16),
          Text(
            item.title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
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
    final steps = [
      {
        'label': 'Submitted',
        'date': item.submittedAt ?? item.date,
        'completed': true,
      },
      {
        'label': 'Validated',
        'date': item.validatedAt,
        'completed':
            item.validatedAt != null || item.status != CaseStatus.submitted,
      },
      {
        'label': 'Assigned',
        'date': item.assignedAt,
        'completed':
            item.assignedAt != null ||
            item.status == CaseStatus.inProgress ||
            item.status == CaseStatus.resolved,
      },
      {
        'label': 'Resolved',
        'date': item.resolvedAt,
        'completed':
            item.resolvedAt != null || item.status == CaseStatus.resolved,
      },
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
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
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
                          isCompleted
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: isCompleted
                              ? AppTheme.primary
                              : Colors.grey[300],
                          size: 20,
                        ),
                        if (!isLast)
                          Expanded(
                            child: Container(
                              width: 2,
                              color: isCompleted
                                  ? AppTheme.primary
                                  : Colors.grey[300],
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
                                fontWeight: isCompleted
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isCompleted
                                    ? Colors.black87
                                    : Colors.grey[500],
                              ),
                            ),
                            if (step['date'] != null)
                              Text(
                                DateFormat(
                                  'MMM d, h:mm a',
                                ).format(step['date'] as DateTime),
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 12,
                                ),
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
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _detailRow('Case ID', item.id),
          _detailRow('Category', item.category),
          _detailRow('Location', item.location),
          _detailRow('Severity', item.severity.name.toUpperCase()),
          if (item.mediaUrls.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Evidence',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 112,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: item.mediaUrls.length,
                separatorBuilder: (context, index) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final url = _absoluteMediaUrl(item.mediaUrls[index]);
                  final type = index < item.mediaTypes.length
                      ? item.mediaTypes[index].toLowerCase()
                      : _guessMediaType(url);
                  final isVideo = _isVideoEvidence(type, url);

                  return InkWell(
                    onTap: () => _showEvidencePreview(context, url, isVideo),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 112,
                      height: 112,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (isVideo)
                            Container(
                              color: Colors.black87,
                              child: const Icon(
                                Icons.play_circle_fill,
                                color: Colors.white,
                                size: 44,
                              ),
                            )
                          else
                            Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                  ),
                            ),
                          Positioned(
                            left: 6,
                            bottom: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                isVideo ? 'VIDEO' : 'PHOTO',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
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
          ],
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
                      content: const Text(
                        'Sigurado ka ba na gusto mong bawiin ang ulat na ito?',
                      ),
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
                      builder: (c) =>
                          const Center(child: CircularProgressIndicator()),
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
                              content: Text(
                                'Hindi mabawi ang ulat. Subukan muli.',
                              ),
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
                label: const Text(
                  'Bawiin ang Ulat',
                  style: TextStyle(color: Colors.red),
                ),
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

  String _absoluteMediaUrl(String url) {
    final trimmed = url.trim();
    if (trimmed.startsWith('http://') ||
        trimmed.startsWith('https://') ||
        trimmed.startsWith('data:') ||
        trimmed.startsWith('blob:')) {
      return trimmed;
    }

    final serverUrl = ApiService.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    if (trimmed.startsWith('/')) return '$serverUrl$trimmed';
    return '$serverUrl/$trimmed';
  }

  String _guessMediaType(String url) {
    final lower = url.toLowerCase();
    if (RegExp(r'\.(mp4|mov|avi|webm|m4v)(\?|$)').hasMatch(lower)) {
      return 'video';
    }
    return 'photo';
  }

  bool _isVideoEvidence(String type, String url) {
    return type == 'video' || _guessMediaType(url) == 'video';
  }

  void _showEvidencePreview(BuildContext context, String url, bool isVideo) {
    showDialog(
      context: context,
      builder: (ctx) {
        if (isVideo) {
          return _NetworkVideoDialog(url: url);
        }

        return Dialog(
          backgroundColor: Colors.black,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.broken_image,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _NetworkVideoDialog extends StatefulWidget {
  final String url;

  const _NetworkVideoDialog({required this.url});

  @override
  State<_NetworkVideoDialog> createState() => _NetworkVideoDialogState();
}

class _NetworkVideoDialogState extends State<_NetworkVideoDialog> {
  VideoPlayerController? _videoController;
  ChewieController? _chewieController;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      final controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.url),
      );
      _videoController = controller;
      await controller.initialize();
      if (!mounted) return;
      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: controller,
          autoPlay: true,
          looping: false,
          aspectRatio: controller.value.aspectRatio,
        );
      });
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Hindi ma-play ang video.');
      }
    }
  }

  @override
  void dispose() {
    _chewieController?.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (_errorMessage != null)
            Text(_errorMessage!, style: const TextStyle(color: Colors.white))
          else if (_chewieController != null)
            Chewie(controller: _chewieController!)
          else
            const CircularProgressIndicator(color: Colors.white),
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}
