import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:konektizen/core/config/environment.dart';
import 'package:konektizen/core/router/router.dart';
import 'package:konektizen/features/sos_video_call/command_center_call_screen.dart';

class SignalingService with WidgetsBindingObserver {
  static const String _defaultC3BusyMessage =
      'C3 is busy right now. Please try again shortly.';

  // Singleton Pattern
  static final SignalingService instance = SignalingService._internal();
  factory SignalingService() => instance;
  SignalingService._internal();

  io.Socket? socket;
  Function(Map<String, dynamic>)? onCallDeclined;
  void Function(Map<String, dynamic>)? onCallEnded;
  void Function(Map<String, dynamic>)? onCaseUpdated;
  String? _activeAcceptedCallId;
  Map<String, dynamic>? _activeAcceptedCallPayload;
  String? _pendingIncomingCallRoom;
  BuildContext? _pendingIncomingCallDialogContext;
  Timer? _incomingRingTimer;
  bool _incomingRingActive = false;
  bool _callScreenVisible = false;
  bool _lifecycleObserverAttached = false;

  // C3 Command Center URL. Read dynamically so Settings changes apply before
  // the next socket connection without rebuilding the app.
  String get _serverUrl => EnvironmentConfig.signalingUrl;

  String? _userId;
  String? get currentReporterId => _userId;

  String _extractDeclineMessage(Map<String, dynamic> payload) {
    final explicit = payload['message']?.toString().trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }

