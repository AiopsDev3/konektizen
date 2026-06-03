import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:konektizen/core/localization/app_language.dart';
import 'package:konektizen/core/localization/app_localizations.dart';
import 'package:konektizen/features/auth/user_provider.dart';
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
    // Load user data when screen opens
    Future.microtask(() => ref.read(userProvider.notifier).loadCurrentUser());
  }

  bool _isLikelyPhoneNumber(String? text) {
    if (text == null || text.isEmpty) return false;
    // Check if it's just digits and plus sign
    final regex = RegExp(r'^\+?[0-9\s]+$');
    if (regex.hasMatch(text) && text.length > 6) return true;
    return false;
  }

  void _openLanguageSheet(
    BuildContext context,
    AppStrings t,
    AppLanguage selectedLanguage,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  t.text('profile.chooseLanguage'),
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ...AppLanguage.values.map((language) {
                  final isSelected = language == selectedLanguage;
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.translate,
                      color: isSelected ? AppTheme.primary : Colors.grey,
                    ),
                    title: Text(language.nativeLabel),
                    subtitle: Text(language.label),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: AppTheme.primary,
                          )
                        : null,
                    onTap: () async {
                      await ref
                          .read(appLanguageProvider.notifier)
                          .setLanguage(language);
                      if (sheetContext.mounted) {
                        Navigator.of(sheetContext).pop();
                      }
                    },
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    final t = ref.watch(appStringsProvider);
    final selectedLanguage = ref.watch(appLanguageProvider);

    // Determine display name: Use fullName if valid and NOT a phone number
    String displayName = 'User';
    if (userState.fullName != null &&
        userState.fullName!.isNotEmpty &&
        !_isLikelyPhoneNumber(userState.fullName)) {
      displayName = userState.fullName!;
    }

    return Scaffold(
      appBar: AppBar(title: Text(t.text('profile.title'))),
      body: userState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppTheme.tertiary.withValues(alpha: 0.3),
                    child: const Icon(
                      Icons.person,
                      size: 40,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Name + Verification Badge (Fixed spacing)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        displayName,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4), // Reduced from 8 to 4
                      // Badge (Fixed positioning)
                      if (userState.isVerified ?? false)
                        const Icon(Icons.verified, color: Colors.blue, size: 20)
                      else if (userState.verificationStatus == 'PENDING')
                        const Icon(
                          Icons.hourglass_top,
                          color: Colors.orange,
                          size: 20,
                        )
                      else
                        const Icon(
                          Icons.gpp_bad_outlined,
                          color: Colors.grey,
                          size: 20,
                        ),
                    ],
                  ),

                  // ... rest of the build method unchanged until line 64
                  // I will only replace up to the Row end to avoid clobbering too much

                  // Verification Status Text
                  Text(
                    (userState.isVerified ?? false)
                        ? t.text('profile.verified')
                        : (userState.verificationStatus == 'PENDING'
                              ? t.text('profile.pending')
                              : t.text('profile.notVerified')),
                    style: TextStyle(
                      color: (userState.isVerified ?? false)
                          ? Colors.blue
                          : (userState.verificationStatus == 'PENDING'
                                ? Colors.orange
                                : Colors.grey),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 4),
                  if (userState.email != null &&
                      !userState.email!.contains('@konektizen.app'))
                    Text(
                      userState.email!,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  if (userState.phoneNumber != null &&
                      userState.phoneNumber!.isNotEmpty)
                    Text(
                      userState.phoneNumber!,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  if (userState.barangay != null &&
                      userState.barangay!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.location_city_outlined,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              userState.barangay!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),

                  // MOVED: Verification Button to TOP
                  if (!(userState.isVerified ?? false) &&
                      userState.verificationStatus != 'PENDING')
                    Card(
                      elevation: 0,
                      color: Colors.blue.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.blue.shade200),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.verified_user,
                          color: Colors.blue,
                        ),
                        title: Text(
                          t.text('profile.verifyAccount'),
                          style: const TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          t.text('profile.verifySubtitle'),
                          style: const TextStyle(
                            color: Colors.blueGrey,
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.blue,
                        ),
                        onTap: () => context.push('/verify-id'),
                      ),
                    )
                  else if (userState.verificationStatus == 'PENDING')
                    Card(
                      elevation: 0,
                      color: Colors.orange.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.orange.shade200),
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.hourglass_empty,
                          color: Colors.orange,
                        ),
                        title: Text(
                          t.text('profile.verificationProgress'),
                          style: const TextStyle(
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          t.text('profile.verificationProgressSubtitle'),
                          style: const TextStyle(color: Colors.orangeAccent),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // NEW: Edit Profile Button
                  ProfileSettingItem(
                    title: t.text('profile.edit'),
                    icon: Icons.edit_outlined,
                    onTap: () => context.push('/profile/edit'),
                  ),
                  ProfileSettingItem(
                    title: t.text('profile.myCases'),
                    icon: Icons.assignment_outlined,
                    onTap: () => context.push('/profile/my-cases'),
                  ),

                  // REMOVED: Notifications
                  ProfileSettingItem(
                    title: t.text('profile.language'),
                    icon: Icons.language,
                    subtitle: selectedLanguage.nativeLabel,
                    onTap: () =>
                        _openLanguageSheet(context, t, selectedLanguage),
                  ),
                  ProfileSettingItem(
                    title: t.text('profile.accessibility'),
                    icon: Icons.accessibility_new,
                  ),
                  ProfileSettingItem(
                    title: t.text('profile.help'),
                    icon: Icons.help_outline,
                  ),
                  ProfileSettingItem(
                    title: t.text('profile.about'),
                    icon: Icons.info_outline,
                  ),

                  const SizedBox(height: 16),

                  OutlinedButton(
                    onPressed: () async {
                      await ref.read(userProvider.notifier).logout();
                      if (context.mounted) {
                        context.go('/auth/login');
                      }
                    },
                    child: Text(t.text('profile.logout')),
                  ),
                ],
              ),
            ),
    );
  }
}
