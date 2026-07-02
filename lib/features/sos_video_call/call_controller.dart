import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:zego_express_engine/zego_express_engine.dart';
import 'package:konektizen/core/services/location_service.dart';
import 'package:konektizen/features/sos_video_call/signaling_service.dart';
import 'package:konektizen/features/sos_video_call/zego_token_service.dart';

class CallController {
  final String callId;
  final String roomName;
  final bool startWithCamera;
  final bool deferPublishing;
  final bool deferConnection;
  final VoidCallback onStateChanged;

  Timer? _reconnectTimer, _locationHeartbeatTimer;
  StreamSubscription<Position>? _locationSubscription;
  bool _isLocationSharingActive = false,
      isConnecting = true,
      isEnding = false,
      _isReconnectScheduled = false,
      _isDisconnecting = false,
      _hasDisconnected = false,
      _engineReady = false,
      _skipNativeCleanup = false;
  bool isMicEnabled = true, isCameraEnabled = true;
  bool _isZegoConnected = false;
  bool _isPublishing = false;
  int _reconnectAttempt = 0;
  String? error;
  String? _publishStreamId, _remoteStreamId;
  int? _localViewId, _remoteViewId;
  Widget? localView, remoteView;

  CallController({
    required this.callId,
    required this.roomName,
    required this.startWithCamera,
    this.deferPublishing = false,
    this.deferConnection = false,
    required this.onStateChanged,
  }) {
    isCameraEnabled = startWithCamera;
    SignalingService.instance.markCallActive(roomName);
    SignalingService.instance.joinCallRoom(roomName, role: 'reporter');
    if (deferConnection) {
      isConnecting = false;
      error = null;
      Future.microtask(onStateChanged);
    } else {
      _connectToZego();
    }
    _startLocationSharing();
  }

  void dispose() {
    isEnding = true;
    _reconnectTimer?.cancel();
    _locationHeartbeatTimer?.cancel();
    _locationSubscription?.cancel();
    if (!_skipNativeCleanup) {
      unawaited(disconnect());
    }
  }

  bool get hasRemoteParticipant => remoteView != null;
  bool get hasLocalPreview => localView != null;

