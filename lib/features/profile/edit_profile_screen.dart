import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:konektizen/core/api/api_service.dart';
import 'package:konektizen/core/utils/app_dialogs.dart';
import 'package:konektizen/features/auth/user_provider.dart';
import 'package:konektizen/features/verification/barangay_data.dart';
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
    // Load current user data
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
      // Update profile information
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

      // If changing password, update it
      if (_isChangingPassword && _newPasswordCtrl.text.isNotEmpty) {
        await apiService.changePassword(
          currentPassword: _currentPasswordCtrl.text,
          newPassword: _newPasswordCtrl.text,
        );
      }

      // Reload user data
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
    final laoagBarangays = BarangayData.getBarangays('Laoag City');
    final selectedBarangay = laoagBarangays.contains(_barangayCtrl.text)
        ? _barangayCtrl.text
        : null;

    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Profile Information Section
              Text(
                'Profile Information',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!value.contains('@')) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _phoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (Optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 32),

              Text(
                'Alert Location',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: selectedBarangay,
                isExpanded: true,
                hint: Text(
                  _barangayCtrl.text.isNotEmpty
                      ? _barangayCtrl.text
                      : 'Select your barangay',
                  overflow: TextOverflow.ellipsis,
                ),
                decoration: const InputDecoration(
                  labelText: 'Barangay',
                  prefixIcon: Icon(Icons.location_city_outlined),
                  border: OutlineInputBorder(),
                ),
                items: laoagBarangays
                    .map(
                      (barangay) => DropdownMenuItem(
                        value: barangay,
                        child: Text(barangay, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  setState(() => _barangayCtrl.text = value ?? '');
                },
                validator: (value) {
                  if ((value == null || value.isEmpty) &&
                      _barangayCtrl.text.isEmpty) {
                    return 'Please select your barangay';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _streetCtrl,
                decoration: const InputDecoration(
                  labelText: 'Street / House Address (Optional)',
                  prefixIcon: Icon(Icons.home_outlined),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 32),

              // Change Password Section
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Change Password',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                  Switch(
                    value: _isChangingPassword,
                    onChanged: (value) {
                      setState(() => _isChangingPassword = value);
                      if (!value) {
                        _currentPasswordCtrl.clear();
                        _newPasswordCtrl.clear();
                        _confirmPasswordCtrl.clear();
                      }
                    },
                  ),
                ],
              ),

              if (_isChangingPassword) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _currentPasswordCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (_isChangingPassword &&
                        (value == null || value.isEmpty)) {
                      return 'Please enter your current password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _newPasswordCtrl,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (_isChangingPassword &&
                        (value == null || value.isEmpty)) {
                      return 'Please enter a new password';
                    }
                    if (_isChangingPassword && value!.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                TextFormField(
                  controller: _confirmPasswordCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  obscureText: true,
                  validator: (value) {
                    if (_isChangingPassword && value != _newPasswordCtrl.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],

              const SizedBox(height: 32),

              ElevatedButton(
                onPressed: _isLoading ? null : _saveChanges,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Save Changes',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
