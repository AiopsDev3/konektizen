import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:konektizen/core/api/api_service.dart';
import 'package:konektizen/core/utils/app_dialogs.dart';
import 'package:konektizen/features/auth/user_provider.dart';
import 'package:konektizen/features/profile/widgets/location_card.dart';
import 'package:konektizen/features/profile/widgets/profile_info_card.dart';
import 'package:konektizen/features/profile/widgets/security_card.dart';
import 'package:konektizen/theme/app_theme.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _streetCtrl = TextEditingController();
  final _barangayCtrl = TextEditingController();
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _isLoading = false;
  bool _isChangingPassword = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      final userState = ref.read(userProvider);
      if (!mounted) return;
      setState(() {
        _nameCtrl.text = userState.fullName ?? '';
        _emailCtrl.text = userState.email ?? '';
        _phoneCtrl.text = userState.phoneNumber ?? '';
        _streetCtrl.text = userState.residentialAddress ?? '';
        _barangayCtrl.text = userState.barangay ?? '';
      });
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _streetCtrl.dispose();
    _barangayCtrl.dispose();
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userState = ref.read(userProvider);
      await apiService.updateProfile(
        fullName: _nameCtrl.text,
        email: _emailCtrl.text,
        phoneNumber: _phoneCtrl.text.isEmpty ? null : _phoneCtrl.text,
        residentialAddress: _streetCtrl.text,
        barangay: _barangayCtrl.text,
        municipality: 'Laoag City',
        province: 'Ilocos Norte',
        region: 'Region I',
        reporterId: userState.id,
      );

      if (_isChangingPassword && _newPasswordCtrl.text.isNotEmpty) {
        await apiService.changePassword(
          currentPassword: _currentPasswordCtrl.text,
          newPassword: _newPasswordCtrl.text,
        );
      }

      await ref.read(userProvider.notifier).loadCurrentUser();

      if (!mounted) return;

      await AppDialogs.showSuccess(
        context,
        title: 'Profile Updated',
        message: 'Your profile has been updated successfully.',
      );

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (!mounted) return;
      AppDialogs.showError(
        context,
        title: 'Update Failed',
        message: e.toString().replaceAll('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Edit Profile',
          style: GoogleFonts.inter(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1E293B),
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Responsive layout helper: Constrain width on tablets and desktop
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ProfileInfoCard(
                        nameController: _nameCtrl,
                        emailController: _emailCtrl,
                        phoneController: _phoneCtrl,
                        isLoading: _isLoading,
                      ),
                      const SizedBox(height: 20),
                      LocationCard(
                        barangayController: _barangayCtrl,
                        streetController: _streetCtrl,
                        isLoading: _isLoading,
                      ),
                      const SizedBox(height: 20),
                      SecurityCard(
                        isChangingPassword: _isChangingPassword,
                        onToggleChanged: (value) {
                          setState(() => _isChangingPassword = value);
                          if (!value) {
                            _currentPasswordCtrl.clear();
                            _newPasswordCtrl.clear();
                            _confirmPasswordCtrl.clear();
                          }
                        },
                        currentPasswordController: _currentPasswordCtrl,
                        newPasswordController: _newPasswordCtrl,
                        confirmPasswordController: _confirmPasswordCtrl,
                        isLoading: _isLoading,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: _isLoading ? null : _saveChanges,
                        icon: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.check_circle_outline_rounded, size: 20),
                        label: Text(_isLoading ? 'Saving...' : 'Save Changes'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 2,
                          shadowColor: AppTheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
