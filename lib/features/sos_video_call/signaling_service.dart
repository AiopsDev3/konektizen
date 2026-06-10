import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:konektizen/core/config/environment.dart';
import 'package:konektizen/core/router/router.dart';
import 'package:konektizen/features/sos_video_call/command_center_call_screen.dart';

class SignalingService {
  static const String _defaultC3BusyMessage =
      'C3 is busy right now. Please try again shortly.';

  // Singleton Pattern
  static final SignalingService instance = SignalingService._internal();
  factory SignalingService() => instance;
  SignalingService._internal();

  IO.Socket? socket;
  Function(Map<String, dynamic>)? onCallDeclined;
  String? _activeAcceptedCallId;

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
    if (reason == 'c3_busy' || endedBy == 'c3') {
      return _defaultC3BusyMessage;
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

  // Global listener for incoming calls from Command Center
  void listenForIncomingCall(String userId) {
    print(
      '[Signaling] ========== SETTING UP INCOMING CALL LISTENER ==========',
    );
    print('[Signaling] User ID: $userId');
    _userId = userId;

    // Connect (or reconnect if ID changed)
    connectToSocket();

    // Listen for ALL events for debugging
    socket!.onAny((event, data) {
      print('[Signaling] 📨 RECEIVED EVENT: $event');
      print('[Signaling] 📦 EVENT DATA: $data');
    });
    socket!.off('call_accepted');
    socket!.off('c3_sos_ack');
    socket!.off('call_declined');
    socket!.off('sos_dismissed');

    void openAcceptedCall(dynamic data, {bool requireReporterMatch = false}) {
      final payload = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};

      if (requireReporterMatch) {
        final reporterId =
            payload['reporter_id']?.toString() ??
            payload['reporterId']?.toString();
        if (reporterId == null || reporterId != _userId) {
          print('[Signaling] Ignoring SOS ack for reporter: $reporterId');
          return;
        }
      }

      print('[Signaling] 🔔 ========== CALL ACCEPTED RECEIVED ==========');
      print('[Signaling] Call Data: $payload');

      // Extract callId and operatorName from C3 payload
      final callId =
          payload['callId']?.toString() ??
          payload['call_id']?.toString() ??
          payload['room']?.toString() ??
          "incoming";
      final room = payload['room']?.toString() ?? callId;
      final operatorName =
          payload['operatorName']?.toString() ?? "Command Center SOS";

      if (_activeAcceptedCallId == room) {
        print('[Signaling] Call screen already open for room: $room');
        return;
      }
      _activeAcceptedCallId = room;

      print('[Signaling] Parsed callId: $callId');
      print('[Signaling] Parsed room: $room');

      if (rootNavigatorKey.currentState != null) {
        rootNavigatorKey.currentState!.push(
          MaterialPageRoute(
            builder: (_) => CommandCenterCallScreen(
              callId: room,
              operatorName: operatorName,
            ),
          ),
        );
      }
    }

    // C3 Spec: Listen for call_accepted (from accept_sos flow)
    socket!.on('call_accepted', (data) {
      openAcceptedCall(data);
    });

    // Fallback: some devices receive the global accepted ACK before/more reliably
    // than the targeted reporter-room call_accepted event.
    socket!.on('c3_sos_ack', (data) {
      final payload = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      if (payload['action']?.toString() != 'accepted') return;
      openAcceptedCall(payload, requireReporterMatch: true);
    });

    void handleDeclined(dynamic data) {
      final payload = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
      final message = _extractDeclineMessage(payload);
      final enriched = <String, dynamic>{...payload, 'message': message};
      print('[Signaling] SOS dismissed by C3: $enriched');
      onCallDeclined?.call(enriched);
      _showDismissMessage(message);
    }

    socket!.on('call_declined', handleDeclined);
    socket!.on('sos_dismissed', handleDeclined);
  }

  void connectToSocket() {
    // Disconnect any existing socket first
    if (socket != null) {
      socket!.dispose();
      socket = null;
    }

    print('[Signaling] Connecting to C3 Socket: $_serverUrl');

    // Flutter socket_io_client uses the native WebSocket path on Android/iOS.
    // C3 must run Flask-SocketIO with eventlet so this can connect cleanly.
    socket = IO.io(
      _serverUrl,
      IO.OptionBuilder()
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
      print('[Signaling] ========================================');
      print('[Signaling] ✅ CONNECTED');
      print('[Signaling] Socket ID: ${socket!.id}');

      // ALIGNMENT: Emit join_reporter immediately on connect/reconnect
      if (_userId != null) {
        print('[Signaling] Auto-joining reporter room: reporter_$_userId');
        socket!.emit('join_reporter', {'reporter_id': _userId});
      }
      print('[Signaling] ========================================');
    });

    socket!.onDisconnect((reason) {
      print('[Signaling] ⚠️ DISCONNECTED');
      print('[Signaling] Reason: $reason');
    });

    socket!.onConnectError((error) {
      print('[Signaling] ❌ CONNECT ERROR');
      print('[Signaling] Error: $error');
    });
  }

  void endCall(String room) {
    socket?.emit('call_ended', {'room': room, 'call_id': room});
    if (_activeAcceptedCallId == room) {
      _activeAcceptedCallId = null;
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
    print('[Signaling] Disposing socket connection');
    if (socket != null) {
      _activeAcceptedCallId = null;
      socket!.disconnect();
      socket!.dispose();
      socket = null;
    }
  }
}
