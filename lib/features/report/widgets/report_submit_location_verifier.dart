import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:konektizen/core/localization/app_localizations.dart';
import 'package:konektizen/features/report/report_provider.dart';
import 'package:konektizen/theme/app_theme.dart';

class ReportSubmitLocationVerifier extends ConsumerWidget {
  final bool isVerifying;
  final VoidCallback onVerify;

  const ReportSubmitLocationVerifier({
    super.key,
    required this.isVerifying,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(reportDraftProvider);
    final strings = ref.watch(appStringsProvider);
    final isVerified = draft.locationVerified;

    return Container(
      decoration: BoxDecoration(
        color: isVerified ? const Color(0xFFF0FDF4) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isVerified ? const Color(0xFF86EFAC) : const Color(0xFFFED7AA),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: (isVerified ? const Color(0xFF15803D) : const Color(0xFFC2410C)).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isVerified ? Icons.verified_user_rounded : Icons.location_searching_rounded,
                color: isVerified ? const Color(0xFF16A34A) : const Color(0xFFEA580C),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                strings.text('report.locationVerification'),
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w800,
                  color: isVerified ? const Color(0xFF14532D) : const Color(0xFF7C2D12),
                  fontSize: 15,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (isVerified) ...[
            Text(
              strings.text('report.verifiedLocationLabel'),
              style: GoogleFonts.inter(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF475569),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              draft.reporterAddress ?? 'Unknown Address',
              style: GoogleFonts.inter(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${draft.reporterLatitude?.toStringAsFixed(6)}, ${draft.reporterLongitude?.toStringAsFixed(6)}',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ] else ...[
            Text(
              strings.text('report.gpsVerificationRequired'),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF7C2D12),
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (!isVerified)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isVerifying ? null : onVerify,
                icon: isVerifying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.my_location_rounded, size: 16),
                label: Text(isVerifying ? 'Verifying...' : strings.text('report.gpsConfirm')),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  backgroundColor: const Color(0xFFEA580C),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: isVerifying ? null : onVerify,
                icon: isVerifying
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                      )
                    : const Icon(Icons.refresh_rounded, size: 16),
                label: Text(isVerifying ? 'Verifying...' : strings.text('report.gpsUpdate')),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                  foregroundColor: AppTheme.primary,
                  side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
