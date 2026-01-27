import 'package:socket_io_client/socket_io_client.dart' as IO;

class SignalingService {
  IO.Socket? socket;
  Function(dynamic)? onLocalStream;
  Function(dynamic)? onRemoteStream;
  Function(dynamic)? onJoined;
  Function(dynamic)? onOffer;
  Function(dynamic)? onAnswer;
  Function(dynamic)? onIceCandidate;
  Function()? onEndCall;
  // Function(dynamic)? onConferenceStart; // Removed Jitsi legacy

  // Flask server IP for WiFi connection
  final String _serverUrl = 'http://172.16.0.101:5000';

  void connect(String callId, String token, String role) {
    // Disconnect any existing socket first
    if (socket != null) {
      print('[Signaling] Disposing existing socket before reconnecting');
      socket!.disconnect();
      socket!.dispose();
      socket = null;
    }
    
    print('[Signaling] ========================================');
    print('[Signaling] Creating new socket connection');
    print('[Signaling] Server URL: $_serverUrl');
    print('[Signaling] CallID: $callId');
    print('[Signaling] Role: $role');
    print('[Signaling] ========================================');
    
    socket = IO.io(_serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'forceNew': true, // Force new connection
    });

    socket!.connect();

    socket!.onConnect((_) {
      print('[Signaling] ✓ Connected to Socket.IO server at $_serverUrl');
      print('[Signaling] Socket ID: ${socket!.id}');
      print('[Signaling] Emitting join-call event...');
      socket!.emit('join-call', {
        'callId': callId,
        'token': token,
        'role': role
      });
      print('[Signaling] join-call emitted for room: $callId');
    });
    
    socket!.onConnectError((data) {
      print('[Signaling] ✗ Connection error: $data');
      print('[Signaling] Verify that $_serverUrl is reachable and adb reverse is running.');
    });
    
    socket!.onError((data) {
      print('[Signaling] Socket Error: $data');
    });
    
    socket!.onDisconnect((_) {
      print('[Signaling] ✗ Disconnected from Socket.IO server');
    });

    socket!.on('offer', (data) {
      print('[Signaling] Received offer');
      onOffer?.call(data);
    });

    socket!.on('answer', (data) {
      print('[Signaling] Received answer');
      onAnswer?.call(data);
    });

    socket!.on('ice-candidate', (data) {
      print('[Signaling] Received ICE candidate');
      onIceCandidate?.call(data);
    });

    socket!.on('end-call', (_) {
      print('[Signaling] Received end-call');
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

  void sendOffer(String room, dynamic sdp) {
    socket!.emit('offer', {'room': room, 'sdp': sdp});
  }

  void sendAnswer(String room, dynamic sdp) {
    socket!.emit('answer', {'room': room, 'sdp': sdp});
  }

  void sendIceCandidate(String room, dynamic candidate) {
    socket!.emit('ice-candidate', {'room': room, 'candidate': candidate});
  }
  
  void endCall(String room) {
     socket!.emit('end-call', {'room': room});
     dispose();
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
