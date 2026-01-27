import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:konektizen/features/auth/phone_auth_service.dart';
import 'package:konektizen/theme/app_theme.dart';

class PhoneLoginScreen extends StatefulWidget {
  final bool isRegister;
  
  const PhoneLoginScreen({
    super.key, 
    this.isRegister = false,
  });

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  String _formatPhoneNumber(String phone) {
    // Remove all non-digits
    String digits = phone.replaceAll(RegExp(r'\D'), '');
    
    // If starts with 0, replace with 63
    if (digits.startsWith('0')) {
      digits = '63${digits.substring(1)}';
    }
    
    // If doesn't start with 63, add it
    if (!digits.startsWith('63')) {
      digits = '63$digits';
    }
    
    // Add + prefix
    return '+$digits';
  }

  bool _isValidPhoneNumber(String phone) {
    final formatted = _formatPhoneNumber(phone);
    // PH numbers: +63 followed by 10 digits
    return RegExp(r'^\+63\d{10}$').hasMatch(formatted);
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

  Future<void> _sendOTP() async {
    final phone = _phoneController.text.trim();
    
    if (phone.isEmpty) {
      _showErrorDialog('Please enter your phone number');
      return;
    }

    if (!_isValidPhoneNumber(phone)) {
      _showErrorDialog(
        'Invalid phone number. Please enter a valid PH number (e.g., 09171234567)',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final formattedPhone = _formatPhoneNumber(phone);
      print('Sending OTP to: $formattedPhone');
      
      final result = await phoneAuthService.sendOTP(formattedPhone);
      
      print('Send OTP result: $result');

      if (!mounted) return;

      if (result['success'] == true) {
        // Navigate to OTP verification screen
        print('Navigating to OTP screen with verificationId: ${result['verificationId']}');
        context.push('/auth/verify-otp', extra: {
          'phoneNumber': formattedPhone,
          'verificationId': result['verificationId'],
          'isRegister': widget.isRegister,
        });
      } else {
        _showErrorDialog(
          result['error'] ?? 'Failed to send OTP. Please check your Firebase configuration.',
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(
          'Firebase OTP testing is currently not working. Please try again later.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(widget.isRegister ? 'Phone Registration' : 'Phone Login'),
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
                Icons.phone_android,
                size: 80,
                color: AppTheme.primary,
              ),
              const SizedBox(height: 24),
              Text(
                widget.isRegister ? 'Create Account with Phone' : 'Log in with Phone',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'We\'ll send you a verification code',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(11),
                ],
                decoration: InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: const Icon(Icons.phone),
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
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                ),
                onSubmitted: (_) => _sendOTP(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendOTP,
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
                          'Send OTP',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => context.pop(),
                child: const Text('Back to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
