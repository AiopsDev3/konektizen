import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:konektizen/features/report/report_provider.dart';
import 'package:konektizen/theme/app_theme.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';
import 'package:konektizen/features/cases/cases_provider.dart';
import 'package:konektizen/core/services/location_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:konektizen/core/utils/app_dialogs.dart';

class ReportSubmitScreen extends ConsumerStatefulWidget {
  const ReportSubmitScreen({super.key});

  @override
  ConsumerState<ReportSubmitScreen> createState() => _ReportSubmitScreenState();
}

class _ReportSubmitScreenState extends ConsumerState<ReportSubmitScreen> {
  bool _isSubmitting = false;
  bool _certified = false;
  bool _isVerifyingLocation = false;

  @override
  void initState() {
    super.initState();
    // Reset verification state on load to force fresh check
    Future.microtask(() => ref.read(reportDraftProvider.notifier).resetLocationVerification());
  }

  Future<bool> _checkLocationRequirements() async {
    // 1. Check Permission
    final hasPermission = await locationService.hasPermission();
    if (!hasPermission) {
      if (mounted) _showPermissionDialog();
      return false;
    }

    // 2. Check GPS Service
    final isGpsOn = await locationService.isLocationServiceEnabled();
    if (!isGpsOn) {
      if (mounted) _showGpsDialog();
      return false;
    }
    
    return true;
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Kailangan ang Lokasyon'),
        content: const Text('Upang makapag-submit ng report, kailangan ng Konektizen ang iyong lokasyon for accurate routing and response.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            child: const Text('Allow Location'),
          ),
        ],
      ),
    );
  }

  void _showGpsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Buksan ang GPS'),
        content: const Text('Please turn on Location Services (GPS) to continue.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyLocation() async {
    if (_isVerifyingLocation) return;
    
    final canProceed = await _checkLocationRequirements();
    if (!canProceed) return;

    setState(() => _isVerifyingLocation = true);

    try {
      final position = await locationService.getCurrentLocation();
      if (position != null && mounted) {
        final address = await locationService.getAddressFromCoordinates(
          position.latitude, 
          position.longitude
        );
        
        ref.read(reportDraftProvider.notifier).confirmLocation(
          lat: position.latitude,
          lng: position.longitude,
          address: address,
        );
      } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Hindi makuha ang lokasyon. Subukan muli.')),
           );
        }
      }
    } catch (e) {
      print('Verification error: $e');
    } finally {
      if (mounted) setState(() => _isVerifyingLocation = false);
    }
  }

  void _showMediaPreview(BuildContext context, String url, String type, String? localPath) {
    if (type == 'video') {
      showDialog(
        context: context,
        builder: (ctx) => _VideoPreviewDialog(url: url, localPath: localPath),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(0),
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                child: localPath != null
                  ? Image.file(
                      File(localPath),
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.white, size: 64),
                    )
                  : Image.network(
                      url,
                      fit: BoxFit.contain,
                      errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.white, size: 64),
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
        ),
      );
    }
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      // 1. Submit Report
      await ref.read(reportDraftProvider.notifier).submitReport();

      // Ensure draft is cleared (the provider should already do this, but being extra safe)
      ref.read(reportDraftProvider.notifier).clearDraft();

      // Refresh My Cases list
      ref.invalidate(caseListProvider);

      // 2. Success Navigation
      if (mounted) {
        await AppDialogs.showSuccess(
          context,
          title: 'Report Submitted',
          message: 'Naisumite na ang iyong report! Maaari ka nang mag-file ng iba pang report.',
        );
        
        if (mounted) {
          context.go('/home');
        }
      }
    } catch (e) {
      // 3. Error Handling
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
             title: const Text('Bigo ang Pagsumite'),
             content: Text('Hindi maipadala ang report. Pakisuri ang iyong koneksyon at subukan muli. ($e)'),
             actions: [
               TextButton(
                 onPressed: () => Navigator.of(ctx).pop(),
                 child: const Text('OK'),
               ),
             ],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  Widget _buildSection(BuildContext context, String title, String value, {bool isUrgency = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
            color: isUrgency && value == 'HIGH' ? Colors.red : null,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(reportDraftProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Report'),
      ),
      body: _isSubmitting 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const LinearProgressIndicator(value: 1.0, backgroundColor: AppTheme.primaryLight),
            const SizedBox(height: 24),
            Text(
              'Summary',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildSection(context, 'Problem', draft.category ?? 'Uncategorized'),
            _buildSection(context, 'Urgency/Severity', draft.severity?.name.toUpperCase() ?? 'MEDIUM', isUrgency: true),
            _buildSection(context, 'Reported Location', '${draft.address}, ${draft.city}'),
            _buildSection(context, 'Your Exact Location', 
              draft.reporterLatitude != null 
                ? '${draft.reporterLatitude?.toStringAsFixed(6)}, ${draft.reporterLongitude?.toStringAsFixed(6)}'
                : 'Paghahanap ng GPS...'),
            _buildSection(context, 'Description', draft.description),
            const SizedBox(height: 16),
            Text(
              'Evidence (${draft.mediaUrls.length})',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            
            // Dynamic Evidence Grid
            if (draft.mediaUrls.isEmpty)
              const Text('No evidence attached', style: TextStyle(color: Colors.grey))
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(draft.mediaUrls.length, (index) {
                  // Safety check for index
                  if (index >= draft.mediaUrls.length) return const SizedBox();
                  
                  final url = draft.mediaUrls[index];
                  // Handle case where types might be out of sync (though they shouldn't be)
                  final type = index < draft.mediaTypes.length ? draft.mediaTypes[index] : 'photo';
                  final localPath = (index < draft.localMediaPaths.length) ? draft.localMediaPaths[index] : null;
                  
                  return GestureDetector(
                    onTap: () => _showMediaPreview(context, url, type, localPath),
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade400),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          if (type == 'photo')
                            localPath != null
                              ? Image.file(File(localPath), fit: BoxFit.cover)
                              : Image.network(
                                  url, 
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
                                )
                          else
                            const Center(child: Icon(Icons.videocam, color: Colors.grey, size: 32)),
                          
                          // Type indicator overlay
                          if (type == 'video')
                             Container(
                               color: Colors.black26,
                               child: const Icon(Icons.play_circle_outline, color: Colors.white),
                             ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
              
            const SizedBox(height: 24),
            
            // Location Verification Gate Block
            Container(
              decoration: BoxDecoration(
                color: draft.locationVerified ? AppTheme.primaryContainer : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: draft.locationVerified ? AppTheme.primary : Colors.orange,
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        draft.locationVerified ? Icons.verified : Icons.location_searching,
                        color: draft.locationVerified ? AppTheme.primary : Colors.orange[800],
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Kumpirmahin ang Lokasyon',
                        style: TextStyle(
                          fontWeight: FontWeight.bold, 
                          color: draft.locationVerified ? AppTheme.primary : Colors.orange[900],
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  
                  if (draft.locationVerified) ...[
                     Text(
                       'Verified Location:',
                       style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                     ),
                     const SizedBox(height: 4),
                     Text(
                       draft.reporterAddress ?? 'Unknown Address',
                       style: const TextStyle(fontWeight: FontWeight.w500),
                     ),
                     const SizedBox(height: 4),
                     Text(
                       '${draft.reporterLatitude?.toStringAsFixed(6)}, ${draft.reporterLongitude?.toStringAsFixed(6)}',
                       style: TextStyle(fontSize: 12, color: Colors.grey[600], fontFamily: 'monospace'),
                     ),
                  ] else ...[
                     const Text(
                       'Kailangan ng GPS verification bago makapag-submit. I-click ang button sa ibaba upang kumpirmahin.',
                       style: TextStyle(fontSize: 13),
                     ),
                  ],
                  
                  const SizedBox(height: 16),
                  
                  if (!draft.locationVerified)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isVerifyingLocation ? null : _verifyLocation,
                        icon: _isVerifyingLocation 
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.my_location),
                        label: Text(_isVerifyingLocation ? 'Verifying...' : 'Confirm This Location'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[800],
                          foregroundColor: Colors.white,
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _isVerifyingLocation ? null : _verifyLocation,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Update Location'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.primary),
                        ),
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 32),
             ValueListenableBuilder<bool>(
               valueListenable: ValueNotifier<bool>(false),
               builder: (context, isCertified, _) {
                 return Column(
                   children: [
                     Row(
                       children: [
                         Checkbox(
                           value: _certified, 
                           onChanged: (v) => setState(() => _certified = v ?? false)
                         ),
                         const Expanded(
                           child: Text(
                             'I certify that this information is true and correct and I allow to send my exact location.',
                             style: TextStyle(fontSize: 12),
                           ),
                         ),
                       ],
                     ),
                     const SizedBox(height: 16),
                     SizedBox(
                       width: double.infinity,
                       child: ElevatedButton(
                         onPressed: (_certified && draft.locationVerified) ? _handleSubmit : null,
                         style: ElevatedButton.styleFrom(
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                           backgroundColor: AppTheme.secondary,
                           foregroundColor: Colors.white,
                           padding: const EdgeInsets.symmetric(vertical: 12),
                         ),
                         child: Text(draft.locationVerified ? 'Submit Report' : 'Enable GPS to Submit'),
                       ),
                     ),
                   ],
                 );
               }
             ),
          ],
        ),
      ),
    );
  }
}

class _VideoPreviewDialog extends StatefulWidget {
  final String url;
  final String? localPath;
  const _VideoPreviewDialog({required this.url, this.localPath});

  @override
  State<_VideoPreviewDialog> createState() => _VideoPreviewDialogState();
}

class _VideoPreviewDialogState extends State<_VideoPreviewDialog> {
  late VideoPlayerController _videoController;
  ChewieController? _chewieController;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    if (widget.localPath != null) {
      _videoController = VideoPlayerController.file(File(widget.localPath!));
    } else {
      _videoController = VideoPlayerController.networkUrl(Uri.parse(widget.url));
    }
    await _videoController.initialize();
    
    if (mounted) {
      setState(() {
        _chewieController = ChewieController(
          videoPlayerController: _videoController,
          autoPlay: true,
          looping: false,
          aspectRatio: _videoController.value.aspectRatio,
          errorBuilder: (context, errorMessage) {
            return Center(child: Text(errorMessage, style: const TextStyle(color: Colors.white)));
          },
        );
      });
    }
  }

  @override
  void dispose() {
    _videoController.dispose();
    _chewieController?.dispose();
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
          if (_chewieController != null)
            Chewie(controller: _chewieController!)
          else
            const CircularProgressIndicator(),
            
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