    final reason = payload['reason']?.toString();
    final endedBy =
        payload['ended_by']?.toString() ?? payload['endedBy']?.toString();
    if (reason == 'c3_busy') {
      return _defaultC3BusyMessage;
    }
    if (endedBy == 'c3') {
      return 'Call ended by the command center.';
    }
    return 'Call ended.';
  }

  void _showDismissMessage(String message) {
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;

    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.hideCurrentSnackBar();
    messenger?.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _startIncomingRing() {
    _incomingRingTimer?.cancel();
    _incomingRingActive = true;

    void playAlert() {
      if (!_incomingRingActive) return;
      unawaited(SystemSound.play(SystemSoundType.alert));
      unawaited(HapticFeedback.mediumImpact());
    }

    playAlert();
    _incomingRingTimer = Timer.periodic(
      const Duration(milliseconds: 1300),
      (_) => playAlert(),
    );
  }

  void _stopIncomingRing() {
    _incomingRingActive = false;
    _incomingRingTimer?.cancel();
    _incomingRingTimer = null;
  }

  void _attachLifecycleObserver() {
    if (_lifecycleObserverAttached) return;
    WidgetsBinding.instance.addObserver(this);
    _lifecycleObserverAttached = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      Future.delayed(const Duration(milliseconds: 350), () {
        restoreActiveCallScreenIfNeeded();
      });
    }
  }

  bool _payloadMatchesActiveCall(Map<String, dynamic> payload) {
    final room =
        payload['room_name']?.toString() ??
        payload['roomName']?.toString() ??
        payload['room']?.toString() ??
        payload['callId']?.toString() ??
        payload['call_id']?.toString() ??
        payload['id']?.toString();
    if (room == null || room.isEmpty) return false;
    return _callAliasesFor(
          _activeAcceptedCallId,
        ).any(_callAliasesFor(room).contains) ||
        _callAliasesFor(
          _activeAcceptedCallPayload?['callId']?.toString() ??
              _activeAcceptedCallPayload?['call_id']?.toString(),
        ).any(_callAliasesFor(room).contains);
  }

  bool _payloadMatchesPendingIncomingCall(Map<String, dynamic> payload) {
    final pendingRoom = _pendingIncomingCallRoom;
    if (pendingRoom == null || pendingRoom.isEmpty) return false;
    final room =
        payload['room_name']?.toString() ??
        payload['roomName']?.toString() ??
        payload['room']?.toString() ??
        payload['callId']?.toString() ??
        payload['call_id']?.toString() ??
        payload['id']?.toString();
    if (room == null || room.isEmpty) return false;
    return _callAliasesFor(pendingRoom).any(_callAliasesFor(room).contains);
  }

  void _dismissPendingIncomingCallIfMatches(Map<String, dynamic> payload) {
    if (!_payloadMatchesPendingIncomingCall(payload)) return;
    final dialogContext = _pendingIncomingCallDialogContext;
    _pendingIncomingCallRoom = null;
    _pendingIncomingCallDialogContext = null;
    _stopIncomingRing();
    if (dialogContext != null) {
      try {
        Navigator.of(dialogContext, rootNavigator: true).pop(false);
      } catch (_) {}
    }
  }

  bool _isPayloadForCurrentReporter(
    Map<String, dynamic> payload, {
    bool allowMissingReporter = true,
    bool allowActiveCallMatch = true,
  }) {
    final reporterId =
        payload['reporter_id']?.toString() ??
        payload['reporterId']?.toString() ??
        payload['target_user_id']?.toString() ??
        payload['targetUserId']?.toString() ??
        payload['userId']?.toString();
    if (reporterId != null && _userId != null && reporterId != _userId) {
      return false;
    }
    if (reporterId != null || _userId == null) return true;
    if (allowActiveCallMatch && _payloadMatchesActiveCall(payload)) {
      return true;
    }
    return allowMissingReporter;
  }

  Set<String> _callAliasesFor(String? room) {
    final raw = room?.trim();
    if (raw == null || raw.isEmpty) return {};
    final clean = raw.startsWith('call_') ? raw.substring(5) : raw;
    return {raw, clean, 'call_$clean'};
  }

  // Global listener for incoming calls from Command Center
  void listenForIncomingCall(String userId) {
    debugPrint(
      '[Signaling] ========== SETTING UP INCOMING CALL LISTENER ==========',
    );
    debugPrint('[Signaling] User ID: $userId');
    _userId = userId;
    _attachLifecycleObserver();

    // Connect (or reconnect if ID changed)
    connectToSocket();

    // Listen for ALL events for debugging
    socket!.onAny((event, data) {
      debugPrint('[Signaling] RECEIVED EVENT: $event');
      debugPrint('[Signaling] EVENT DATA: $data');
    });
    socket!.off('call_accepted');
    socket!.off('operator_accepted_sos');
    socket!.off('ai_caller_started');
    socket!.off('c3_sos_ack');
    socket!.off('call_declined');
    socket!.off('sos_dismissed');
    socket!.off('end-call');
    socket!.off('call_ended');
    socket!.off('incoming_call');
    socket!.off('case_updated');

    socket!.on('case_updated', (data) {
      debugPrint('[Signaling] case_updated event received: $data');
      final payload = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      onCaseUpdated?.call(payload);
    });

    socket!.on('incoming_call', (data) {
      final payload = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      if (!_isPayloadForCurrentReporter(
        payload,
        allowMissingReporter: false,
        allowActiveCallMatch: false,
      )) {
        return;
      }
      _handleIncomingCommandCenterCall(payload);
    });

    void openAcceptedCall(dynamic data, {bool requireReporterMatch = false}) {
      final payload = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};

      if (requireReporterMatch) {
        final reporterId =
            payload['reporter_id']?.toString() ??
            payload['reporterId']?.toString();
        if (reporterId == null || reporterId != _userId) {
          debugPrint('[Signaling] Ignoring SOS ack for reporter: $reporterId');
          return;
        }
      } else if (!_isPayloadForCurrentReporter(
        payload,
        allowMissingReporter: false,
      )) {
        debugPrint('[Signaling] Ignoring accepted call for another room.');
        return;
      }

      debugPrint('[Signaling] CALL ACCEPTED RECEIVED');
      debugPrint('[Signaling] Call Data: $payload');

      _openCallScreenFromPayload(payload);
    }

    // C3 Spec: Listen for call_accepted (from accept_sos flow)
    socket!.on('call_accepted', (data) {
      openAcceptedCall(data);
    });

    socket!.on('operator_accepted_sos', (data) {
      openAcceptedCall(data);
    });

    socket!.on('ai_caller_started', (data) {
      final payload = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      if (!_isPayloadForCurrentReporter(payload)) return;
      openAcceptedCall({
        ...payload,
        'operatorName': 'AIGOR',
        'operator_name': 'AIGOR',
        'type': 'video',
        'callType': 'video',
        'video_provider': payload['video_provider'] ?? 'zego',
        'videoProvider': payload['videoProvider'] ?? 'zego',
      });
    });

    void handleEnded(dynamic data) {
      final payload = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      if (!_isPayloadForCurrentReporter(payload, allowMissingReporter: false)) {
        return;
      }
      final message = _extractDeclineMessage(payload);
      final enriched = <String, dynamic>{...payload, 'message': message};
      _markPayloadCallEnded(payload);
      _dismissPendingIncomingCallIfMatches(payload);
      debugPrint('[Signaling] SOS call ended: $enriched');
      onCallEnded?.call(enriched);
      _showDismissMessage(message);
    }

    // Fallback: some devices receive the global accepted ACK before/more reliably
    // than the targeted reporter-room call_accepted event.
    socket!.on('c3_sos_ack', (data) {
      final payload = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final action = payload['action']?.toString();
      if (action != 'accepted') {
        if (action == 'declined' ||
            action == 'dismissed' ||
            action == 'ended' ||
            action == 'resolved') {
          handleEnded(payload);
        }
        return;
      }
      openAcceptedCall(payload, requireReporterMatch: true);
    });

    void handleDeclined(dynamic data) {
      final payload = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      if (!_isPayloadForCurrentReporter(payload, allowMissingReporter: false)) {
        return;
      }
      final message = _extractDeclineMessage(payload);
      final enriched = <String, dynamic>{...payload, 'message': message};
      _markPayloadCallEnded(payload);
      _dismissPendingIncomingCallIfMatches(payload);
      debugPrint('[Signaling] SOS dismissed by C3: $enriched');
      onCallDeclined?.call(enriched);
      onCallEnded?.call(enriched);
      _showDismissMessage(message);
    }

    socket!.on('call_declined', handleDeclined);
    socket!.on('sos_dismissed', handleDeclined);
    socket!.on('end-call', handleEnded);
    socket!.on('call_ended', handleEnded);
  }

  void connectToSocket() {
    // Disconnect any existing socket first
    if (socket != null) {
      socket!.dispose();
      socket = null;
    }

    debugPrint('[Signaling] Connecting to C3 Socket: $_serverUrl');

    // Flutter socket_io_client uses the native WebSocket path on Android/iOS.
    // C3 must run Flask-SocketIO with eventlet so this can connect cleanly.
    socket = io.io(
      _serverUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setPath('/socket.io')
          .enableAutoConnect()
          .enableReconnection()
          .setReconnectionAttempts(999999)
          .setReconnectionDelay(1000)
          .setReconnectionDelayMax(5000)
          .setTimeout(20000)
          .enableForceNew()
          .build(),
    );

    socket!.onConnect((_) {
      debugPrint('[Signaling] ========================================');
      debugPrint('[Signaling] CONNECTED');
      debugPrint('[Signaling] Socket ID: ${socket!.id}');

      // ALIGNMENT: Emit join_reporter immediately on connect/reconnect
      if (_userId != null) {
        debugPrint('[Signaling] Auto-joining reporter room: reporter_$_userId');
        socket!.emit('join_reporter', {'reporter_id': _userId});
      }
      if (_activeAcceptedCallId != null) {
        joinCallRoom(_activeAcceptedCallId!, role: 'reporter');
      }
      debugPrint('[Signaling] ========================================');
    });

    socket!.onDisconnect((reason) {
      debugPrint('[Signaling] DISCONNECTED');
      debugPrint('[Signaling] Reason: $reason');
    });

    socket!.onConnectError((error) {
      debugPrint('[Signaling] CONNECT ERROR');
      debugPrint('[Signaling] Error: $error');
    });
  }

  void endCall(String room) {
    final payload = {
      'room': room,
      'call_id': room,
      'callId': room,
      'ended_by': 'reporter',
    };
    socket?.emit('end-call', payload);
    socket?.emit('call_ended', payload);
    if (_activeAcceptedCallId == room) {
      _activeAcceptedCallId = null;
      _activeAcceptedCallPayload = null;
      _callScreenVisible = false;
    }
  }

  void joinCallRoom(String room, {String role = 'reporter'}) {
    if (socket == null || !(socket!.connected)) {
      return;
    }
    socket!.emit('join-call', {
      'room': room,
      'callId': room,
      'call_id': room,
      'role': role,
      if (_userId != null) 'reporter_id': _userId,
    });
  }

  void markCallActive(String room) {
    _activeAcceptedCallId = room;
  }

  void rememberActiveCall({
    required String room,
    required String callId,
    String? operatorName,
    String? aiCallerSessionId,
  }) {
    _attachLifecycleObserver();
    _activeAcceptedCallId = room;
    _activeAcceptedCallPayload = {
      'room': room,
      'room_name': room,
      'roomName': room,
      'call_id': callId,
      'callId': callId,
      if (operatorName != null) 'operatorName': operatorName,
      if (aiCallerSessionId != null) 'ai_caller_session_id': aiCallerSessionId,
      if (aiCallerSessionId != null) 'aiCallerSessionId': aiCallerSessionId,
    };
  }

  void markCallScreenVisible(String room, bool visible) {
    if (_activeAcceptedCallId == room) {
      _callScreenVisible = visible;
    }
  }

  bool isCallScreenVisibleFor(String room) {
    return _callScreenVisible &&
        _callAliasesFor(_activeAcceptedCallId).contains(room);
  }

  void markCallEnded(String room) {
    if (_callAliasesFor(_activeAcceptedCallId).contains(room)) {
      _activeAcceptedCallId = null;
      _activeAcceptedCallPayload = null;
      _callScreenVisible = false;
    }
    _stopIncomingRing();
  }

  void _markPayloadCallEnded(Map<String, dynamic> payload) {
    final room =
        payload['room_name']?.toString() ??
        payload['roomName']?.toString() ??
        payload['room']?.toString() ??
        payload['callId']?.toString() ??
        payload['call_id']?.toString();
    if (room == null || room.isEmpty) return;
    markCallEnded(room);
  }

  void restoreActiveCallScreenIfNeeded() {
    final payload = _activeAcceptedCallPayload;
    if (payload == null ||
        _activeAcceptedCallId == null ||
        _callScreenVisible) {
      return;
    }
    _openCallScreenFromPayload(payload, force: true);
  }

  Future<void> _handleIncomingCommandCenterCall(
    Map<String, dynamic> payload,
  ) async {
    final context = rootNavigatorKey.currentContext;
    if (context == null) {
      debugPrint(
        '[Signaling] No context for incoming C3 call; opening directly.',
      );
      _openCallScreenFromPayload(payload);
      return;
    }

    final callId =
        payload['callId']?.toString() ??
        payload['call_id']?.toString() ??
        payload['room']?.toString() ??
        'incoming';
    final room =
        payload['room_name']?.toString() ??
        payload['roomName']?.toString() ??
        payload['room']?.toString() ??
        (callId.startsWith('call_') || callId.startsWith('sos_')
            ? callId
            : 'call_$callId');
    if (_callAliasesFor(_activeAcceptedCallId).contains(room) &&
        _callScreenVisible) {
      debugPrint('[Signaling] Incoming C3 call ignored; screen already open.');
      return;
    }

    final operatorName =
        payload['operatorName']?.toString() ??
        payload['operator_name']?.toString() ??
        'C3 Command Center';

    _pendingIncomingCallRoom = room;
    _startIncomingRing();
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        _pendingIncomingCallDialogContext = dialogContext;
        return AlertDialog(
          backgroundColor: const Color(0xFF0F172A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Incoming C3 Call',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
          ),
          content: Text(
            '$operatorName is calling about your emergency report.',
            style: const TextStyle(color: Color(0xFFCBD5E1)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text(
                'Decline',
                style: TextStyle(color: Color(0xFFF87171)),
              ),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.video_call),
              label: const Text('Answer'),
            ),
          ],
        );
      },
    );
    _pendingIncomingCallRoom = null;
    _pendingIncomingCallDialogContext = null;
    _stopIncomingRing();

    if (accepted == true) {
      socket?.emit('call_accepted', {
        ...payload,
        'room': room,
        'room_name': room,
        'roomName': room,
        'call_id': callId,
        'callId': callId,
        if (_userId != null) 'reporter_id': _userId,
      });
      _openCallScreenFromPayload({
        ...payload,
        'room': room,
        'room_name': room,
        'roomName': room,
        'call_id': callId,
        'callId': callId,
        'operatorName': operatorName,
      });
      return;
    }

    socket?.emit('end-call', {
      ...payload,
      'room': room,
      'call_id': callId,
      'callId': callId,
      'ended_by': 'reporter',
      if (_userId != null) 'reporter_id': _userId,
    });
  }

  void _openCallScreenFromPayload(
    Map<String, dynamic> payload, {
    bool force = false,
  }) {
    _stopIncomingRing();

    final callId =
        payload['callId']?.toString() ??
        payload['call_id']?.toString() ??
        payload['room']?.toString() ??
        'incoming';
    final room =
        payload['room_name']?.toString() ??
        payload['roomName']?.toString() ??
        payload['room']?.toString() ??
        (callId.startsWith('call_') || callId.startsWith('sos_')
            ? callId
            : 'call_$callId');
    final operatorName =
        payload['operatorName']?.toString() ??
        payload['operator_name']?.toString() ??
        payload['assignedOperatorName']?.toString() ??
        payload['assigned_operator_name']?.toString() ??
        'Command Center SOS';
    final aiCallerSessionId =
        payload['ai_caller_session_id']?.toString() ??
        payload['aiCallerSessionId']?.toString() ??
        payload['session_id']?.toString() ??
        payload['sessionId']?.toString();

    if (!force && _activeAcceptedCallId == room && _callScreenVisible) {
      debugPrint('[Signaling] Call screen already open for room: $room');
      return;
    }

    _activeAcceptedCallId = room;
    _activeAcceptedCallPayload = {
      ...payload,
      'room': room,
      'room_name': room,
      'roomName': room,
      'call_id': callId,
      'callId': callId,
      'operatorName': operatorName,
      if (aiCallerSessionId != null) 'ai_caller_session_id': aiCallerSessionId,
      if (aiCallerSessionId != null) 'aiCallerSessionId': aiCallerSessionId,
    };
    joinCallRoom(room, role: 'reporter');

    debugPrint('[Signaling] Parsed callId: $callId');
    debugPrint('[Signaling] Parsed room: $room');

    final navigator = rootNavigatorKey.currentState;
    if (navigator != null) {
      _callScreenVisible = true;
      navigator.push(
        MaterialPageRoute(
          builder: (_) => CommandCenterCallScreen(
            callId: callId,
            roomName: room,
            operatorName: operatorName,
            aiCallerSessionId: aiCallerSessionId,
          ),
        ),
      );
    }
  }

  void sendReporterLocation({
    required String callId,
    required double latitude,
    required double longitude,
    double? speed,
    double? heading,
    double? accuracy,
  }) {
    if (socket == null || !(socket!.connected)) {
      return;
    }

    socket!.emit('reporter_location_update', {
      'call_id': callId,
      'reporter_id': _userId,
      'latitude': latitude,
      'longitude': longitude,
      if (speed != null) 'speed': speed,
      if (heading != null) 'heading': heading,
      if (accuracy != null) 'accuracy': accuracy,
      'updated': DateTime.now().toIso8601String(),
    });
  }

  void dispose() {
    debugPrint('[Signaling] Disposing socket connection');
    _stopIncomingRing();
    if (_lifecycleObserverAttached) {
      WidgetsBinding.instance.removeObserver(this);
      _lifecycleObserverAttached = false;
    }
    if (socket != null) {
      _activeAcceptedCallId = null;
      _activeAcceptedCallPayload = null;
      _callScreenVisible = false;
      socket!.disconnect();
      socket!.dispose();
      socket = null;
    }
  }
}
