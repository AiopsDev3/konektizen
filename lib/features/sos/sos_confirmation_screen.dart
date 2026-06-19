import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:konektizen/core/services/location_service.dart';
import 'package:konektizen/features/sos/sos_service.dart';
import 'package:konektizen/features/sos/widgets/pulsing_sos_button.dart';
import 'package:konektizen/features/sos/widgets/sos_info_grid.dart';
import 'package:konektizen/features/sos_video_call/signaling_service.dart';
import 'package:konektizen/core/api/api_service.dart';

class SOSConfirmationScreen extends StatefulWidget {
  const SOSConfirmationScreen({super.key});

  @override
  State<SOSConfirmationScreen> createState() => _SOSConfirmationScreenState();
}

class _SOSConfirmationScreenState extends State<SOSConfirmationScreen> {
  bool _isProcessing = false;
  String? _statusMessage;
  String? _hotlineNumber;
  final SignalingService _signaling = SignalingService.instance;

  @override
  void initState() {
    super.initState();
    _fetchHotline();
    _signaling.onCallDeclined = _handleCallDeclined;
    _connectSocketEarly();
  }

  @override
  void dispose() {
    if (_signaling.onCallDeclined == _handleCallDeclined) {
      _signaling.onCallDeclined = null;
    }
    super.dispose();
  }

  void _handleCallDeclined(Map<String, dynamic> payload) {
    if (!mounted) return;
    final message = payload['message']?.toString() ??
        'C3 is busy right now. Please try again shortly.';
    setState(() {
      _isProcessing = false;
      _statusMessage = message;
    });
  }

  Future<void> _connectSocketEarly() async {
    try {
      final user = await apiService.getCurrentUser();
      final userId = user?['_id'] ?? user?['id'];
      if (userId != null) {
        _signaling.listenForIncomingCall(userId.toString());
      }
    } catch (e) {
      debugPrint('[SOS UI] Pre-connect error: $e');
    }
  }

  Future<void> _fetchHotline() async {
    final number = await sosService.getHotlineNumber();
    if (mounted) setState(() => _hotlineNumber = number);
  }

  Future<void> _handleSOS() async {
    if (_isProcessing) return;
    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

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
    try {
      final success = await sosService.sendSOS(
        latitude: location.latitude,
        longitude: location.longitude,
        hotlineNumber: hotline,
      );

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
    } catch (e) {
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
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFEF4444),
              Color(0xFF991B1B),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Top Close Button
              Positioned(
                left: 16,
                top: 16,
                child: GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.2),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
              // Main Content
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  children: [
                    const Spacer(flex: 3),
                    PulsingSOSButton(onTap: _handleSOS),
                    const Spacer(flex: 2),
                    Text(
                      'EMERGENCY SOS',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'This will call the Command Center hotline and share your current location with responders.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                    ),
                    const Spacer(flex: 3),
                    const SOSInfoGrid(),
                    const Spacer(flex: 3),
                    _buildActionPanel(context),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionPanel(BuildContext context) {
    if (_isProcessing) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _statusMessage ?? 'Calling Command Center...',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              setState(() => _isProcessing = false);
              context.pop();
            },
            child: Text(
              'CANCEL',
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ElevatedButton(
          onPressed: _handleSOS,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFFEF4444),
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            shadowColor: Colors.black.withValues(alpha: 0.25),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.call_rounded, size: 20),
              const SizedBox(width: 8),
              Text(
                'CALL NOW',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: GestureDetector(
            onTap: () => context.push('/hotlines'),
            child: Text(
              'VIEW ALL LOCAL EMERGENCY HOTLINES',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: GestureDetector(
            onTap: () => context.pop(),
            child: Text(
              'CANCEL',
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
