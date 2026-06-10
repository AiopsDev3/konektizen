import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:geolocator/geolocator.dart';
import 'package:livekit_client/livekit_client.dart';
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
  final Room _room = Room(
    roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true),
  );

  EventsListener<RoomEvent>? _listener;
  Timer? _locationHeartbeatTimer;
  StreamSubscription<Position>? _locationSubscription;
  bool _isLocationSharingActive = false;
  bool _isConnecting = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _room.addListener(_refresh);
    _listener = _room.createListener()
      ..on<ParticipantEvent>((_) => _refresh())
      ..on<RoomDisconnectedEvent>((_) => _refresh())
      ..on<TrackSubscribedEvent>((_) => _refresh())
      ..on<TrackUnsubscribedEvent>((_) => _refresh())
      ..on<TrackMutedEvent>((_) => _refresh())
      ..on<TrackUnmutedEvent>((_) => _refresh());
    _connectToLiveKit();
    _startLocationSharing();
  }

  @override
  void dispose() {
    _locationHeartbeatTimer?.cancel();
    _locationSubscription?.cancel();
    _room.removeListener(_refresh);
    _listener?.dispose();
    _room.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _connectToLiveKit() async {
    setState(() {
      _isConnecting = true;
      _error = null;
    });

    try {
      final suffix = DateTime.now().millisecondsSinceEpoch;
      final participantName = 'Citizen SOS $suffix';
      final token = await liveKitTokenService.createToken(
        roomName: widget.callId,
        participantName: participantName,
      );

      await _room.connect(token.liveKitUrl, token.token);
      await _room.localParticipant?.setMicrophoneEnabled(true);
      await _room.localParticipant?.setCameraEnabled(widget.startWithCamera);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _isConnecting = false);
      }
    }
  }

  Future<void> _endCall() async {
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
      print('[Call Screen] Location send error: $e');
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
    final participants = <Participant>[
      ..._room.remoteParticipants.values,
      if (local != null) local,
    ];
    final mainParticipant = participants.isNotEmpty ? participants.first : null;

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
              left: 16,
              right: 16,
              top: 16,
              child: _CallHeader(
                title: widget.operatorName ?? 'Command Center SOS',
                subtitle: widget.callId,
              ),
            ),
            if (participants.length > 1)
              Positioned(
                right: 16,
                bottom: 104,
                width: 128,
                height: 172,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _ParticipantTile(participant: participants.last),
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

  const _ParticipantTile({required this.participant});

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
          left: 12,
          right: 12,
          bottom: 12,
          child: Row(
            children: [
              Icon(
                participant.isMicrophoneEnabled() ? Icons.mic : Icons.mic_off,
                color: participant.isMicrophoneEnabled()
                    ? Colors.greenAccent
                    : Colors.redAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  name,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
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
  final String title;
  final String subtitle;

  const _CallHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
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
