import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:konektizen/core/api/api_service.dart';
import 'package:konektizen/core/utils/app_dialogs.dart';
import 'package:konektizen/theme/app_theme.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleRegister() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || password.isEmpty) {
      AppDialogs.showError(
        context,
        title: 'Validation Error',
        message: 'Please fill in all fields.',
      );
      return;
    }

    setState(() => _isLoading = true);
    final result = await apiService.register(
      name,
      email, 
      password,
    );
    
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result['success']) {
      if (mounted) {
        await AppDialogs.showSuccess(
          context,
          title: 'Registration Successful',
          message: 'Your account has been created.',
        );
        if (mounted) {
          // After successful registration, login and check verification
          final loginResult = await apiService.login(email, password);
          if (loginResult != null && mounted) {
            _checkVerificationAndProceed(loginResult);
          } else if (mounted) {
            context.pop(); // Go back to login if auto-login fails
          }
        }
      }
    } else {
      if (mounted) {
        AppDialogs.showError(
          context,
          title: 'Registration Failed',
          message: result['error'] ?? 'An error occurred during registration.',
        );
      }
    }
  }


  Future<void> _handleFacebookRegister() async {
    setState(() => _isLoading = true);
    try {
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['public_profile', 'email'],
      );

      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;
        // Use the same endpoint as login, as it handles creation
        final apiResult = await apiService.facebookLogin(accessToken.tokenString);
        
        if (!mounted) return;
        setState(() => _isLoading = false);

        if (apiResult != null && apiResult['error'] == null) {
           _checkVerificationAndProceed(apiResult);
        } else {
           if(mounted) {
             AppDialogs.showError(
               context,
               title: 'Registration Failed',
               message: apiResult?['error'] ?? 'Failed to authenticate with backend.',
             );
           }
        }
      } else {
        if (!mounted) return;
        setState(() => _isLoading = false);
        if (result.status == LoginStatus.failed) {
           AppDialogs.showError(
             context,
             title: 'Facebook Error',
             message: result.message ?? 'Facebook login failed.',
           );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      AppDialogs.showError(
        context,
        title: 'Error',
        message: e.toString(),
      );
    }
  }

  void _checkVerificationAndProceed(Map<String, dynamic> data) {
    if (!mounted) return;

    final user = data['user'];
    final isVerified = user['isVerified'] == true; 
    
    if (!isVerified) {
      _showVerificationPrompt();
    } else {
      context.go('/home');
    }
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
      appBar: AppBar(title: const Text('Mag-rehistro')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Buong Pangalan'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailCtrl,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passCtrl,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text('Gumawa ng Account'),
              ),
            ),
            const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleFacebookRegister,
                  icon: const Icon(Icons.facebook, color: Colors.white),
                  label: const Text('Magpatuloy gamit ang Facebook', 
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    )
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1877F2), // Facebook Blue
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8), // Rounded corners
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),
              
              // Phone Registration Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => context.push(
                    '/auth/phone-login', 
                    extra: {'isRegister': true},
                  ),
                  icon: const Icon(Icons.phone_android, color: Colors.white),
                  label: const Text('Magpatuloy gamit ang Numero',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    )
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),

          ],
        ),
      ),
    );
  }
}
