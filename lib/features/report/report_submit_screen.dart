import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:konektizen/core/localization/app_localizations.dart';
import 'package:konektizen/features/report/report_provider.dart';
import 'package:konektizen/features/report/widgets/report_submit_location_verifier.dart';
import 'package:konektizen/features/report/widgets/video_preview_dialog.dart';
import 'package:konektizen/theme/app_theme.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:konektizen/core/services/location_service.dart';
import 'package:konektizen/features/cases/cases_provider.dart';

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
    Future.microtask(() => ref.read(reportDraftProvider.notifier).resetLocationVerification());
  }

  Future<bool> _checkLocationRequirements(AppStrings strings) async {
    final hasPermission = await locationService.hasPermission();
    if (!hasPermission) {
      if (mounted) _showPermissionDialog(strings);
      return false;
    }

    final isGpsOn = await locationService.isLocationServiceEnabled();
    if (!isGpsOn) {
      if (mounted) _showGpsDialog(strings);
      return false;
    }
    
    return true;
  }

  void _showPermissionDialog(AppStrings strings) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(strings.text('report.gpsRequiredTitle'), style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(strings.text('report.gpsRequiredBody'), style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.text('report.cancel'), style: GoogleFonts.inter(color: const Color(0xFF64748B))),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              openAppSettings();
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Allow Location'),
          ),
        ],
      ),
    );
  }

  void _showGpsDialog(AppStrings strings) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(strings.text('report.gpsTurnOnTitle'), style: GoogleFonts.inter(fontWeight: FontWeight.w700)),
        content: Text(strings.text('report.gpsTurnOnBody'), style: GoogleFonts.inter()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(strings.text('report.cancel'), style: GoogleFonts.inter(color: const Color(0xFF64748B))),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              Geolocator.openLocationSettings();
            },
            style: FilledButton.styleFrom(backgroundColor: AppTheme.primary),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyLocation() async {
    if (_isVerifyingLocation) return;
    final strings = ref.read(appStringsProvider);
    
    final canProceed = await _checkLocationRequirements(strings);
    if (!canProceed) return;

    setState(() => _isVerifyingLocation = true);

    try {
      final position = await locationService.getCurrentLocation();
      if (position != null && mounted) {
        final address = await locationService.getAddressFromCoordinates(position.latitude, position.longitude);
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
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isVerifyingLocation = false);
    }
  }

  void _showMediaPreview(BuildContext context, String url, String type, String? localPath) {
    if (type == 'video') {
      showDialog(
        context: context,
        builder: (ctx) => VideoPreviewDialog(url: url, localPath: localPath),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                child: localPath != null
                  ? Image.file(File(localPath), fit: BoxFit.contain)
                  : Image.network(url, fit: BoxFit.contain),
              ),
              Positioned(
                top: 40,
                right: 20,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
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
    setState(() => _isSubmitting = true);

    try {
      await ref.read(reportDraftProvider.notifier).submitReport();
      ref.read(reportDraftProvider.notifier).clearDraft();
      ref.invalidate(caseListProvider);

      if (mounted) {
        context.go('/report/success');
      }
    } catch (e) {
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildSummaryRow(IconData icon, String title, String value, {bool isUrgency = false}) {
    final isHigh = isUrgency && value.toLowerCase() == 'high';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: const Color(0xFF64748B), size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isHigh ? AppTheme.error : const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(reportDraftProvider);
    final strings = ref.watch(appStringsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          strings.text('report.reviewTitle'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
      ),
      body: _isSubmitting 
        ? Center(
            child: CircularProgressIndicator(
              color: AppTheme.primary,
              strokeWidth: 3,
            ),
          )
        : SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Step progress indicator at 100%
                LinearProgressIndicator(
                  value: 1.0, 
                  color: AppTheme.primary,
                  backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 24),
                Text(
                  strings.text('report.summary'),
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 16),
                
                // Summary details Card
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildSummaryRow(
                        Icons.report_problem_outlined, 
                        strings.text('report.fieldProblem'), 
                        draft.category ?? 'Uncategorized',
                      ),
                      const Divider(color: Color(0xFFF1F5F9), height: 24, thickness: 1),
                      _buildSummaryRow(
                        Icons.priority_high_rounded, 
                        strings.text('report.fieldUrgency'), 
                        draft.severity?.name.toUpperCase() ?? 'MEDIUM',
                        isUrgency: true,
                      ),
                      const Divider(color: Color(0xFFF1F5F9), height: 24, thickness: 1),
                      _buildSummaryRow(
                        Icons.location_on_outlined, 
                        strings.text('report.fieldReportedLocation'), 
                        '${draft.address}, ${draft.city}',
                      ),
                      const Divider(color: Color(0xFFF1F5F9), height: 24, thickness: 1),
                      _buildSummaryRow(
                        Icons.my_location_rounded, 
                        strings.text('report.fieldYourLocation'), 
                        draft.reporterLatitude != null 
                            ? '${draft.reporterLatitude?.toStringAsFixed(6)}, ${draft.reporterLongitude?.toStringAsFixed(6)}'
                            : 'Paghahanap ng GPS...',
                      ),
                      const Divider(color: Color(0xFFF1F5F9), height: 24, thickness: 1),
                      _buildSummaryRow(
                        Icons.description_outlined, 
                        strings.text('report.fieldDescription'), 
                        draft.description,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Evidence Grid Card
                Text(
                  '${strings.text('report.evidenceCount')} (${draft.mediaUrls.length})',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 12),
                if (draft.mediaUrls.isEmpty)
                  Text(
                    strings.text('report.noEvidence'), 
                    style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13),
                  )
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: List.generate(draft.mediaUrls.length, (index) {
                      if (index >= draft.mediaUrls.length) return const SizedBox();
                      final url = draft.mediaUrls[index];
                      final type = index < draft.mediaTypes.length ? draft.mediaTypes[index] : 'photo';
                      final localPath = (index < draft.localMediaPaths.length) ? draft.localMediaPaths[index] : null;
                      
                      return GestureDetector(
                        onTap: () => _showMediaPreview(context, url, type, localPath),
                        child: Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFE2E8F0)),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              if (type == 'photo')
                                localPath != null
                                  ? Image.file(File(localPath), fit: BoxFit.cover)
                                  : Image.network(url, fit: BoxFit.cover)
                              else
                                const Center(
                                  child: Icon(Icons.videocam_rounded, color: Color(0xFF475569), size: 30),
                                ),
                              if (type == 'video')
                                Container(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  child: const Icon(Icons.play_circle_outline_rounded, color: Colors.white, size: 28),
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ),
                const SizedBox(height: 24),
                
                // Location Verification Gate Card
                ReportSubmitLocationVerifier(
                  isVerifying: _isVerifyingLocation,
                  onVerify: _verifyLocation,
                ),
                const SizedBox(height: 24),
                
                // Terms Checkbox and Submit
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _certified, 
                        onChanged: (v) => setState(() => _certified = v ?? false),
                        activeColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        strings.text('report.certifyText'),
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF475569),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: (_certified && draft.locationVerified) ? _handleSubmit : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    draft.locationVerified ? strings.text('report.submit') : strings.text('report.gpsEnableToSubmit'),
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
