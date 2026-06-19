import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:konektizen/core/localization/app_localizations.dart';
import 'package:konektizen/features/auth/user_provider.dart';
import 'package:konektizen/features/profile/accessibility_provider.dart';
import 'package:konektizen/features/profile/widgets/profile_bottom_sheets.dart';
import 'package:konektizen/features/profile/profile_setting_item.dart';
import 'package:konektizen/theme/app_theme.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});
  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(userProvider.notifier).loadCurrentUser());
  }

  bool _isLikelyPhoneNumber(String? text) {
    if (text == null || text.isEmpty) return false;
    return RegExp(r'^\+?[0-9\s]+$').hasMatch(text) && text.length > 6;
  }



  Widget _buildGroup(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: List.generate(children.length * 2 - 1, (index) {
          if (index.isOdd) return const Divider(height: 1, color: Color(0xFFF1F5F9), indent: 52);
          return children[index ~/ 2];
        }),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8, top: 16),
      child: Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF94A3B8), letterSpacing: 1.2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final t = ref.watch(appStringsProvider);
    final selectedLanguage = ref.watch(appLanguageProvider);

    if (userState.isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    final isVerified = userState.isVerified ?? false;
    final isPending = userState.verificationStatus == 'PENDING';
    final name = (userState.fullName?.isNotEmpty == true && !_isLikelyPhoneNumber(userState.fullName)) ? userState.fullName! : 'User';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(t.text('profile.title')),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Premium Profile Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.primary, AppTheme.primaryLight], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: AppTheme.primary.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 6))],
              ),
              child: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 3)),
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: const Icon(Icons.person, size: 36, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(child: Text(name, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
                            const SizedBox(width: 6),
                            Icon(
                              isVerified ? Icons.verified : (isPending ? Icons.hourglass_top : Icons.gpp_bad_outlined),
                              color: isVerified ? const Color(0xFF38BDF8) : (isPending ? Colors.amber : Colors.white60),
                              size: 18,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(userState.phoneNumber ?? userState.email ?? '', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
                        if (userState.barangay?.isNotEmpty == true) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.location_city, size: 12, color: Colors.white.withValues(alpha: 0.8)),
                              const SizedBox(width: 4),
                              Flexible(child: Text(userState.barangay!, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.bold))),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Verification Prompt if not verified
            if (!isVerified) ...[
              Container(
                decoration: BoxDecoration(
                  color: isPending ? const Color(0xFFFFFBEB) : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isPending ? const Color(0xFFFDE68A) : const Color(0xFFBFDBFE)),
                ),
                child: ListTile(
                  leading: Icon(isPending ? Icons.hourglass_empty : Icons.verified_user, color: isPending ? Colors.orange : Colors.blue),
                  title: Text(
                    isPending ? t.text('profile.verificationProgress') : t.text('profile.verifyAccount'),
                    style: TextStyle(color: isPending ? Colors.orange.shade800 : Colors.blue.shade800, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    isPending ? t.text('profile.verificationProgressSubtitle') : t.text('profile.verifySubtitle'),
                    style: TextStyle(color: isPending ? Colors.orange.shade700 : Colors.blue.shade700, fontSize: 12),
                  ),
                  trailing: isPending ? null : const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.blue),
                  onTap: isPending ? null : () => context.push('/verify-id'),
                ),
              ),
              const SizedBox(height: 10),
            ],

            _buildSectionHeader('ACCOUNT & ACTIVITY'),
            _buildGroup([
              ProfileSettingItem(title: t.text('profile.edit'), icon: Icons.edit_outlined, onTap: () => context.push('/profile/edit')),
              ProfileSettingItem(title: t.text('profile.myCases'), icon: Icons.assignment_outlined, onTap: () => context.push('/profile/my-cases')),
            ]),

            _buildSectionHeader('PREFERENCES'),
            _buildGroup([
              ProfileSettingItem(
                title: t.text('profile.language'),
                icon: Icons.language,
                subtitle: selectedLanguage.nativeLabel,
                onTap: () => ProfileBottomSheets.showLanguageSheet(
                    context, ref, t, selectedLanguage),
              ),
              ProfileSettingItem(
                title: t.text('profile.accessibility'),
                icon: Icons.accessibility_new,
                subtitle: ref.watch(accessibilityProvider).highContrast
                    ? 'High Contrast Active'
                    : 'Default scaling & contrast',
                onTap: () => ProfileBottomSheets.showAccessibilitySheet(context, ref),
              ),
            ]),

            _buildSectionHeader('SUPPORT & INFORMATION'),
            _buildGroup([
              ProfileSettingItem(
                title: t.text('profile.help'),
                icon: Icons.help_outline,
                subtitle: 'FAQs & Support Hotline',
                onTap: () => ProfileBottomSheets.showHelpSheet(context),
              ),
              ProfileSettingItem(
                title: t.text('profile.about'),
                icon: Icons.info_outline,
                subtitle: 'Made by AITELLIGENZ',
                onTap: () => ProfileBottomSheets.showAboutSheet(context),
              ),
            ]),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.logout),
                label: Text(t.text('profile.logout')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.redAccent),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () async {
                  await ref.read(userProvider.notifier).logout();
                  if (context.mounted) context.go('/auth/login');
                },
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
