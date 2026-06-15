import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:konektizen/core/services/location_service.dart';
import 'package:konektizen/features/sos_video_call/livekit_token_service.dart';
import 'package:konektizen/features/sos_video_call/signaling_service.dart';

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
  late Room _room;

  EventsListener<RoomEvent>? _listener;
  Timer? _reconnectTimer;
  Timer? _locationHeartbeatTimer;
  StreamSubscription<Position>? _locationSubscription;
  bool _isLocationSharingActive = false;
  bool _isConnecting = true;
  bool _isEnding = false;
  bool _isReconnectScheduled = false;
  int _reconnectAttempt = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _createRoom();
    _connectToLiveKit();
    SignalingService.instance.joinCallRoom(widget.callId, role: 'reporter');
    SignalingService.instance.socket?.on('end-call', _handleRemoteEndCall);
    SignalingService.instance.socket?.on('call_ended', _handleRemoteEndCall);
    WakelockPlus.enable();
    _startLocationSharing();
  }

  @override
  void dispose() {
    _isEnding = true;
    _reconnectTimer?.cancel();
    _locationHeartbeatTimer?.cancel();
    _locationSubscription?.cancel();
    _disposeRoomListeners();
    SignalingService.instance.socket?.off('end-call', _handleRemoteEndCall);
    SignalingService.instance.socket?.off('call_ended', _handleRemoteEndCall);
    WakelockPlus.disable();
    _room.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _createRoom() {
    _room = Room(
      roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
    );
    _room.addListener(_refresh);
    _listener = _room.createListener()
      ..on<ParticipantEvent>((_) => _refresh())
      ..on<RoomConnectedEvent>((_) {
        _reconnectAttempt = 0;
        _isReconnectScheduled = false;
        if (!mounted) return;
        setState(() {
          _isConnecting = false;
          _error = null;
        });
      })
      ..on<RoomReconnectedEvent>((_) {
        _reconnectAttempt = 0;
        _isReconnectScheduled = false;
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _error = null;
          });
        }
        unawaited(_publishLocalMediaWithRetry());
      })
      ..on<RoomAttemptReconnectEvent>((event) {
        if (!mounted) return;
        setState(() {
          _error =
              'Connection interrupted. Reconnecting (${event.attempt}/${event.maxAttemptsRetry})...';
        });
      })
      ..on<RoomDisconnectedEvent>((event) {
        _refresh();
        if (!_shouldReconnectAfterDisconnect(event.reason)) return;
        _scheduleReconnect(reason: event.reason);
      })
      ..on<TrackSubscribedEvent>((_) => _refresh())
      ..on<TrackUnsubscribedEvent>((_) => _refresh())
      ..on<TrackMutedEvent>((_) => _refresh())
      ..on<TrackUnmutedEvent>((_) => _refresh());
  }

  void _disposeRoomListeners() {
    _room.removeListener(_refresh);
    _listener?.dispose();
    _listener = null;
  }

  bool _shouldReconnectAfterDisconnect(DisconnectReason? reason) {
    if (_isEnding || !mounted) return false;
    if (reason == DisconnectReason.clientInitiated ||
        reason == DisconnectReason.duplicateIdentity ||
        reason == DisconnectReason.participantRemoved ||
        reason == DisconnectReason.roomDeleted) {
      return false;
    }
    return true;
  }

  void _scheduleReconnect({DisconnectReason? reason}) {
    if (_isReconnectScheduled || _isEnding || !mounted) return;
    _isReconnectScheduled = true;
    _reconnectAttempt += 1;
    final delaySeconds = _reconnectAttempt < 6 ? _reconnectAttempt * 2 : 12;

    setState(() {
      _isConnecting = true;
      _error =
          'Connection interrupted. Reconnecting in ${delaySeconds}s...';
    });

    debugPrint(
      '[Call Screen] LiveKit disconnected unexpectedly: $reason. '
      'Reconnect attempt $_reconnectAttempt in ${delaySeconds}s.',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_isEnding || !mounted) return;
      _isReconnectScheduled = false;
      unawaited(_connectToLiveKit(isReconnect: true));
    });
  }

  Future<void> _resetRoomForReconnect() async {
    _disposeRoomListeners();
    try {
      await _room.disconnect();
    } catch (_) {}
    try {
      await _room.dispose();
    } catch (_) {}
    _createRoom();
  }

  Future<void> _connectToLiveKit({bool isReconnect = false}) async {
    setState(() {
      _isConnecting = true;
      _error = isReconnect ? 'Reconnecting to Command Center...' : null;
    });

    try {
      if (isReconnect) {
        await _resetRoomForReconnect();
      }
      final suffix = DateTime.now().millisecondsSinceEpoch;
      final participantName = 'Citizen SOS $suffix';
      final token = await liveKitTokenService.createToken(
        roomName: widget.callId,
        participantName: participantName,
      );

      await _room.connect(token.liveKitUrl, token.token);
      SignalingService.instance.joinCallRoom(widget.callId, role: 'reporter');
      _reconnectAttempt = 0;
      _isReconnectScheduled = false;
      unawaited(_publishLocalMediaWithRetry());
    } catch (e) {
      _error = e.toString();
      _scheduleReconnect();
    } finally {
      if (mounted) {
        setState(() => _isConnecting = _isReconnectScheduled);
      }
    }
  }

  Future<void> _publishLocalMediaWithRetry() async {
    for (var attempt = 0; attempt < 30; attempt += 1) {
      if (_isEnding) return;
      final delayMs = attempt == 0
          ? 0
          : (2000 + attempt * 1000 > 10000 ? 10000 : 2000 + attempt * 1000);
      if (delayMs > 0) {
        await Future.delayed(Duration(milliseconds: delayMs));
      }
      if (_isEnding) return;

      final participant = _room.localParticipant;
      if (participant == null) continue;

      try {
        if (!participant.isMicrophoneEnabled()) {
          await participant.setMicrophoneEnabled(true);
        }
        if (widget.startWithCamera && !participant.isCameraEnabled()) {
          await participant.setCameraEnabled(true);
        }
        _refresh();
        return;
      } catch (e) {
        debugPrint('[Call Screen] Media publish retry failed: $e');
      }
    }
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
    if (_isEnding) return;
    _isEnding = true;
    SignalingService.instance.markCallEnded(widget.callId);
    await _room.disconnect();
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
    if (_isEnding) return;
    _isEnding = true;
    SignalingService.instance.endCall(widget.callId);
    await _room.disconnect();
    if (mounted) {
      context.go('/home');
    }
  }

  Future<void> _sendCurrentLocation({bool force = false}) async {
    if (!_isLocationSharingActive && !force) return;

    try {
      final position = await locationService.getCurrentLocation();
      if (position == null) return;

      SignalingService.instance.sendReporterLocation(
        callId: widget.callId,
        latitude: position.latitude,
        longitude: position.longitude,
        speed: position.speed >= 0 ? position.speed * 3.6 : null,
        heading: position.heading >= 0 ? position.heading : null,
        accuracy: position.accuracy,
      );
    } catch (e) {
      debugPrint('[Call Screen] Location send error: $e');
    }
  }

  Future<void> _startLocationSharing() async {
    if (_isLocationSharingActive) return;
    _isLocationSharingActive = true;

    await _sendCurrentLocation(force: true);

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _locationSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings).listen(
          (position) {
            SignalingService.instance.sendReporterLocation(
              callId: widget.callId,
              latitude: position.latitude,
              longitude: position.longitude,
              speed: position.speed >= 0 ? position.speed * 3.6 : null,
              heading: position.heading >= 0 ? position.heading : null,
              accuracy: position.accuracy,
            );
          },
        );

    _locationHeartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _sendCurrentLocation(force: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final local = _room.localParticipant;
    final remoteParticipants = <Participant>[
      ..._room.remoteParticipants.values,
    ];
    final participants = <Participant>[
      ...remoteParticipants,
      if (local != null) local,
    ];
    final mainParticipant = remoteParticipants.isNotEmpty
        ? remoteParticipants.first
        : (participants.isNotEmpty ? participants.first : null);
    final localPreview = local != null && remoteParticipants.isNotEmpty ? local : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: mainParticipant == null
                  ? _CallStatus(
                      message:
                          _error ??
                          (_isConnecting
                              ? 'Connecting to Command Center...'
                              : 'Waiting for operator...'),
                      loading: _isConnecting && _error == null,
                    )
                  : _ParticipantTile(participant: mainParticipant),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: _CallHeader(subtitle: widget.callId),
            ),
            if (localPreview != null)
              Positioned(
                right: 16,
                top: 84,
                width: 118,
                height: 158,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white24),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: _ParticipantTile(
                      participant: localPreview,
                      compact: true,
                    ),
                  ),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: _CallControls(
                micEnabled: local?.isMicrophoneEnabled() ?? false,
                cameraEnabled: local?.isCameraEnabled() ?? false,
                onToggleMic: () async {
                  final participant = _room.localParticipant;
                  if (participant == null) return;
                  await participant.setMicrophoneEnabled(
                    !participant.isMicrophoneEnabled(),
                  );
                  _refresh();
                },
                onToggleCamera: () async {
                  final participant = _room.localParticipant;
                  if (participant == null) return;
                  await participant.setCameraEnabled(
                    !participant.isCameraEnabled(),
                  );
                  _refresh();
                },
                onEnd: _endCall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  final Participant participant;
  final bool compact;

  const _ParticipantTile({required this.participant, this.compact = false});

  VideoTrack? _videoTrack() {
    for (final publication in participant.videoTrackPublications) {
      final track = publication.track;
      if (track is VideoTrack && !publication.muted && !track.muted) {
        return track;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final videoTrack = _videoTrack();
    final name = participant.name.isNotEmpty
        ? participant.name
        : participant.identity;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (videoTrack != null)
          VideoTrackRenderer(videoTrack, renderMode: VideoRenderMode.auto)
        else
          Container(
            color: const Color(0xFF101820),
            child: Center(
              child: CircleAvatar(
                radius: 42,
                backgroundColor: Colors.white12,
                child: Text(
                  name.isEmpty ? 'C3' : name.characters.first.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        Positioned(
          left: compact ? 8 : 12,
          right: compact ? 8 : 12,
          bottom: compact ? 8 : 12,
          child: Row(
            children: [
              Icon(
                participant.isMicrophoneEnabled() ? Icons.mic : Icons.mic_off,
                color: participant.isMicrophoneEnabled()
                    ? Colors.greenAccent
                    : Colors.redAccent,
                size: compact ? 16 : 18,
              ),
              SizedBox(width: compact ? 6 : 8),
              Expanded(
                child: Text(
                  compact ? 'You' : name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 12 : 14,
                    shadows: [Shadow(blurRadius: 6)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CallHeader extends StatelessWidget {
  final String subtitle;

  const _CallHeader({required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 148, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xCC000000), Color(0x00000000)],
        ),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Command Center',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                shadows: [Shadow(blurRadius: 8)],
              ),
            ),
            const SizedBox(height: 4),
            _CallIdText(subtitle: subtitle),
          ],
        ),
      ),
    );
  }
}

class _CallIdText extends StatelessWidget {
  final String subtitle;

  const _CallIdText({required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Text(
      subtitle,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 13,
        letterSpacing: 0.4,
        shadows: [Shadow(blurRadius: 8)],
      ),
    );
  }
}

class _CallStatus extends StatelessWidget {
  final String message;
  final bool loading;

  const _CallStatus({required this.message, required this.loading});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 18),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}

class _CallControls extends StatelessWidget {
  final bool micEnabled;
  final bool cameraEnabled;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onEnd;

  const _CallControls({
    required this.micEnabled,
    required this.cameraEnabled,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _RoundControlButton(
          icon: micEnabled ? Icons.mic : Icons.mic_off,
          onPressed: onToggleMic,
        ),
        const SizedBox(width: 16),
        _RoundControlButton(
          icon: cameraEnabled ? Icons.videocam : Icons.videocam_off,
          onPressed: onToggleCamera,
        ),
        const SizedBox(width: 16),
        _RoundControlButton(
          icon: Icons.call_end,
          color: Colors.red,
          onPressed: onEnd,
        ),
      ],
    );
  }
}

class _RoundControlButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _RoundControlButton({
    required this.icon,
    required this.onPressed,
    this.color = const Color(0xFF1F2937),
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      shape: const CircleBorder(),
      child: IconButton(
        color: Colors.white,
        icon: Icon(icon),
        iconSize: 26,
        padding: const EdgeInsets.all(18),
        onPressed: onPressed,
      ),
    );
  }
}
