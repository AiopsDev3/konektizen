import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:konektizen/features/auth/phone_auth_service.dart';
import 'package:konektizen/features/auth/user_provider.dart';
import 'package:konektizen/core/api/api_service.dart';
import 'package:konektizen/theme/app_theme.dart';

class OTPVerificationScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  final String? verificationId;
  final bool isRegister;

  const OTPVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.verificationId,
    this.isRegister = false,
  });

  @override
  ConsumerState<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends ConsumerState<OTPVerificationScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  int _resendCooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _otpController.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendCooldown() {
    setState(() => _resendCooldown = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_resendCooldown == 0) {
        timer.cancel();
      } else {
        setState(() => _resendCooldown--);
      }
    });
  }

  void _showErrorDialog(String message, {VoidCallback? onClose}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onClose?.call();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();

    if (otp.isEmpty) {
      _showErrorDialog('Please enter the OTP code');
      return;
    }

    if (otp.length != 6) {
      _showErrorDialog('OTP must be 6 digits');
      return;
    }

    // Check if we have a verification ID
    if (widget.verificationId == null || widget.verificationId!.isEmpty) {
      _showErrorDialog(
        'No verification in progress. Please go back and request OTP again.',
        onClose: () => context.pop(),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Verify OTP with Firebase using the passed verification ID
      print('Verifying OTP with verificationId: ${widget.verificationId}');
      
      final result = await phoneAuthService.verifyOTPWithId(
        widget.verificationId!,
        otp,
      );

      if (!mounted) return;

      if (result['success'] != true) {
        _showErrorDialog(
          result['error'] ?? 'Invalid OTP. Please check your code and try again.',
        );
        setState(() => _isLoading = false);
        return;
      }

      // 2. Authenticate with Backend
      final firebaseUid = result['firebaseUid'];
      final phoneNumber = result['phoneNumber'];

      if (!mounted) return;

      if (widget.isRegister) {
         // REGISTER FLOW
         final apiResult = await apiService.phoneRegister(
           firebaseUid: firebaseUid,
           phoneNumber: phoneNumber,
         );
         
         if (!mounted) return;
         
         if (apiResult != null && apiResult['error'] != null) {
            // Check for 409 Conflict
            if (apiResult['status'] == 409) {
               _showErrorDialog(
                 apiResult['error'],
                 onClose: () => context.go('/auth/login'), // Redirect to login
               );
            } else {
               _showErrorDialog(apiResult['error']);
            }
            setState(() => _isLoading = false);
            return;
         }

         // Success -> Complete Profile
         context.go('/auth/complete-profile', extra: {
           'firebaseUid': firebaseUid,
           'phoneNumber': phoneNumber,
         });

      } else {
         // LOGIN FLOW
         final apiResult = await apiService.phoneLogin(
           firebaseUid: firebaseUid,
           phoneNumber: phoneNumber,
         );

         if (!mounted) return;

         if (apiResult != null && apiResult['error'] != null) {
            // Check for 404 Not Found
            if (apiResult['status'] == 404) {
               _showErrorDialog(
                 apiResult['error'],
                 onClose: () => context.go('/auth/register'), // Redirect to register
               );
            } else {
               _showErrorDialog(apiResult['error']);
            }
            setState(() => _isLoading = false);
            return;
         }

         // Success -> Home
         context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        _showErrorDialog(
          'An error occurred. Please check your connection.',
        );
        setState(() => _isLoading = false);
      }
    } finally {
      if (mounted) {
        // isLoading set to false in specific error blocks or if success navigation happens (disposed)
        // But if navigation happens, this might run on unmounted widget.
        // Safe check:
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _resendOTP() async {
    if (_resendCooldown > 0) return;

    setState(() => _isLoading = true);

    try {
      final result = await phoneAuthService.resendOTP(widget.phoneNumber);

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent successfully'),
            behavior: SnackBarBehavior.floating,
            margin: EdgeInsets.only(top: 80, left: 16, right: 16),
          ),
        );
        _startResendCooldown();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to resend OTP'),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.only(top: 80, left: 16, right: 16),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An error occurred. Please try again.')),
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
        title: const Text('Verify OTP'),
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
                Icons.message,
                size: 80,
                color: AppTheme.primary,
              ),
              const SizedBox(height: 24),
              const Text(
                'Enter verification code',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'We sent a code to ${widget.phoneNumber}',
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              TextField(
                controller: _otpController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 16,
                  color: Colors.black,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: InputDecoration(
                  hintText: '000000',
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
                onSubmitted: (_) => _verifyOTP(),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyOTP,
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
                          'Verify',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Didn\'t receive the code? ',
                    style: TextStyle(color: Colors.grey),
                  ),
                  TextButton(
                    onPressed: _resendCooldown > 0 ? null : _resendOTP,
                    child: Text(
                      _resendCooldown > 0
                          ? 'Resend in ${_resendCooldown}s'
                          : 'Resend',
                      style: TextStyle(
                        color: _resendCooldown > 0 ? Colors.grey : AppTheme.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
