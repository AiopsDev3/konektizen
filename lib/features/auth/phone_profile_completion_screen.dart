import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:konektizen/core/api/api_service.dart';
import 'package:konektizen/theme/app_theme.dart';

class PhoneProfileCompletionScreen extends StatefulWidget {
  final String firebaseUid;
  final String phoneNumber;

  const PhoneProfileCompletionScreen({
    super.key,
    required this.firebaseUid,
    required this.phoneNumber,
  });

  @override
  State<PhoneProfileCompletionScreen> createState() => _PhoneProfileCompletionScreenState();
}

class _PhoneProfileCompletionScreenState extends State<PhoneProfileCompletionScreen> {
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _completeProfile() async {
    final name = _nameController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty) {
      _showErrorDialog('Please enter your name');
      return;
    }

    if (password.isEmpty) {
      _showErrorDialog('Please enter a password');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Call backend to update user with name and password
      final result = await apiService.completePhoneProfile(
        fullName: name,
        password: password,
      );

      if (!mounted) return;

      if (result != null) {
        // Token is already saved from registration step

        
        // Show "Know Your Citizen" verification prompt
        _showVerificationPrompt();
      } else {
        _showErrorDialog('Failed to complete profile. Please try again.');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog('An error occurred. Please try again.');
        setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showVerificationPrompt() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('I-verify ang iyong account'),
        content: const Text(
          'Para magamit nang buo ang KONEKTIZEN',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/home');
            },
            child: const Text('\'Wag muna'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.go('/home');
              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) context.push('/verify-id');
              });
            },
            child: const Text('Mag-verify ngayon'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              const Icon(
                Icons.person_add,
                size: 80,
                color: AppTheme.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                'Welcome!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Logged in with ${widget.phoneNumber}',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _completeProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text(
                          'Continue',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
