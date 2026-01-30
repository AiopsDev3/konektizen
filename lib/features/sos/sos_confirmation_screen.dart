import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:konektizen/core/services/location_service.dart';
import 'package:konektizen/features/sos/sos_service.dart';
import 'package:konektizen/features/sos_video_call/call_screen.dart';
import 'package:konektizen/features/sos_video_call/command_center_call_screen.dart';
import 'package:konektizen/features/sos_video_call/signaling_service.dart';
import 'package:konektizen/core/api/api_service.dart'; // To get userId

class SOSConfirmationScreen extends StatefulWidget {
  const SOSConfirmationScreen({super.key});

  @override
  State<SOSConfirmationScreen> createState() => _SOSConfirmationScreenState();
}

class _SOSConfirmationScreenState extends State<SOSConfirmationScreen> {
  bool _isProcessing = false;
  String? _hotlineNumber;
  final SignalingService _signaling = SignalingService.instance; // Singleton ref

  @override
  void initState() {
    super.initState();
    _fetchHotline();
    // OPTIMIZATION: Pre-connect to C3 Socket immediately so we are ready to receive calls instantly.
    _connectSocketEarly();
  }

  Future<void> _connectSocketEarly() async {
    try {
       final user = await apiService.getCurrentUser();
       final userId = user?['_id'] ?? user?['id'];
       if (userId != null) {
          print('[SOS UI] Pre-connecting Socket for User: $userId');
          _signaling.listenForIncomingCall(userId.toString());
       }
    } catch (e) {
       print('[SOS UI] Pre-connect error: $e');
    }
  }

  Future<void> _fetchHotline() async {
    final number = await sosService.getHotlineNumber();
    if(mounted) setState(() => _hotlineNumber = number);
  }

  Future<void> _handleSOS() async {
    // strict debounce
    if (_isProcessing) return; 
    setState(() => _isProcessing = true);

    // 1. Get Location (Required)
    final location = await locationService.getCurrentLocation();
    if (location == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enable Location to send SOS.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isProcessing = false);
      }
      return;
    }

    final hotline = _hotlineNumber ?? '911';

    // 2. Send SOS IMMEDIATELY (Don't wait for anything else)
    print('[SOS UI] ⚡ SENDING SOS IMMEDIATELY');
    try {
      // Send SOS and wait for result
      final success = await sosService.sendSOS(
        latitude: location.latitude, 
        longitude: location.longitude,
        hotlineNumber: hotline,
      );
      
      print('[SOS UI] SOS API Result: $success');
      
      if (!success && mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send SOS. Check connection.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // SOS sent successfully - now wait for operator to accept
      // The call_accepted event listener is already set up in _connectSocketEarly()
      // When C3 accepts, the SignalingService will automatically open the call screen
      print('[SOS UI] ✅ SOS sent successfully. Waiting for operator to accept...');

    } catch (e) {
      print('[SOS UI] SOS API Error: $e');
      if (mounted) {
         setState(() => _isProcessing = false);
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.red,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    )
                  ]
                ),
                child: const Icon(Icons.phone_in_talk, size: 60, color: Colors.red),
              ),
              const SizedBox(height: 48),
              const Text(
                'EMERGENCY SOS',
                style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'This will call the Command Center hotline and share your current location with responders.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const Spacer(),
                if (_isProcessing)
                Column(
                  children: [
                    const CircularProgressIndicator(color: Colors.white),
                    const SizedBox(height: 16),
                    const Text(
                      'SOS Alert Sent!',
                      style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Waiting for operator to accept...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () {
                        setState(() => _isProcessing = false);
                        context.pop();
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                        side: const BorderSide(color: Colors.white, width: 2),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text('GO BACK', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: _handleSOS,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text(
                        'CALL NOW',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => context.pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('CANCEL', style: TextStyle(fontSize: 16)),
                    ),
                  ],
                ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
