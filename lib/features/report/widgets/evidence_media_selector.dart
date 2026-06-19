import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:konektizen/core/localization/app_localizations.dart';
import 'package:konektizen/theme/app_theme.dart';

class EvidenceMediaSelector extends ConsumerWidget {
  final List<File> mediaFiles;
  final List<String> mediaTypes;
  final VoidCallback onCapturePhoto;
  final VoidCallback onRecordVideo;
  final Function(int) onRemoveMedia;
  final Function(String, String) onShowPreview;

  const EvidenceMediaSelector({
    super.key,
    required this.mediaFiles,
    required this.mediaTypes,
    required this.onCapturePhoto,
    required this.onRecordVideo,
    required this.onRemoveMedia,
    required this.onShowPreview,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = ref.watch(appStringsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.text('report.evidenceLabel'),
          style: GoogleFonts.inter(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onCapturePhoto,
                icon: const Icon(Icons.camera_alt_rounded, size: 18),
                label: Text(strings.text('report.photoButton')),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primary,
                  side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: onRecordVideo,
                icon: const Icon(Icons.videocam_rounded, size: 18),
                label: Text(strings.text('report.videoButton')),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(0, 44),
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.primary,
                  side: BorderSide(color: AppTheme.primary.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (mediaFiles.isNotEmpty)
          SizedBox(
            height: 90,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: mediaFiles.length,
              itemBuilder: (context, index) {
                final isPhoto = mediaTypes[index] == 'photo';
                return Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 90,
                  height: 90,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            onTap: () => onShowPreview(mediaFiles[index].path, mediaTypes[index]),
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                                borderRadius: BorderRadius.circular(12),
                                color: const Color(0xFFF1F5F9),
                              ),
                              child: isPhoto
                                  ? Image.file(
                                      mediaFiles[index],
                                      fit: BoxFit.cover,
                                    )
                                  : const Center(
                                      child: Icon(
                                        Icons.play_circle_outline_rounded,
                                        size: 40,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => onRemoveMedia(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Color(0xFFEF4444),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
