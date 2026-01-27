import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:konektizen/features/auth/user_provider.dart';
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

  @override
  Widget build(BuildContext context) {
    final userState = ref.watch(userProvider);
    
    // Determine display name: Use fullName if valid and NOT a phone number
    String displayName = 'User';
    if (userState.fullName != null && 
        userState.fullName!.isNotEmpty && 
        !_isLikelyPhoneNumber(userState.fullName)) {
      displayName = userState.fullName!;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: userState.isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: AppTheme.tertiary.withOpacity(0.3),
                    child: const Icon(Icons.person, size: 40, color: AppTheme.primary),
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
                         const Icon(Icons.hourglass_top, color: Colors.orange, size: 20)
                      else
                         const Icon(Icons.gpp_bad_outlined, color: Colors.grey, size: 20),
                    ],
                  ),
                  
                  // ... rest of the build method unchanged until line 64
                  // I will only replace up to the Row end to avoid clobbering too much
                  
                  // Verification Status Text
                  Text(
                    (userState.isVerified ?? false) ? 'Verified Citizen' 
                    : (userState.verificationStatus == 'PENDING' ? 'Verification Pending' : 'Not Verified'),
                    style: TextStyle(
                      color: (userState.isVerified ?? false) ? Colors.blue 
                      : (userState.verificationStatus == 'PENDING' ? Colors.orange : Colors.grey),
                      fontWeight: FontWeight.bold,
                      fontSize: 12
                    ),
                  ),

                  const SizedBox(height: 4),
                  if (userState.email != null && !userState.email!.contains('@konektizen.app'))
                    Text(
                      userState.email!,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  if (userState.phoneNumber != null && userState.phoneNumber!.isNotEmpty)
                    Text(
                      userState.phoneNumber!,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  const SizedBox(height: 24),
                  
                  // MOVED: Verification Button to TOP
                  if (!(userState.isVerified ?? false) && userState.verificationStatus != 'PENDING')
                    Card(
                      elevation: 0,
                      color: Colors.blue.shade50,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.blue.shade200),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.verified_user, color: Colors.blue),
                        title: const Text('Verify Your Account', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Get verified to help your barangay.', style: TextStyle(color: Colors.blueGrey, fontSize: 12)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.blue),
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
                      child: const ListTile(
                        leading: Icon(Icons.hourglass_empty, color: Colors.orange),
                        title: Text('Verification In Progress', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                        subtitle: Text('We are checking your documents.', style: TextStyle(color: Colors.orangeAccent)),
                      ),
                    ),

                  const SizedBox(height: 16),
                  
                  // NEW: Edit Profile Button
                  _buildSettingItem(context, 'Edit Profile', Icons.edit_outlined, onTap: () => context.push('/profile/edit')),
                  
                  // REMOVED: Notifications
                  _buildSettingItem(context, 'Language', Icons.language),
                  _buildSettingItem(context, 'Accessibility', Icons.accessibility_new),
                  _buildSettingItem(context, 'Help & Support', Icons.help_outline),
                  _buildSettingItem(context, 'About KONEKTIZEN', Icons.info_outline),
                  
                  const SizedBox(height: 16),
                  
                  OutlinedButton(
                    onPressed: () async {
                      await ref.read(userProvider.notifier).logout();
                      if (context.mounted) {
                        context.go('/auth/login');
                      }
                    },
                    child: const Text('Log Out'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSettingItem(BuildContext context, String title, IconData icon, {VoidCallback? onTap}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListTile(
        leading: Icon(icon, color: AppTheme.primary),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {},
      ),
    );
  }
}
