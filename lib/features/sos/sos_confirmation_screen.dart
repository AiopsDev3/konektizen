import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:konektizen/core/services/location_service.dart';
import 'package:konektizen/features/sos/sos_service.dart';
import 'package:konektizen/features/sos_video_call/call_screen.dart';

class SOSConfirmationScreen extends StatefulWidget {
  const SOSConfirmationScreen({super.key});

  @override
  State<SOSConfirmationScreen> createState() => _SOSConfirmationScreenState();
}

class _SOSConfirmationScreenState extends State<SOSConfirmationScreen> {
  bool _isProcessing = false;
  bool _sosSent = false;
  String? _hotlineNumber;

  @override
  void initState() {
    super.initState();
    _fetchHotline();
  }

  Future<void> _fetchHotline() async {
    final number = await sosService.getHotlineNumber();
    if(mounted) setState(() => _hotlineNumber = number);
  }

  Future<void> _handleSOS() async {
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

    // 2. Send API Record (Background)
    sosService.sendSOS(
      latitude: location.latitude, 
      longitude: location.longitude,
      hotlineNumber: hotline,
    );
    
    // 3. Start Video Call FIRST (Priority)
    try {
      final videoSession = await sosService.startVideoCall();
      if (videoSession != null && mounted) {
        final callId = videoSession['callId'];
        final token = videoSession['citizenToken'];
        
        setState(() {
          _isProcessing = false;
          _sosSent = true;
        });
        
        print('[SOS] Starting WebRTC video call');
        
        // Navigate to WebRTC CallScreen
        try {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CallScreen(
                callId: callId, 
                token: token,
                role: 'citizen',
                hotlineNumber: hotline,
              ),
            ),
          );
        } catch (e) {
          print('[SOS] ERROR navigating to CallScreen: $e');
          // If navigation fails, fall back to dialer
          if (mounted) {
            final Uri launchUri = Uri(scheme: 'tel', path: hotline);
            try {
              if (await canLaunchUrl(launchUri)) {
                await launchUrl(launchUri);
              }
            } catch (dialerError) {
              print('Error launching dialer: $dialerError');
            }
          }
        }
      } else {
        // Fallback: If video call fails, launch dialer
        if (mounted) {
          final Uri launchUri = Uri(scheme: 'tel', path: hotline);
          try {
            if (await canLaunchUrl(launchUri)) {
              await launchUrl(launchUri);
            }
          } catch (e) {
            print('Error launching dialer: $e');
          }
          
          setState(() {
            _isProcessing = false;
            _sosSent = true;
          });
        }
      }
    } catch (e) {
      print('Error starting video call: $e');
      // Fallback to phone dialer
      if (mounted) {
        final Uri launchUri = Uri(scheme: 'tel', path: hotline);
        try {
          if (await canLaunchUrl(launchUri)) {
            await launchUrl(launchUri);
          }
        } catch (e) {
          print('Error launching dialer: $e');
        }
        
        setState(() {
          _isProcessing = false;
          _sosSent = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_sosSent) {
      return Scaffold(
        backgroundColor: Colors.red.shade900,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 100),
                const SizedBox(height: 24),
                const Text(
                  'SOS SENT',
                  style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Command Center has been alerted.\nYou are being connected to the hotline.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 18),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () => context.pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.red.shade900,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                  ),
                  child: const Text('CLOSE'),
                ),
              ],
            ),
          ),
        ),
      );
    }

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
                const CircularProgressIndicator(color: Colors.white)
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
