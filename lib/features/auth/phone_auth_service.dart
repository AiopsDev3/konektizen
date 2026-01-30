import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PhoneAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String? _verificationId;
  int? _resendToken;
  DateTime? _lastOtpSentTime;
  
  // Send OTP to phone number
  Future<Map<String, dynamic>> sendOTP(String phoneNumber) async {
    try {
      // ⚠️ TESTING BYPASS - Remove in production!
      // This bypasses Firebase billing requirement for testing
      // Universal bypass for any number if needed, or specific test numbers
      if (phoneNumber == '+639612283926' || phoneNumber.endsWith('123456')) {
        print('🧪 Using test bypass for $phoneNumber');
        _verificationId = 'test-verification-id-12345';
        _lastOtpSentTime = DateTime.now();
        return {
          'success': true,
          'verificationId': _verificationId,
          'message': 'Test OTP sent (bypassed Firebase - Use 123456)',
        };
      }
      
      // Check cooldown (60 seconds between resends)
      if (_lastOtpSentTime != null) {
        final difference = DateTime.now().difference(_lastOtpSentTime!);
        if (difference.inSeconds < 60) {
          return {
            'success': false,
            'error': 'Please wait ${60 - difference.inSeconds} seconds before resending',
          };
        }
      }

      final completer = <String, dynamic>{};
      
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        timeout: const Duration(seconds: 60),
        
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (Android only)
          print('Auto-verification completed');
        },
        
        verificationFailed: (FirebaseAuthException e) {
          print('Verification failed: ${e.code} - ${e.message}');
          completer['success'] = false;
          completer['error'] = _getErrorMessage(e.code);
        },
        
        codeSent: (String verificationId, int? resendToken) {
          print('OTP sent successfully');
          _verificationId = verificationId;
          _resendToken = resendToken;
          _lastOtpSentTime = DateTime.now();
          completer['success'] = true;
          completer['verificationId'] = verificationId;
        },
        
        codeAutoRetrievalTimeout: (String verificationId) {
          print('Auto-retrieval timeout');
          _verificationId = verificationId;
        },
        
        forceResendingToken: _resendToken,
      );

      // Wait for callback (increased time for test phone numbers)
      await Future.delayed(const Duration(seconds: 3));
      
      if (completer.isEmpty) {
        return {
          'success': true,
          'verificationId': _verificationId,
          'message': 'OTP sent successfully',
        };
      }
      
      return completer;
    } catch (e) {
      print('Send OTP Error: $e');
      return {
        'success': false,
        'error': 'Failed to send OTP. Please check your internet connection.',
      };
    }
  }

  // Verify OTP code
  Future<Map<String, dynamic>> verifyOTP(String otp) async {
    if (_verificationId == null) {
      return {
        'success': false,
        'error': 'No verification in progress. Please request OTP first.',
      };
    }

    return await verifyOTPWithId(_verificationId!, otp);
  }

  // Verify OTP with explicit verification ID
  Future<Map<String, dynamic>> verifyOTPWithId(String verificationId, String otp, {bool verifyOnly = false}) async {
    try {
      // ⚠️ TESTING BYPASS - Universal for '123456'
      // This allows the user to proceed with KYC even if Firebase SMS fails
      if (otp == '123456') {
        print('🧪 Using Universal Test Bypass for OTP: $otp');
        return {
          'success': true,
          'firebaseUid': 'test-uid-${DateTime.now().millisecondsSinceEpoch}',
          'phoneNumber': '+639123456789', // Dummy, or we can use the actual input if passed
        };
      }
      
      // Legacy specific number bypass
      if (verificationId == 'test-verification-id-12345' && otp == '123456') {
        print('🧪 Using test bypass for OTP verification');
        return {
          'success': true,
          'firebaseUid': 'test-uid-${DateTime.now().millisecondsSinceEpoch}',
          'phoneNumber': '+639612283926',
        };
      }
      
      print('Creating credential with verificationId: $verificationId and OTP: $otp');
      
      final credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      if (verifyOnly) {
         print('Verifying OTP strictly (NO main auth side effects)...');
         // We use a secondary Firebase App to verify the credential without
         // disrupting the main app's session (e.g. Email/Facebook login).
         FirebaseApp secondaryApp;
         try {
           secondaryApp = Firebase.app('VerifyApp');
         } catch (_) {
           secondaryApp = await Firebase.initializeApp(
             name: 'VerifyApp',
             options: Firebase.app().options,
           );
         }

         final secondaryAuth = FirebaseAuth.instanceFor(app: secondaryApp);
         final userCredential = await secondaryAuth.signInWithCredential(credential);
         
         // If success, we have proof. Now cleanup.
         final uid = userCredential.user?.uid;
         final phone = userCredential.user?.phoneNumber;
         
         print('OTP Verified on secondary app! UID: $uid');
         
         await secondaryAuth.signOut(); // Cleanup secondary session
         
         return {
           'success': true,
           'firebaseUid': uid,
           'phoneNumber': phone,
         };

      } else {
        // Normal Flow (Login/Register)
        print('Signing in with credential (Main App)...');
        final userCredential = await _auth.signInWithCredential(credential);
        
        print('Sign in successful! UID: ${userCredential.user?.uid}');
        
        return {
          'success': true,
          'firebaseUid': userCredential.user?.uid,
          'phoneNumber': userCredential.user?.phoneNumber,
        };
      }
    } on FirebaseAuthException catch (e) {
      print('Verify OTP Error: ${e.code} - ${e.message}');
      return {
        'success': false,
        'error': _getErrorMessage(e.code),
      };
    } catch (e) {
      print('Verify OTP Error: $e');
      return {
        'success': false,
        'error': 'Failed to verify OTP. Please try again. $e',
      };
    }
  }

  // Resend OTP
  Future<Map<String, dynamic>> resendOTP(String phoneNumber) async {
    return await sendOTP(phoneNumber);
  }

  // Get user-friendly error messages
  String _getErrorMessage(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Invalid phone number format. Please use +63 format.';
      case 'invalid-verification-code':
        return 'Invalid OTP code. Please check and try again.';
      case 'session-expired':
        return 'OTP expired. Please request a new one.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your internet connection.';
      case 'quota-exceeded':
        return 'SMS quota exceeded. Please try again later.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  // Reset state
  void reset() {
    _verificationId = null;
    _resendToken = null;
    _lastOtpSentTime = null;
  }
}

final phoneAuthService = PhoneAuthService();
