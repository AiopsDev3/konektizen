import 'package:flutter/material.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:go_router/go_router.dart';
import 'package:konektizen/core/api/api_service.dart';
import 'package:konektizen/core/config/environment.dart';
import 'package:konektizen/core/widgets/validation_dialog.dart';
import 'package:konektizen/theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    // Validate email and password
    if (_emailCtrl.text.trim().isEmpty) {
      ValidationDialog.show(context, 'Please enter your email');
      return;
    }
    
    if (_passCtrl.text.isEmpty) {
      ValidationDialog.show(context, 'Please enter your password');
      return;
    }
    
    if (!_emailCtrl.text.contains('@')) {
      ValidationDialog.show(context, 'Please enter a valid email address');
      return;
    }
    
    setState(() => _isLoading = true);
    try {
      final result = await apiService.login(_emailCtrl.text.trim(), _passCtrl.text);
      
      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result != null) {
        if (mounted) _checkVerificationAndProceed(result);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login failed. Check credentials.')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _handleFacebookLogin() async {
    setState(() => _isLoading = true);
    try {
      final LoginResult result = await FacebookAuth.instance.login(
        permissions: ['public_profile', 'email'],
      );

      if (result.status == LoginStatus.success) {
        final AccessToken accessToken = result.accessToken!;
        final apiResult = await apiService.facebookLogin(accessToken.tokenString);
        
        if (!mounted) return;
        setState(() => _isLoading = false);

        if (apiResult != null && apiResult['error'] == null) {
          if (mounted) _checkVerificationAndProceed(apiResult);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(apiResult?['error'] ?? 'Facebook login failed')),
            );
          }
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Facebook login cancelled')),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Facebook login error: $e')),
        );
      }
    }
  }

  void _checkVerificationAndProceed(Map<String, dynamic> data) {
    if (!mounted) return;

    final user = data['user'];
    final isVerified = user?['isVerified'] == true; 
    
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
      resizeToAvoidBottomInset: true,
      appBar: AppBar(title: const Text('Mag-login')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 32),
              // Logo
              const Icon(
                Icons.location_city,
                size: 80,
                color: AppTheme.primary,
              ),
              const SizedBox(height: 16),
              const Text(
                'Welcome to Konektizen',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'Connect with your community today.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              // Email field
              TextField(
                controller: _emailCtrl,
                decoration: InputDecoration(
                  labelText: 'Email',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Password field
              TextField(
                controller: _passCtrl,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              // Login button
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Mag-login',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              // Facebook login button
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleFacebookLogin,
                  icon: const Icon(Icons.facebook, color: Colors.white),
                  label: const Text(
                    'Magpatuloy gamit ang Facebook',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1877F2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Phone login button
              SizedBox(
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : () => context.push(
                    '/auth/phone-login',
                    extra: {'isRegister': false},
                  ),
                  icon: const Icon(Icons.phone, color: Colors.white),
                  label: const Text(
                    'Magpatuloy gamit ang Numero',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Register link
              TextButton(
                onPressed: () => context.push('/auth/register'),
                child: const Text(
                  'Wala pang account? Mag-rehistro',
                  style: TextStyle(color: AppTheme.primary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
