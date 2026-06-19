import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:konektizen/core/services/location_service.dart';
import 'package:konektizen/features/sos_video_call/livekit_token_service.dart';
import 'package:konektizen/features/sos_video_call/signaling_service.dart';

class CallController {
  final String callId;
  final bool startWithCamera;
  final VoidCallback onStateChanged;

  late Room room;
  EventsListener<RoomEvent>? _listener;
  Timer? _reconnectTimer, _locationHeartbeatTimer;
  StreamSubscription<Position>? _locationSubscription;
  bool _isLocationSharingActive = false, isConnecting = true, isEnding = false, _isReconnectScheduled = false;
  int _reconnectAttempt = 0;
  String? error;

  CallController({required this.callId, required this.startWithCamera, required this.onStateChanged}) {
    _createRoom();
    _connectToLiveKit();
    SignalingService.instance.joinCallRoom(callId, role: 'reporter');
    _startLocationSharing();
  }

  void dispose() {
    isEnding = true;
    _reconnectTimer?.cancel();
    _locationHeartbeatTimer?.cancel();
    _locationSubscription?.cancel();
    _disposeRoomListeners();
    room.dispose();
  }

  void _createRoom() {
    room = Room(roomOptions: const RoomOptions(adaptiveStream: true, dynacast: true))..addListener(onStateChanged);
    _listener = room.createListener()
      ..on<ParticipantEvent>((_) => onStateChanged())
      ..on<RoomConnectedEvent>((_) {
        _reconnectAttempt = 0;
        _isReconnectScheduled = false;
        isConnecting = false;
        error = null;
        onStateChanged();
      })
      ..on<RoomReconnectedEvent>((_) {
        _reconnectAttempt = 0;
        _isReconnectScheduled = false;
        isConnecting = false;
        error = null;
        onStateChanged();
        unawaited(_publishLocalMediaWithRetry());
      })
      ..on<RoomAttemptReconnectEvent>((event) {
        error = 'Interrupted. Reconnecting (${event.attempt}/${event.maxAttemptsRetry})...';
        onStateChanged();
      })
      ..on<RoomDisconnectedEvent>((event) {
        onStateChanged();
        if (_shouldReconnect(event.reason)) _scheduleReconnect(event.reason);
      })
      ..on<TrackSubscribedEvent>((_) => onStateChanged())
      ..on<TrackUnsubscribedEvent>((_) => onStateChanged())
      ..on<TrackMutedEvent>((_) => onStateChanged())
      ..on<TrackUnmutedEvent>((_) => onStateChanged());
  }

  void _disposeRoomListeners() {
    room.removeListener(onStateChanged);
    _listener?.dispose();
    _listener = null;
  }

  bool _shouldReconnect(DisconnectReason? reason) {
    if (isEnding) return false;
    return reason != DisconnectReason.clientInitiated && reason != DisconnectReason.duplicateIdentity && reason != DisconnectReason.participantRemoved && reason != DisconnectReason.roomDeleted;
  }

  void _scheduleReconnect(DisconnectReason? reason) {
    if (_isReconnectScheduled || isEnding) return;
    _isReconnectScheduled = true;
    _reconnectAttempt += 1;
    final delay = _reconnectAttempt < 6 ? _reconnectAttempt * 2 : 12;
    isConnecting = true;
    error = 'Interrupted. Reconnecting in ${delay}s...';
    onStateChanged();

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(Duration(seconds: delay), () {
      if (isEnding) return;
      _isReconnectScheduled = false;
      unawaited(_connectToLiveKit(isReconnect: true));
    });
  }

  Future<void> _connectToLiveKit({bool isReconnect = false}) async {
    isConnecting = true;
    error = isReconnect ? 'Reconnecting to Command Center...' : null;
    onStateChanged();

    try {
      if (isReconnect) {
        _disposeRoomListeners();
        try {
          await room.disconnect();
          await room.dispose();
        } catch (_) {}
        _createRoom();
      }
      final suffix = DateTime.now().millisecondsSinceEpoch;
      final token = await liveKitTokenService.createToken(roomName: callId, participantName: 'Citizen SOS $suffix');
      await room.connect(token.liveKitUrl, token.token);
      SignalingService.instance.joinCallRoom(callId, role: 'reporter');
      _reconnectAttempt = 0;
      _isReconnectScheduled = false;
      unawaited(_publishLocalMediaWithRetry());
    } catch (e) {
      error = e.toString();
      _scheduleReconnect(null);
    } finally {
      isConnecting = _isReconnectScheduled;
      onStateChanged();
    }
  }

  Future<void> _publishLocalMediaWithRetry() async {
    for (var attempt = 0; attempt < 30; attempt += 1) {
      if (isEnding) return;
      if (attempt > 0) await Future.delayed(Duration(milliseconds: 2000 + attempt * 1000));
      if (isEnding) return;

      final participant = room.localParticipant;
      if (participant == null) continue;

      try {
        if (!participant.isMicrophoneEnabled()) await participant.setMicrophoneEnabled(true);
        if (startWithCamera && !participant.isCameraEnabled()) await participant.setCameraEnabled(true);
        onStateChanged();
        return;
      } catch (e) {
        debugPrint('[CallController] Media publish failed: $e');
      }
    }
  }

  Future<void> _sendCurrentLocation({bool force = false}) async {
    if (!_isLocationSharingActive && !force) return;
    try {
      final pos = await locationService.getCurrentLocation();
      if (pos == null) return;
      SignalingService.instance.sendReporterLocation(
        callId: callId, latitude: pos.latitude, longitude: pos.longitude,
        speed: pos.speed >= 0 ? pos.speed * 3.6 : null, heading: pos.heading >= 0 ? pos.heading : null, accuracy: pos.accuracy,
      );
    } catch (_) {}
  }

  Future<void> _startLocationSharing() async {
    if (_isLocationSharingActive) return;
    _isLocationSharingActive = true;
    await _sendCurrentLocation(force: true);

    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5),
    ).listen((pos) {
      SignalingService.instance.sendReporterLocation(
        callId: callId, latitude: pos.latitude, longitude: pos.longitude,
        speed: pos.speed >= 0 ? pos.speed * 3.6 : null, heading: pos.heading >= 0 ? pos.heading : null, accuracy: pos.accuracy,
      );
    });

    _locationHeartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) => _sendCurrentLocation(force: true));
  }
}