  void _scheduleReconnect() {
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
      unawaited(_connectToZego(isReconnect: true, publishAfterConnect: true));
    });
  }

  Future<void> _connectToZego({
    bool isReconnect = false,
    bool publishAfterConnect = false,
  }) async {
    isConnecting = true;
    error = isReconnect ? 'Reconnecting to Command Center...' : null;
    onStateChanged();

    try {
      final suffix = DateTime.now().millisecondsSinceEpoch;
      final userId = _safeZegoId('citizen_${callId}_$suffix');
      final token = await zegoTokenService.createToken(
        callId: callId,
        roomName: roomName,
        userId: userId,
        userName: 'Citizen SOS',
      );

      await _resetZegoEngine();
      final profile = ZegoEngineProfile(
        token.appId,
        ZegoScenario.StandardVideoCall,
        appSign: null,
        enablePlatformView: false,
      );
      await ZegoExpressEngine.createEngineWithProfile(profile);
      _engineReady = true;
      _hasDisconnected = false;
      _bindZegoCallbacks();

      final config = ZegoRoomConfig.defaultConfig()
        ..token = token.token
        ..isUserStatusNotify = true;
      final login = await ZegoExpressEngine.instance.loginRoom(
        token.roomId,
        ZegoUser(token.userId, token.userName),
        config: config,
      );
      if (login.errorCode != 0) {
        throw Exception('ZEGO room login failed (${login.errorCode}).');
      }
      _isZegoConnected = true;

      _publishStreamId = token.publishStreamId;
      await ZegoExpressEngine.instance.muteMicrophone(false);
      await ZegoExpressEngine.instance.enableCamera(isCameraEnabled);
      await _startLocalPreview();
      if (publishAfterConnect || !deferPublishing) {
        await _startPublishing();
      }
      SignalingService.instance.joinCallRoom(roomName, role: 'reporter');
      _reconnectAttempt = 0;
      _isReconnectScheduled = false;
      isConnecting = false;
      error = null;
    } catch (e) {
      if (deferPublishing && !publishAfterConnect) {
        debugPrint('[CallController] ZEGO prep skipped during AI triage: $e');
        await _resetZegoEngine(clearCallbacks: true);
        _isPublishing = false;
        _isReconnectScheduled = false;
        isConnecting = false;
        error = null;
        return;
      }
      error = e.toString();
      _scheduleReconnect();
    } finally {
      isConnecting = _isReconnectScheduled;
      onStateChanged();
    }
  }

  void _bindZegoCallbacks() {
    ZegoExpressEngine.onRoomStreamUpdate = (roomId, updateType, streamList, _) {
      if (roomId != roomName) return;
      if (updateType == ZegoUpdateType.Add) {
        for (final stream in streamList) {
          if (stream.streamID == _publishStreamId ||
              stream.streamID == _remoteStreamId) {
            continue;
          }
          unawaited(_startRemotePlayback(stream.streamID));
          break;
        }
      } else if (updateType == ZegoUpdateType.Delete) {
        for (final stream in streamList) {
          if (stream.streamID == _remoteStreamId) {
            unawaited(_stopRemotePlayback());
          }
        }
      }
    };
    ZegoExpressEngine
        .onRoomStateChanged = (roomId, _, errorCode, extendedData) {
      if (roomId != roomName || errorCode == 0 || isEnding) return;
      error = 'ZEGO room warning ($errorCode)';
      debugPrint('[CallController] ZEGO room warning $errorCode $extendedData');
      onStateChanged();
    };
    ZegoExpressEngine
        .onPublisherStateUpdate = (streamId, state, errorCode, extendedData) {
      if (streamId != _publishStreamId || errorCode == 0 || isEnding) return;
      error = 'ZEGO publish warning ($errorCode)';
      debugPrint(
        '[CallController] ZEGO publish warning $state $errorCode $extendedData',
      );
      onStateChanged();
    };
  }

  Future<void> _startLocalPreview() async {
    final widget = await ZegoExpressEngine.instance.createCanvasView((viewId) {
      if (isEnding || !_engineReady) return;
      _localViewId = viewId;
      ZegoExpressEngine.instance.startPreview(canvas: ZegoCanvas.view(viewId));
    });
    if (isEnding || !_engineReady) return;
    localView = widget;
    onStateChanged();
  }

  Future<void> _startRemotePlayback(String streamId) async {
    _remoteStreamId = streamId;
    final widget = await ZegoExpressEngine.instance.createCanvasView((viewId) {
      if (isEnding || !_engineReady) return;
      _remoteViewId = viewId;
      ZegoExpressEngine.instance.startPlayingStream(
        streamId,
        canvas: ZegoCanvas.view(viewId),
      );
    });
    if (isEnding || !_engineReady) return;
    remoteView = widget;
    onStateChanged();
  }

  Future<void> _stopRemotePlayback() async {
    final streamId = _remoteStreamId;
    if (_engineReady && streamId != null) {
      try {
        await ZegoExpressEngine.instance.stopPlayingStream(streamId);
      } catch (_) {}
    }
    if (_engineReady && _remoteViewId != null) {
      try {
        await ZegoExpressEngine.instance.destroyCanvasView(_remoteViewId!);
      } catch (_) {}
    }
    _remoteStreamId = null;
    _remoteViewId = null;
    remoteView = null;
    onStateChanged();
  }

  Future<void> pausePublishingForAiTriage() async {
    if (!_engineReady || !_isZegoConnected || isEnding) {
      _isPublishing = false;
      return;
    }
    try {
      if (_isPublishing) {
        await ZegoExpressEngine.instance.muteMicrophone(true);
        await ZegoExpressEngine.instance.stopPublishingStream();
      }
    } catch (e) {
      debugPrint(
        '[CallController] Could not pause publishing for AI triage: $e',
      );
    } finally {
      _isPublishing = false;
    }
  }

  Future<void> resumePublishingAfterAiTriage() async {
    if (_isPublishing || isEnding) return;
    await setNativeMicrophoneMuted(!isMicEnabled);
    if (!_isZegoConnected || _publishStreamId == null) {
      await _connectToZego(publishAfterConnect: true);
      return;
    }
    await _startPublishing();
  }

  Future<void> _startPublishing() async {
    if (!_engineReady ||
        !_isZegoConnected ||
        _publishStreamId == null ||
        _isPublishing ||
        isEnding) {
      return;
    }
    await ZegoExpressEngine.instance.startPublishingStream(_publishStreamId!);
    _isPublishing = true;
  }

  Future<void> toggleMicrophone() async {
    isMicEnabled = !isMicEnabled;
    if (_isZegoConnected) {
      await ZegoExpressEngine.instance.muteMicrophone(!isMicEnabled);
    }
    onStateChanged();
  }

  Future<void> setNativeMicrophoneMuted(bool muted) async {
    if (!_isZegoConnected || isEnding) return;
    try {
      await ZegoExpressEngine.instance.muteMicrophone(muted);
    } catch (e) {
      debugPrint('[CallController] Could not set native mic muted=$muted: $e');
    }
  }

  Future<void> toggleCamera() async {
    isCameraEnabled = !isCameraEnabled;
    if (_isZegoConnected) {
      await ZegoExpressEngine.instance.enableCamera(isCameraEnabled);
    }
    onStateChanged();
  }

  Future<void> ensureCameraEnabled() async {
    var changed = false;
    if (!isCameraEnabled) {
      isCameraEnabled = true;
      changed = true;
    }
    if (_isZegoConnected) {
      await ZegoExpressEngine.instance.enableCamera(true);
    }
    if (changed) onStateChanged();
  }

  Future<void> disconnect() async {
    if (_isDisconnecting || _hasDisconnected) return;
    _isDisconnecting = true;
    _hasDisconnected = true;
    _reconnectTimer?.cancel();
    _isReconnectScheduled = false;
    try {
      if (_engineReady) {
        try {
          if (_isPublishing && _publishStreamId != null) {
            await ZegoExpressEngine.instance.stopPublishingStream();
          }
        } catch (_) {}
        _isPublishing = false;
        try {
          if (_localViewId != null || localView != null) {
            await ZegoExpressEngine.instance.stopPreview();
          }
        } catch (_) {}
        try {
          await _stopRemotePlayback();
        } catch (_) {}
        try {
          if (_isZegoConnected) {
            await ZegoExpressEngine.instance.logoutRoom(roomName);
          }
        } catch (_) {}
      }
      _isPublishing = false;
      _isZegoConnected = false;
      await _destroyCanvasViews();
      await _resetZegoEngine(clearCallbacks: true);
    } finally {
      _isDisconnecting = false;
    }
  }

  void closeWithoutNativeCleanup() {
    isEnding = true;
    _skipNativeCleanup = true;
    _hasDisconnected = true;
    _isDisconnecting = false;
    _reconnectTimer?.cancel();
    _locationHeartbeatTimer?.cancel();
    _locationSubscription?.cancel();
    _isReconnectScheduled = false;
    _isPublishing = false;
    _isZegoConnected = false;
    _engineReady = false;
    localView = null;
    remoteView = null;
    _localViewId = null;
    _remoteViewId = null;
    _remoteStreamId = null;
    ZegoExpressEngine.onRoomStreamUpdate = null;
    ZegoExpressEngine.onRoomStateChanged = null;
    ZegoExpressEngine.onPublisherStateUpdate = null;
  }

  Future<void> _destroyCanvasViews() async {
    try {
      if (_engineReady && _localViewId != null) {
        await ZegoExpressEngine.instance.destroyCanvasView(_localViewId!);
      }
    } catch (_) {}
    _localViewId = null;
    _remoteViewId = null;
    localView = null;
    remoteView = null;
  }

  Future<void> _resetZegoEngine({bool clearCallbacks = false}) async {
    if (clearCallbacks) {
      ZegoExpressEngine.onRoomStreamUpdate = null;
      ZegoExpressEngine.onRoomStateChanged = null;
      ZegoExpressEngine.onPublisherStateUpdate = null;
    }
    try {
      if (_engineReady) {
        await ZegoExpressEngine.destroyEngine();
      }
    } catch (_) {}
    _engineReady = false;
    _isZegoConnected = false;
  }

  String _safeZegoId(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return cleaned.length <= 120 ? cleaned : cleaned.substring(0, 120);
  }

  Future<void> _sendCurrentLocation({bool force = false}) async {
    if (!_isLocationSharingActive && !force) return;
    try {
      final pos = await locationService.getCurrentLocation();
      if (pos == null) return;
      SignalingService.instance.sendReporterLocation(
        callId: callId,
        latitude: pos.latitude,
        longitude: pos.longitude,
        speed: pos.speed >= 0 ? pos.speed * 3.6 : null,
        heading: pos.heading >= 0 ? pos.heading : null,
        accuracy: pos.accuracy,
      );
    } catch (_) {}
  }

  Future<void> _startLocationSharing() async {
    if (_isLocationSharingActive) return;
    _isLocationSharingActive = true;
    await _sendCurrentLocation(force: true);

    _locationSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
        ).listen((pos) {
          SignalingService.instance.sendReporterLocation(
            callId: callId,
            latitude: pos.latitude,
            longitude: pos.longitude,
            speed: pos.speed >= 0 ? pos.speed * 3.6 : null,
            heading: pos.heading >= 0 ? pos.heading : null,
            accuracy: pos.accuracy,
          );
        });

    _locationHeartbeatTimer = Timer.periodic(
      const Duration(seconds: 10),
      (_) => _sendCurrentLocation(force: true),
    );
  }
}
