import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:flutter/services.dart';

class PiPOverlay {
  static const MethodChannel _channel = MethodChannel('pip_channel');
  static bool _isPiPMode = false;
  static Function(bool)? _pipModeCallback;

  static Future<void> show({
    required BuildContext context,
    required RTCVideoRenderer localRenderer,
    required VoidCallback onTap,
    required VoidCallback onClose,
  }) async {
    try {
      // Enter native Android PiP mode ONLY - no Flutter overlay
      await _channel.invokeMethod('enterPiP');
      _isPiPMode = true;
      print('[PiP] Native Android PiP activated');
    } catch (e) {
      print('[PiP] Error entering PiP mode: $e');
    }
  }

  static Future<void> hide() async {
    try {
      if (_isPiPMode) {
        await _channel.invokeMethod('exitPiP');
        _isPiPMode = false;
      }
    } catch (e) {
      print('[PiP] Error exiting PiP mode: $e');
    }
  }

  static bool get isShowing => _isPiPMode;
  
  static void updatePiPMode(bool isPiP) {
    _isPiPMode = isPiP;
    _pipModeCallback?.call(isPiP);
  }
  
  static void setupPiPListener(Function(bool) callback) {
    _pipModeCallback = callback;
    
    // Set up method channel to receive PiP mode changes from Android
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onPiPModeChanged') {
        final bool isInPiP = call.arguments as bool;
        updatePiPMode(isInPiP);
      }
    });
  }
}
