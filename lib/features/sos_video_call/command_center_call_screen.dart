import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:konektizen/features/sos_video_call/call_controller.dart';
import 'package:konektizen/features/sos_video_call/signaling_service.dart';
import 'package:konektizen/features/sos_video_call/widgets/call_header.dart';
import 'package:konektizen/features/sos_video_call/widgets/call_controls.dart';
import 'package:konektizen/features/sos_video_call/widgets/participant_tile.dart';
import 'package:konektizen/features/sos_video_call/widgets/call_status.dart';

class CommandCenterCallScreen extends StatefulWidget {
  final String callId;
  final String? operatorName;
  final bool startWithCamera;

  const CommandCenterCallScreen({
    super.key,
    required this.callId,
    this.operatorName,
    this.startWithCamera = true,
  });

  @override
  State<CommandCenterCallScreen> createState() =>
      _CommandCenterCallScreenState();
}

class _CommandCenterCallScreenState extends State<CommandCenterCallScreen> {
  late final CallController _controller;

  @override
  void initState() {
    super.initState();
    _controller = CallController(
      callId: widget.callId,
      startWithCamera: widget.startWithCamera,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
    );
    SignalingService.instance.socket?.on('end-call', _handleRemoteEndCall);
    SignalingService.instance.socket?.on('call_ended', _handleRemoteEndCall);
    WakelockPlus.enable();
  }

  @override
  void dispose() {
    SignalingService.instance.socket?.off('end-call', _handleRemoteEndCall);
    SignalingService.instance.socket?.off('call_ended', _handleRemoteEndCall);
    WakelockPlus.disable();
    _controller.dispose();
    super.dispose();
  }

  bool _isPayloadForThisCall(dynamic data) {
    if (data is! Map) return false;
    final payload = Map<String, dynamic>.from(data);
    final payloadCallId =
        payload['room']?.toString() ??
        payload['call_id']?.toString() ??
        payload['callId']?.toString() ??
        payload['id']?.toString();
    return payloadCallId == widget.callId;
  }

  Future<void> _closeFromRemoteEnd() async {
    if (_controller.isEnding) return;
    _controller.isEnding = true;
    SignalingService.instance.markCallEnded(widget.callId);
    try {
      await _controller.room.disconnect();
    } catch (_) {}
    if (!mounted) return;

    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Command Center ended the call.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    context.go('/home');
  }

  void _handleRemoteEndCall(dynamic data) {
    if (!_isPayloadForThisCall(data)) return;
    _closeFromRemoteEnd();
  }

  Future<void> _endCall() async {
    if (_controller.isEnding) return;
    _controller.isEnding = true;
    SignalingService.instance.endCall(widget.callId);
    try {
      await _controller.room.disconnect();
    } catch (_) {}
    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final local = _controller.room.localParticipant;
    final remoteParticipants = <Participant>[
      ..._controller.room.remoteParticipants.values,
    ];
    final participants = <Participant>[
      ...remoteParticipants,
      if (local != null) local,
    ];
    final mainParticipant = remoteParticipants.isNotEmpty
        ? remoteParticipants.first
        : (participants.isNotEmpty ? participants.first : null);
    final localPreview = local != null && remoteParticipants.isNotEmpty ? local : null;

    final isConnected = mainParticipant != null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: !isConnected
                  ? CallStatus(
                      message: _controller.error ??
                          (_controller.isConnecting
                              ? 'Connecting to Command Center...'
                              : 'Waiting for operator...'),
                      loading: _controller.isConnecting && _controller.error == null,
                    )
                  : ParticipantTile(
                      participant: mainParticipant,
                      key: ValueKey('remote_${mainParticipant.identity}'),
                    ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: CallHeader(
                callId: widget.callId,
                isConnected: isConnected,
              ),
            ),
            if (localPreview != null)
              Positioned(
                right: 16,
                top: 96,
                width: 118,
                height: 158,
                child: ParticipantTile(
                  participant: localPreview,
                  compact: true,
                  key: ValueKey('local_${localPreview.identity}'),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: CallControls(
                  micEnabled: local?.isMicrophoneEnabled() ?? false,
                  cameraEnabled: local?.isCameraEnabled() ?? false,
                  onToggleMic: () async {
                    final participant = _controller.room.localParticipant;
                    if (participant == null) return;
                    await participant.setMicrophoneEnabled(
                      !participant.isMicrophoneEnabled(),
                    );
                  },
                  onToggleCamera: () async {
                    final participant = _controller.room.localParticipant;
                    if (participant == null) return;
                    await participant.setCameraEnabled(
                      !participant.isCameraEnabled(),
                    );
                  },
                  onEnd: _endCall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
