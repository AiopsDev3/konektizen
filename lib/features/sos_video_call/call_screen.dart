import 'package:flutter/material.dart';
import 'package:konektizen/features/sos_video_call/command_center_call_screen.dart';

class CallScreen extends StatefulWidget {
  final String callId;
  final String token;
  final String role; // 'citizen'
  final String? hotlineNumber;

  const CallScreen({
    super.key,
    required this.callId,
    required this.token,
    this.role = 'citizen',
    this.hotlineNumber,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  @override
  Widget build(BuildContext context) {
    return CommandCenterCallScreen(
      callId: widget.callId,
      operatorName: widget.hotlineNumber ?? 'AIGOR',
      startWithCamera: true,
    );
  }
}
