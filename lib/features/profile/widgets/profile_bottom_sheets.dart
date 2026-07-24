import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:konektizen/core/config/app_edition.dart';
import 'package:konektizen/core/localization/app_language.dart';
import 'package:konektizen/core/localization/app_localizations.dart';
import 'package:konektizen/features/profile/accessibility_provider.dart';
import 'package:konektizen/theme/app_theme.dart';

class ProfileBottomSheets {
  static Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  static void showLanguageSheet(
    BuildContext context,
    WidgetRef ref,
    AppStrings t,
    AppLanguage selectedLanguage,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.translate_rounded,
                      color: AppTheme.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    t.text('profile.chooseLanguage'),
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...AppLanguage.values.map((lang) {
                final isSelected = lang == selectedLanguage;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: InkWell(
                    onTap: () async {
                      await ref
                          .read(appLanguageProvider.notifier)
                          .setLanguage(lang);
                      final isScreenReader = ref
                          .read(accessibilityProvider)
                          .screenReader;
                      if (isScreenReader) {
                        // ignore: deprecated_member_use
                        SemanticsService.announce(
                          'Language changed to ${lang.nativeLabel}',
                          TextDirection.ltr,
                        );
                      }
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary.withValues(alpha: 0.05)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? AppTheme.primary
                              : const Color(0xFFE2E8F0),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary.withValues(alpha: 0.1)
                                  : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.translate_rounded,
                              color: isSelected
                                  ? AppTheme.primary
                                  : const Color(0xFF64748B),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang.nativeLabel,
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected
                                        ? AppTheme.primary
                                        : const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  lang.label,
                                  style: GoogleFonts.inter(
                                    fontSize: 11,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected)
                            const Icon(
                              Icons.check_circle_rounded,
                              color: AppTheme.primary,
                              size: 20,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  static void showAccessibilitySheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Consumer(
          builder: (context, ref, child) {
            final settings = ref.watch(accessibilityProvider);
            final notifier = ref.read(accessibilityProvider.notifier);

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.accessibility_new_rounded,
                            color: AppTheme.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Accessibility Settings',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeTrackColor: AppTheme.primary,
                      title: Text(
                        'High Contrast Mode',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      subtitle: Text(
                        'Increase text contrast across screens.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      value: settings.highContrast,
                      onChanged: (val) {
                        notifier.toggleHighContrast(val);
                        if (val) {
                          // ignore: deprecated_member_use
                          SemanticsService.announce(
                            'High Contrast Mode Enabled',
                            TextDirection.ltr,
                          );
                        } else {
                          // ignore: deprecated_member_use
                          SemanticsService.announce(
                            'High Contrast Mode Disabled',
                            TextDirection.ltr,
                          );
                        }
                      },
                    ),
                    const Divider(color: Color(0xFFF1F5F9)),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      activeTrackColor: AppTheme.primary,
                      title: Text(
                        'Screen Reader Assistance',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF1E293B),
                        ),
                      ),
                      subtitle: Text(
                        'Optimize components for spoken assistance.',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: const Color(0xFF64748B),
                        ),
                      ),
                      value: settings.screenReader,
                      onChanged: (val) {
                        notifier.toggleScreenReader(val);
                        if (val) {
                          // ignore: deprecated_member_use
                          SemanticsService.announce(
                            'Screen Reader Assistance Enabled',
                            TextDirection.ltr,
                          );
                        } else {
                          // ignore: deprecated_member_use
                          SemanticsService.announce(
                            'Screen Reader Assistance Disabled',
                            TextDirection.ltr,
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static void showHelpSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.help_outline_rounded,
                        color: AppTheme.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Help & Support',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.call_rounded,
                    color: Color(0xFF10B981),
                  ),
                  title: Text(
                    'Emergency Hotline (911)',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  subtitle: Text(
                    'Dial command center hotline immediately.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  onTap: () {
                    _launchUrl('tel:911');
                  },
                ),
                const Divider(color: Color(0xFFF1F5F9)),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.email_outlined,
                    color: Color(0xFF3B82F6),
                  ),
                  title: Text(
                    'Email Support',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  subtitle: Text(
                    'Get in touch at support@aitelligenz.com',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  onTap: () {
                    _launchUrl('mailto:support@aitelligenz.com');
                  },
                ),
                const Divider(color: Color(0xFFF1F5F9)),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFFF59E0B),
                  ),
                  title: Text(
                    'Frequently Asked Questions',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  subtitle: Text(
                    AppFeatures.sosCallsEnabled
                        ? 'Learn how to file reports and trigger SOS.'
                        : 'Learn how to file and monitor reports.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  onTap: () {
                    _showFAQDialog(context);
                  },
                ),
                const Divider(color: Color(0xFFF1F5F9)),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.phone_in_talk_rounded,
                    color: Color(0xFFEF4444),
                  ),
                  title: Text(
                    'Emergency Hotline Numbers',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E293B),
                    ),
                  ),
                  subtitle: Text(
                    'View Laoag City disaster, police, and fire contacts.',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF64748B),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/hotlines');
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  static void _showFAQDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'FAQs',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1E293B),
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFAQItem(
                  'How to file a report?',
                  'Go to home screen and click "Report a Problem". Fill out description, category, and attach media.',
                ),
                const SizedBox(height: 12),
                if (AppFeatures.sosCallsEnabled) ...[
                  _buildFAQItem(
                    'How to trigger SOS?',
                    'Click the floating SOS button on the bottom menu to start an instant video call with the Command Center.',
                  ),
                  const SizedBox(height: 12),
                ],
                _buildFAQItem(
                  'Is my location shared?',
                  AppFeatures.sosCallsEnabled
                      ? 'Yes, only when you submit a report or invoke the Emergency SOS call to help responders locate you.'
                      : 'Yes, only when you submit a report and location is needed to help responders find the incident.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Close',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static Widget _buildFAQItem(String question, String answer) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          question,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF1E293B),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          answer,
          style: GoogleFonts.inter(
            fontSize: 12,
            color: const Color(0xFF475569),
            height: 1.3,
          ),
        ),
      ],
    );
  }

  static void showAboutSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    image: DecorationImage(
                      image: AssetImage('assets/images/logo_green.png'),
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Konektizen',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Version 1.4.2',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Konektizen is a citizen engagement platform enabling real-time hazard reporting, local district coordination, and emergency response in Laoag City.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: const Color(0xFF475569),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Developed and made by AITELLIGENZ',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }
}
