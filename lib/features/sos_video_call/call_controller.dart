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

  Timer? _reconnectTimer,
      _locationHeartbeatTimer,
      _remoteRecoveryTimer,
      _remotePlaybackWatchdogTimer,
      _mediaHealthTimer,
      _remoteStreamScanTimer;
  StreamSubscription<Position>? _locationSubscription;
  bool _isLocationSharingActive = false,
      isConnecting = true,
      isEnding = false,
      _isReconnectScheduled = false,
      _isDisconnecting = false,
      _hasDisconnected = false,
      _engineReady = false,
      _skipNativeCleanup = false,
      _remoteFirstFrameRendered = false,
      _remotePlaybackRestartInFlight = false,
      _publishRecoveryInFlight = false;
  bool isMicEnabled = true, isCameraEnabled = true;
  bool _isZegoConnected = false;
  bool _isPublishing = false;
  int _reconnectAttempt = 0;
  String? error;
  String? _publishStreamId, _remoteStreamId;
  String? _activeRoomName;
  late final String _zegoUserId;
  int? _localViewId, _remoteViewId;
  Widget? localView, remoteView;
  final Set<String> _remoteStreamCandidates = <String>{};

  CallController({
    required this.callId,
    required this.roomName,
    required this.startWithCamera,
    this.deferPublishing = false,
    this.deferConnection = false,
    required this.onStateChanged,
  }) {
    isCameraEnabled = startWithCamera;
    _zegoUserId = _safeZegoId('citizen_$callId');
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
    _remoteRecoveryTimer?.cancel();
    _remotePlaybackWatchdogTimer?.cancel();
    _mediaHealthTimer?.cancel();
    _remoteStreamScanTimer?.cancel();
    _locationSubscription?.cancel();
    if (!_skipNativeCleanup) {
      unawaited(disconnect());
    }
  }

  bool get hasRemoteParticipant => remoteView != null;
  bool get hasLocalPreview => localView != null;
  String get _streamRoomName => _activeRoomName ?? roomName;

  bool _isOperatorStream(String streamId) {
    final lower = streamId.toLowerCase();
    return lower.contains('_c3_') ||
        lower.contains('c3_') ||
        lower.contains('operator') ||
        lower.contains('command');
  }

  String _preferredRemoteStreamId(Iterable<String> streamIds) {
    final candidates = streamIds
        .where(
          (streamId) => streamId.isNotEmpty && streamId != _publishStreamId,
        )
        .toList();
    if (candidates.isEmpty) return '';
    candidates.sort((a, b) {
      final aOperator = _isOperatorStream(a);
      final bOperator = _isOperatorStream(b);
      if (aOperator != bOperator) return aOperator ? -1 : 1;
      return a.compareTo(b);
    });
    return candidates.first;
  }

  void _scheduleReconnect({String? reason}) {
    if (_isReconnectScheduled || isEnding) return;
    _isReconnectScheduled = true;
    _reconnectAttempt += 1;
    final delay = _reconnectAttempt < 6 ? _reconnectAttempt * 2 : 12;
    isConnecting = true;
    final cleanReason = reason?.trim();
    error = cleanReason == null || cleanReason.isEmpty
        ? 'Interrupted. Reconnecting in ${delay}s...'
        : '$cleanReason. Reconnecting in ${delay}s...';
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
    error = isReconnect ? 'Reconnecting to AITELLIGENZ room...' : null;
    onStateChanged();

    try {
      final token = await zegoTokenService.createToken(
        callId: callId,
        roomName: roomName,
        userId: _zegoUserId,
        userName: 'Citizen SOS',
      );
      _activeRoomName = token.roomId.isNotEmpty ? token.roomId : roomName;

      await _resetZegoEngine();
      try {
        await ZegoExpressEngine.setLogConfig(
          ZegoLogConfig('', 0, logCount: 3, logLevel: 'disable'),
        );
      } catch (_) {}
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

      await _loginRoomWithTokenCandidates(token);
      _isZegoConnected = true;

      _publishStreamId = token.publishStreamId;
      await ZegoExpressEngine.instance.muteMicrophone(false);
      await ZegoExpressEngine.instance.setAudioRouteToSpeaker(true);
      await ZegoExpressEngine.instance.enableCamera(isCameraEnabled);
      if (isCameraEnabled) {
        await _startLocalPreview();
      }
      if (publishAfterConnect || !deferPublishing) {
        await _startPublishing();
      }
      SignalingService.instance.joinCallRoom(roomName, role: 'reporter');
      if (_activeRoomName != null && _activeRoomName != roomName) {
        SignalingService.instance.joinCallRoom(
          _activeRoomName!,
          role: 'reporter',
        );
      }
      _reconnectAttempt = 0;
      _isReconnectScheduled = false;
      isConnecting = false;
      error = null;
    } catch (e) {
      if (deferPublishing && !publishAfterConnect) {
        debugPrint('[AITELLIGENZ Room] Prep skipped during AI triage: $e');
        await _resetZegoEngine(clearCallbacks: true);
        _isPublishing = false;
        _isReconnectScheduled = false;
        isConnecting = false;
        error = null;
        return;
      }
      final message = _friendlyConnectionError(e);
      error = message;
      _scheduleReconnect(reason: message);
    } finally {
      isConnecting = _isReconnectScheduled;
      onStateChanged();
    }
  }

  Future<void> _loginRoomWithTokenCandidates(ZegoTokenResponse token) async {
    final user = ZegoUser(token.userId, token.userName);
    var lastErrorCode = 0;
    for (var index = 0; index < token.loginTokens.length; index += 1) {
      final config = ZegoRoomConfig.defaultConfig()
        ..token = token.loginTokens[index]
        ..isUserStatusNotify = true;
      final login = await ZegoExpressEngine.instance.loginRoom(
        token.roomId,
        user,
        config: config,
      );
      if (login.errorCode == 0) {
        if (index > 0) {
          debugPrint(
            '[AITELLIGENZ Room] Room login succeeded with fallback access.',
          );
        }
        return;
      }
      lastErrorCode = login.errorCode;
      debugPrint(
        '[AITELLIGENZ Room] Room login failed with access attempt ${index + 1}/${token.loginTokens.length}: ${login.errorCode}',
      );
      try {
        await ZegoExpressEngine.instance.logoutRoom(token.roomId);
      } catch (_) {}
    }
    throw Exception('AITELLIGENZ room login failed ($lastErrorCode).');
  }

  String _friendlyConnectionError(Object error) {
    final raw = error
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceAll(
          RegExp(r'ZEGOCLOUD|ZegoCloud|ZEGO|Zego', caseSensitive: false),
          'AITELLIGENZ room',
        )
        .trim();
    if (raw.isEmpty) return 'Video connection interrupted';
    if (raw.length <= 90) return raw;
    return '${raw.substring(0, 90)}...';
  }

  void _bindZegoCallbacks() {
    ZegoExpressEngine.onRoomStreamUpdate = (roomId, updateType, streamList, _) {
      if (roomId != _streamRoomName) return;
      if (updateType == ZegoUpdateType.Add) {
        for (final stream in streamList) {
          if (stream.streamID == _publishStreamId) {
            continue;
          }
          _remoteStreamCandidates.add(stream.streamID);
          if (_remoteStreamId != null) continue;
          unawaited(_startRemotePlayback(stream.streamID));
          break;
        }
      } else if (updateType == ZegoUpdateType.Delete) {
        for (final stream in streamList) {
          _remoteStreamCandidates.remove(stream.streamID);
          if (stream.streamID == _remoteStreamId) {
            unawaited(_recoverRemotePlaybackAfterDrop(stream.streamID));
          }
        }
      }
    };
    ZegoExpressEngine
        .onRoomStateChanged = (roomId, _, errorCode, extendedData) {
      if (roomId != _streamRoomName || errorCode == 0 || isEnding) return;
      error = 'AITELLIGENZ room warning ($errorCode)';
      debugPrint('[AITELLIGENZ Room] Room warning $errorCode $extendedData');
      onStateChanged();
    };
    ZegoExpressEngine
        .onPublisherStateUpdate = (streamId, state, errorCode, extendedData) {
      if (streamId != _publishStreamId || errorCode == 0 || isEnding) return;
      error = 'AITELLIGENZ room publish warning ($errorCode)';
      debugPrint(
        '[AITELLIGENZ Room] Publish warning $state $errorCode $extendedData',
      );
      unawaited(_restartPublishing(reason: 'publish warning $errorCode'));
      onStateChanged();
    };
    ZegoExpressEngine.onPlayerStateUpdate =
        (streamId, state, errorCode, extendedData) {
          if (streamId != _remoteStreamId || isEnding) return;
          debugPrint(
            '[AITELLIGENZ Room] Player state $state $errorCode $extendedData',
          );
          if (state == ZegoPlayerState.Playing && errorCode == 0) {
            error = null;
            _startRemotePlaybackWatchdog(streamId);
            onStateChanged();
            return;
          }
          if (errorCode != 0 || state == ZegoPlayerState.NoPlay) {
            error = 'AITELLIGENZ room playback warning ($errorCode)';
            unawaited(
              _restartRemotePlayback(
                streamId,
                reason: 'player state $state $errorCode',
              ),
            );
            onStateChanged();
          }
        };
    ZegoExpressEngine.onPlayerRecvVideoFirstFrame = (streamId) {
      if (streamId != _remoteStreamId || isEnding) return;
      _remoteFirstFrameRendered = true;
      error = null;
      _remotePlaybackWatchdogTimer?.cancel();
      onStateChanged();
    };
    ZegoExpressEngine.onPlayerRenderVideoFirstFrame = (streamId) {
      if (streamId != _remoteStreamId || isEnding) return;
      _remoteFirstFrameRendered = true;
      error = null;
      _remotePlaybackWatchdogTimer?.cancel();
      onStateChanged();
    };
  }

  Future<void> _startLocalPreview() async {
    if (!_engineReady || isEnding) return;
    if (_localViewId != null && localView != null) {
      try {
        await ZegoExpressEngine.instance.startPreview(
          canvas: _videoCanvas(_localViewId!),
        );
      } catch (e) {
        debugPrint('[CallController] Could not restart local preview: $e');
      }
      onStateChanged();
      return;
    }

    final widget = await ZegoExpressEngine.instance.createCanvasView((viewId) {
      if (isEnding || !_engineReady) return;
      _localViewId = viewId;
      ZegoExpressEngine.instance.startPreview(canvas: _videoCanvas(viewId));
    });
    if (isEnding || !_engineReady) return;
    localView = widget;
    onStateChanged();
  }

  Future<void> _stopLocalPreview({bool destroyView = true}) async {
    if (!_engineReady) {
      localView = null;
      _localViewId = null;
      onStateChanged();
      return;
    }

    try {
      await ZegoExpressEngine.instance.stopPreview();
    } catch (e) {
      debugPrint('[CallController] Could not stop local preview: $e');
    }

    if (destroyView && _localViewId != null) {
      try {
        await ZegoExpressEngine.instance.destroyCanvasView(_localViewId!);
      } catch (e) {
        debugPrint('[CallController] Could not destroy local preview: $e');
      }
      _localViewId = null;
      localView = null;
    }
    onStateChanged();
  }

  Future<void> _startRemotePlayback(
    String streamId, {
    bool force = false,
  }) async {
    if (!_engineReady || isEnding || streamId == _publishStreamId) return;
    if (!force && _remoteStreamId == streamId && remoteView != null) return;
    if (_remoteStreamId != null && _remoteStreamId != streamId) {
      await _stopRemotePlayback(clearCandidates: false);
    }
    if (force && _remoteStreamId == streamId) {
      await _stopRemotePlayback(clearCandidates: false);
    }
    _remoteFirstFrameRendered = false;
    _remoteStreamId = streamId;
    final widget = await ZegoExpressEngine.instance.createCanvasView((viewId) {
      if (isEnding || !_engineReady) return;
      _remoteViewId = viewId;
      ZegoExpressEngine.instance.startPlayingStream(
        streamId,
        canvas: _videoCanvas(viewId),
      );
    });
    if (isEnding || !_engineReady) return;
    remoteView = widget;
    _startRemotePlaybackWatchdog(streamId);
    onStateChanged();
  }

  Future<void> _stopRemotePlayback({bool clearCandidates = true}) async {
    _remotePlaybackWatchdogTimer?.cancel();
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
    _remoteFirstFrameRendered = false;
    if (clearCandidates) {
      _remoteStreamCandidates.clear();
    }
    onStateChanged();
  }

  void _startRemotePlaybackWatchdog(String streamId) {
    _remotePlaybackWatchdogTimer?.cancel();
    _remotePlaybackWatchdogTimer = Timer(
      const Duration(milliseconds: 2600),
      () {
        if (isEnding || !_engineReady || _remoteStreamId != streamId) return;
        if (_remoteFirstFrameRendered) return;
        unawaited(
          _restartRemotePlayback(
            streamId,
            reason: 'remote video first frame timeout',
          ),
        );
      },
    );
  }

  Future<void> _restartRemotePlayback(
    String streamId, {
    required String reason,
  }) async {
    if (_remotePlaybackRestartInFlight ||
        !_engineReady ||
        !_isZegoConnected ||
        isEnding ||
        streamId.isEmpty ||
        streamId == _publishStreamId) {
      return;
    }
    _remotePlaybackRestartInFlight = true;
    try {
      debugPrint('[CallController] Restarting remote playback: $reason');
      await _startRemotePlayback(streamId, force: true);
    } catch (e) {
      debugPrint('[CallController] Remote playback restart failed: $e');
    } finally {
      _remotePlaybackRestartInFlight = false;
    }
  }

  Future<void> _recoverRemotePlaybackAfterDrop(String droppedStreamId) async {
    await _stopRemotePlayback(clearCandidates: false);
    if (isEnding || !_engineReady) return;

    final fallbackStreamId = _remoteStreamCandidates.firstWhere(
      (streamId) => streamId != droppedStreamId && streamId != _publishStreamId,
      orElse: () => '',
    );
    if (fallbackStreamId.isNotEmpty) {
      await _startRemotePlayback(fallbackStreamId);
      return;
    }

    _remoteRecoveryTimer?.cancel();
    _remoteRecoveryTimer = Timer(const Duration(milliseconds: 900), () {
      if (isEnding || !_engineReady || _remoteStreamId != null) return;
      final nextStreamId = _preferredRemoteStreamId(_remoteStreamCandidates);
      if (nextStreamId.isNotEmpty) {
        unawaited(_startRemotePlayback(nextStreamId));
      } else {
        unawaited(_scanKnownRemoteStreams());
        onStateChanged();
      }
    });
  }

  void _startMediaHealthChecks() {
    _mediaHealthTimer?.cancel();
    _remoteStreamScanTimer?.cancel();

    _mediaHealthTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (isEnding || !_engineReady || !_isZegoConnected) return;
      unawaited(_ensureLocalMediaHealthy());
    });

    _remoteStreamScanTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (isEnding || !_engineReady || !_isZegoConnected) return;
      if (_remoteStreamId == null ||
          remoteView == null ||
          !_remoteFirstFrameRendered) {
        unawaited(_scanKnownRemoteStreams());
      }
    });
  }

  Future<void> _scanKnownRemoteStreams() async {
    if (!_engineReady || !_isZegoConnected || isEnding) return;
    try {
      final result = await ZegoExpressEngine.instance.getRoomStreamList(
        _streamRoomName,
        ZegoRoomStreamListType.Play,
      );
      for (final stream in result.playStreamList) {
        final streamId = stream.streamID;
        if (streamId.isEmpty || streamId == _publishStreamId) continue;
        _remoteStreamCandidates.add(streamId);
      }
      final streamId = _preferredRemoteStreamId(_remoteStreamCandidates);
      if (streamId.isEmpty) return;
      if (_remoteStreamId != streamId || remoteView == null) {
        await _startRemotePlayback(streamId);
      } else if (!_remoteFirstFrameRendered) {
        await _restartRemotePlayback(
          streamId,
          reason: 'known stream scan found blank playback',
        );
      }
    } catch (e) {
      debugPrint('[CallController] Remote stream scan failed: $e');
    }
  }

  Future<void> _ensureLocalMediaHealthy() async {
    if (!_engineReady || !_isZegoConnected || isEnding) return;
    if (_publishStreamId == null) return;

    if (isCameraEnabled) {
      try {
        await ZegoExpressEngine.instance.enableCamera(true);
      } catch (e) {
        debugPrint('[CallController] Could not keep camera enabled: $e');
      }
      if (localView == null || _localViewId == null) {
        await _startLocalPreview();
      } else {
        try {
          await ZegoExpressEngine.instance.startPreview(
            canvas: _videoCanvas(_localViewId!),
          );
        } catch (e) {
          debugPrint(
            '[CallController] Local preview health restart failed: $e',
          );
        }
      }
    }

    if (!_isPublishing) {
      await _restartPublishing(reason: 'publish health check');
    }
  }

  Future<void> pausePublishingForAiTriage() async {
    _mediaHealthTimer?.cancel();
    _mediaHealthTimer = null;
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
    await _restartPublishing(reason: 'AI triage finished');
  }

  Future<void> _startPublishing() async {
    if (!_engineReady ||
        !_isZegoConnected ||
        _publishStreamId == null ||
        _isPublishing ||
        isEnding) {
      return;
    }
    if (isCameraEnabled) {
      try {
        await ZegoExpressEngine.instance.enableCamera(true);
        await _startLocalPreview();
      } catch (e) {
        debugPrint(
          '[CallController] Could not prepare camera before publish: $e',
        );
      }
    }
    await ZegoExpressEngine.instance.startPublishingStream(_publishStreamId!);
    _isPublishing = true;
    _startMediaHealthChecks();
  }

  Future<void> _restartPublishing({String reason = 'media recovery'}) async {
    if (_publishRecoveryInFlight || isEnding) return;
    if (!_engineReady || !_isZegoConnected || _publishStreamId == null) return;
    _publishRecoveryInFlight = true;
    try {
      debugPrint('[CallController] Restarting publish stream: $reason');
      try {
        await ZegoExpressEngine.instance.stopPublishingStream();
      } catch (_) {}
      _isPublishing = false;
      await ZegoExpressEngine.instance.muteMicrophone(!isMicEnabled);
      await ZegoExpressEngine.instance.setAudioRouteToSpeaker(true);
      if (isCameraEnabled) {
        await ZegoExpressEngine.instance.enableCamera(true);
        await _startLocalPreview();
      }
      await ZegoExpressEngine.instance.startPublishingStream(_publishStreamId!);
      _isPublishing = true;
      error = null;
      _startMediaHealthChecks();
    } catch (e) {
      error = _friendlyConnectionError(e);
      debugPrint('[CallController] Publish restart failed: $e');
    } finally {
      _publishRecoveryInFlight = false;
      onStateChanged();
    }
  }

  ZegoCanvas _videoCanvas(int viewId) {
    return ZegoCanvas(
      viewId,
      viewMode: ZegoViewMode.AspectFit,
      backgroundColor: 0x000000,
      alphaBlend: false,
      rotation: 0,
      mirror: false,
    );
  }

  Future<void> toggleMicrophone() async {
    isMicEnabled = !isMicEnabled;
    if (_isZegoConnected) {
      await ZegoExpressEngine.instance.muteMicrophone(!isMicEnabled);
    }
    onStateChanged();
  }

  Future<void> setSpeakerEnabled(bool enabled) async {
    if (!_engineReady || isEnding) return;
    try {
      await ZegoExpressEngine.instance.setAudioRouteToSpeaker(enabled);
    } catch (e) {
      debugPrint('[CallController] Could not set speaker=$enabled: $e');
    }
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
    if (_isZegoConnected && _engineReady) {
      await ZegoExpressEngine.instance.enableCamera(isCameraEnabled);
      if (isCameraEnabled) {
        await _startLocalPreview();
      } else {
        await _stopLocalPreview();
      }
    }
    onStateChanged();
  }

  Future<void> ensureCameraEnabled() async {
    var changed = false;
    if (!isCameraEnabled) {
      isCameraEnabled = true;
      changed = true;
    }
    if (_isZegoConnected && _engineReady) {
      await ZegoExpressEngine.instance.enableCamera(true);
      await _startLocalPreview();
      if (!_isPublishing) {
        await _restartPublishing(reason: 'camera enabled');
      }
    }
    if (changed) onStateChanged();
  }

  Future<void> recoverLocalPreview() async {
    if (isEnding) return;
    if (!isCameraEnabled) {
      await toggleCamera();
      return;
    }
    if (!_isZegoConnected || !_engineReady) {
      onStateChanged();
      return;
    }
    await _stopLocalPreview();
    await ZegoExpressEngine.instance.enableCamera(true);
    await _startLocalPreview();
    await _restartPublishing(reason: 'local preview recovered');
  }

  Future<void> recoverVideoSurfaces() async {
    if (isEnding) return;
    if (isEnding || !_engineReady || !_isZegoConnected) return;
    await _scanKnownRemoteStreams();
    if (isEnding || remoteView != null) return;
    final streamId = _preferredRemoteStreamId(_remoteStreamCandidates);
    if (streamId.isNotEmpty) {
      await _startRemotePlayback(streamId);
    } else {
      _remoteRecoveryTimer?.cancel();
      _remoteRecoveryTimer = Timer(const Duration(milliseconds: 700), () {
        if (isEnding || !_engineReady || !_isZegoConnected) return;
        unawaited(_scanKnownRemoteStreams());
      });
      onStateChanged();
    }
  }

  Future<void> disconnect() async {
    if (_isDisconnecting || _hasDisconnected) return;
    _isDisconnecting = true;
    _hasDisconnected = true;
    _reconnectTimer?.cancel();
    _remoteRecoveryTimer?.cancel();
    _remotePlaybackWatchdogTimer?.cancel();
    _mediaHealthTimer?.cancel();
    _remoteStreamScanTimer?.cancel();
    _isReconnectScheduled = false;
    try {
      if (_engineReady) {
        try {
          if (_isPublishing && _publishStreamId != null) {
            await ZegoExpressEngine.instance.stopPublishingStream();
          }
        } catch (_) {}
        _isPublishing = false;
        await _stopLocalPreview();
        try {
          await _stopRemotePlayback();
        } catch (_) {}
        try {
          if (_isZegoConnected) {
            await ZegoExpressEngine.instance.logoutRoom(_streamRoomName);
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
    _remoteRecoveryTimer?.cancel();
    _remotePlaybackWatchdogTimer?.cancel();
    _mediaHealthTimer?.cancel();
    _remoteStreamScanTimer?.cancel();
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
    _remoteFirstFrameRendered = false;
    _activeRoomName = null;
    _remoteStreamCandidates.clear();
    ZegoExpressEngine.onRoomStreamUpdate = null;
    ZegoExpressEngine.onRoomStateChanged = null;
    ZegoExpressEngine.onPublisherStateUpdate = null;
    ZegoExpressEngine.onPlayerStateUpdate = null;
    ZegoExpressEngine.onPlayerRecvVideoFirstFrame = null;
    ZegoExpressEngine.onPlayerRenderVideoFirstFrame = null;
  }

  Future<void> _destroyCanvasViews() async {
    try {
      if (_engineReady && _localViewId != null) {
        await ZegoExpressEngine.instance.destroyCanvasView(_localViewId!);
      }
    } catch (_) {}
    try {
      if (_engineReady && _remoteViewId != null) {
        await ZegoExpressEngine.instance.destroyCanvasView(_remoteViewId!);
      }
    } catch (_) {}
    _localViewId = null;
    _remoteViewId = null;
    localView = null;
    remoteView = null;
    _remoteFirstFrameRendered = false;
    _remoteStreamCandidates.clear();
  }

  Future<void> _resetZegoEngine({bool clearCallbacks = false}) async {
    if (clearCallbacks) {
      ZegoExpressEngine.onRoomStreamUpdate = null;
      ZegoExpressEngine.onRoomStateChanged = null;
      ZegoExpressEngine.onPublisherStateUpdate = null;
      ZegoExpressEngine.onPlayerStateUpdate = null;
      ZegoExpressEngine.onPlayerRecvVideoFirstFrame = null;
      ZegoExpressEngine.onPlayerRenderVideoFirstFrame = null;
    }
    try {
      if (_engineReady) {
        await ZegoExpressEngine.destroyEngine();
      }
    } catch (_) {}
    _engineReady = false;
    _isZegoConnected = false;
    _activeRoomName = null;
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

  Future<void> shareCurrentLocationNow() async {
    await _sendCurrentLocation(force: true);
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
