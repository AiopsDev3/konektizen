import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:konektizen/core/config/environment.dart';
import 'package:konektizen/core/router/router.dart';
import 'package:konektizen/features/sos_video_call/command_center_call_screen.dart';

class SignalingService {
  // Singleton Pattern
  static final SignalingService instance = SignalingService._internal();
  factory SignalingService() => instance;
  SignalingService._internal();

  IO.Socket? socket;
  Function(dynamic)? onOffer;
  Function(dynamic)? onAnswer;
  Function(dynamic)? onIceCandidate;
  Function(bool)? onCameraToggle;
  Function(bool)? onMicToggle; // [NEW] Sync mute state
  Function()? onEndCall;

  // C3 Command Center IP
  final String _serverUrl = EnvironmentConfig.signalingUrl;

  String? _userId;

  // Global listener for incoming calls from Command Center
  void listenForIncomingCall(String userId) {
    print('[Signaling] ========== SETTING UP INCOMING CALL LISTENER ==========');
    print('[Signaling] User ID: $userId');
    _userId = userId;
    
    // Connect (or reconnect if ID changed)
    connectToSocket(); 

    // Listen for ALL events for debugging
    socket!.onAny((event, data) {
      print('[Signaling] 📨 RECEIVED EVENT: $event');
      print('[Signaling] 📦 EVENT DATA: $data');
    });

    // C3 Spec: Listen for call_accepted (from accept_sos flow)
    socket!.on('call_accepted', (data) {
      print('[Signaling] 🔔 ========== CALL ACCEPTED RECEIVED ==========');
      print('[Signaling] Call Data: $data');
      
      // Extract callId and operatorName from C3 payload
      final callId = data['callId']?.toString() ?? data['call_id']?.toString() ?? "incoming";
      final room = data['room']?.toString() ?? callId;
      final operatorName = data['operatorName']?.toString() ?? "C3 Command Center";
      
      print('[Signaling] Parsed callId: $callId');
      print('[Signaling] Parsed room: $room');
      
      // CRITICAL: Immediately emit join-call to join WebRTC room
      print('[Signaling] Emitting join-call to room: $room');
      socket!.emit('join-call', {
        'callId': room,  
        'role': 'citizen'
      });
      
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
    });
  }

  void connectToSocket() {
      // Disconnect any existing socket first
    if (socket != null) {
      socket!.dispose();
      socket = null;
    }
    
    print('[Signaling] Connecting to C3 Socket: $_serverUrl');
    
    // MIMIC RESPONDER APP CONFIG EXACTLY
    socket = IO.io(_serverUrl, <String, dynamic>{
      'transports': ['websocket', 'polling'], 
      'autoConnect': true,
      'reconnection': true,
      'timeout': 10000,
      'forceNew': true,
    });
    
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

  // Legacy connect method (for accepting call logic inside CallScreen if needed)
  void connect(String callId, String token, String role) {
    // Re-use connection if possible, but usually Call Screen inits its own specific listeners?
    // For now, let's keep it creating a connection if one doesn't exist, or re-using.
    if (socket == null || !socket!.connected) {
        connectToSocket();
    }

    socket!.onConnect((_) {
      print('[Signaling] Emitting join-call event...');
      socket!.emit('join-call', {
        'callId': callId,
        'token': token,
        'role': role
      });
    });
    
    // Unified signal listener (C3 spec)
    socket!.on('signal', (data) {
      print('[Signaling] Received signal: ${data['type']}');
      final type = data['type'];
      final payload = data['payload'];
      
      switch (type) {
        case 'offer':
          onOffer?.call(payload);
          break;
        case 'answer':
          onAnswer?.call(payload);
          break;
        case 'ice':
          onIceCandidate?.call(payload);
          break;
        case 'camera':
          final enabled = payload['enabled'] ?? false;
          onCameraToggle?.call(enabled);
          break;
        case 'mic':
          // payload.enabled means "mic is enabled" (not muted)
          final enabled = payload['enabled'] ?? true;
          onMicToggle?.call(enabled);
          break;
      }
    });

    socket!.on('call_ended', (_) {
      print('[Signaling] Received call_ended');
      onEndCall?.call();
    });
    
    socket!.on('call-expired', (_) {
      print('[Signaling] Call expired');
      onEndCall?.call();
    });

    socket!.on('error', (data) {
      print('[Signaling] ERROR from server: $data');
    });
  }

  // Unified signal sender (C3 spec)
  void sendSignal({
    required String to,
    required dynamic reporterId, // [CHANGED] Allow String or int
    required String callId,
    required String type,
    required Map<String, dynamic> payload,
  }) {
    socket!.emit('signal', {
      'to': to,
      'reporter_id': reporterId,
      'call_id': callId,
      'type': type,
      'payload': payload,
    });
    print('[Signaling] Sent signal: $type');
  }
  
  // Legacy methods for backward compatibility
  void sendOffer(String room, dynamic sdp) {
    // Note: This is legacy, prefer sendSignal
    socket!.emit('offer', {'room': room, 'sdp': sdp});
  }

  void sendAnswer(String room, dynamic sdp) {
    socket!.emit('answer', {'room': room, 'sdp': sdp});
  }

  void sendIceCandidate(String room, dynamic candidate) {
    socket!.emit('ice-candidate', {'room': room, 'candidate': candidate});
  }
  
  void endCall(String room) {
     socket!.emit('call_ended', {'room': room});
     // Do not dispose, keep listening for next call?
     // For now, we dispose to be clean.
     // dispose(); 
     // BUT if we dispose, we lose the listener!
     // So maybe just leave room?
  }

  void dispose() {
    print('[Signaling] Disposing socket connection');
    if (socket != null) {
      socket!.disconnect();
      socket!.dispose();
      socket = null;
    }
  }
}
