import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:konektizen/features/sos_video_call/signaling_service.dart';

class CommandCenterCallScreen extends StatefulWidget {
  final String callId;
  final String? operatorName;

  const CommandCenterCallScreen({
    super.key,
    required this.callId,
    this.operatorName,
  });

  @override
  State<CommandCenterCallScreen> createState() => _CommandCenterCallScreenState();
}

class _CommandCenterCallScreenState extends State<CommandCenterCallScreen> {
  // --- WebRTC State ---
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  MediaStream? _remoteStream; // For audio playback (even if no video)
  bool _isConnecting = true;

  // --- Timer State ---
  Timer? _timer;
  int _secondsElapsed = 0;
  
  // --- Controls State ---
  bool _isMicMuted = false;
  bool _isSpeakerOn = true; // Use Helper to toggle
  bool _isVideoOn = false; 

  @override
  void initState() {
    super.initState();
    _startTimer();
    _initializeWebRTC();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _disposeWebRTC();
    super.dispose();
  }
  
  // --- WebRTC Logic ---
  Future<void> _initializeWebRTC() async {
    print('[Call Screen] Initializing WebRTC...');
    try {
      // 1. Get User Media - C3 Spec: Audio-Only
      final mediaConstraints = {
        'audio': true,
        'video': false // C3 spec: start with audio-only
      };
      
      _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      print('[Call Screen] Local Stream acquired (audio-only)');

      // 3. Create Peer Connection
      final configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          // Add TURN servers here if needed for production
        ]
      };
      
      _peerConnection = await createPeerConnection(configuration);
      
      // 4. Add Local Tracks to Peer Connection
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // 4. Handle ICE Candidates - C3 Spec: room-based event
      _peerConnection!.onIceCandidate = (candidate) {
        print('[Call Screen] Sending ICE Candidate');
        SignalingService.instance.socket?.emit('ice-candidate', {
          'room': widget.callId,
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }
        });
        print('[ICE] Sent to room: ${widget.callId}');
      };

      // 5. Handle Remote Stream (Audio)
      _peerConnection!.onTrack = (event) {
        print('[Call Screen] Remote Track Received');
        if (event.streams.isNotEmpty) {
           setState(() {
             _remoteStream = event.streams[0];
             _isConnecting = false;
           });
        }
      };
      
      // 6. Setup Signaling Listeners
      _setupSignalingListeners();

    } catch (e) {
      print('[Call Screen] WebRTC Init Error: $e');
      if(mounted) {
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Call Error: $e')));
      }
    }
  }
  
  void _setupSignalingListeners() {
    final socket = SignalingService.instance.socket;
    if (socket == null) return;

    print('[Call Screen] Setting up room-based signaling listeners');
    print('[Call Screen] Room: ${widget.callId}');
    print('[Call Screen] C3 is initiator - waiting for offer');

    // C3 Spec: Listen for OFFER (C3 is initiator)
    socket.on('offer', (data) async {
       print('[Signaling] 📨 Received OFFER from C3');
       print('[Signaling] Offer data: $data');
       try {
         // C3 sends: {room: 'sos_X', sdp: {type: 'offer', sdp: '...'}}
         final sdpData = data['sdp'];
         await _peerConnection!.setRemoteDescription(
           RTCSessionDescription(sdpData['sdp'], sdpData['type'])
         );
         print('[Signaling] ✅ Remote description set');
         
         // Create Answer
         final answer = await _peerConnection!.createAnswer();
         await _peerConnection!.setLocalDescription(answer);
         print('[Signaling] ✅ Local description (answer) set');
         
         // Send Answer - C3 Spec: room-based event
         socket.emit('answer', {
           'room': widget.callId,
           'sdp': {
             'type': answer.type,
             'sdp': answer.sdp,
           }
         });
         print('[Signaling] 📤 Sent ANSWER to room: ${widget.callId}');
       } catch (e) {
         print('[Call Screen] ❌ Handle Offer Error: $e');
       }
    });
    
    // Listen for ICE Candidates
    socket.on('ice-candidate', (data) {
       print('[Signaling] 🧊 Received ICE Candidate');
       if (_peerConnection != null) {
          final candidateData = data['candidate'];
          final candidate = RTCIceCandidate(
            candidateData['candidate'],
            candidateData['sdpMid'],
            candidateData['sdpMLineIndex'],
          );
          _peerConnection!.addCandidate(candidate);
          print('[Signaling] ✅ ICE candidate added');
       }
    });
    
    // Listen for End Call
    socket.on('end-call', (_) {
       print('[Call Screen] Remote Ended Call');
       _handleEndCall();
    });
  }
  
  Future<void> _disposeWebRTC() async {
    _localStream?.dispose();
    _peerConnection?.close();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _secondsElapsed++);
      }
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _handleEndCall() {
    print('[Call Screen] Ending Call');
    SignalingService.instance.socket?.emit('end-call');
    // Dispose handled by dispose()
    if (mounted && context.canPop()) {
       context.pop();
    }
  }
  
  void _toggleMic() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        bool enabled = audioTracks[0].enabled;
        audioTracks[0].enabled = !enabled;
        setState(() => _isMicMuted = !enabled);
      }
    }
  }

  void _toggleSpeaker() {
     setState(() => _isSpeakerOn = !_isSpeakerOn);
     Helper.setSpeakerphoneOn(_isSpeakerOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F4E68), Color(0xFF061821)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                      onPressed: () { 
                         // Minimize (Pop) but keep call running? 
                         // For now, simpler to just treat as back
                         // context.pop(); 
                      },
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 1),

              // Center Info
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isConnecting ? Colors.orange : Colors.green,
                        width: 3
                      )
                    ),
                    child: Icon(
                      Icons.support_agent,
                      size: 50,
                      color: _isConnecting ? Colors.orange : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Text(
                    widget.operatorName ?? 'C3 Command Center',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  Text(
                    _isConnecting ? 'Connecting Audio...' : _formatDuration(_secondsElapsed),
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 2),

              // Bottom Control Bar
              Padding(
                padding: const EdgeInsets.only(bottom: 48.0, left: 16, right: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // 1. Video Toggle (Default Off)
                    _buildControlButton(
                      icon: _isVideoOn ? Icons.videocam : Icons.videocam_off,
                      isActive: _isVideoOn,
                      onPressed: () {
                         setState(() => _isVideoOn = !_isVideoOn);
                         // TODO: Enable/Disable video track
                         if (_localStream != null) {
                            _localStream!.getVideoTracks().forEach((track) {
                              track.enabled = _isVideoOn;
                            });
                         }
                      },
                    ),

                    // 2. Mic Toggle
                    _buildControlButton(
                      icon: _isMicMuted ? Icons.mic_off : Icons.mic,
                      isActive: !_isMicMuted,
                      onPressed: _toggleMic,
                    ),

                    // 3. Speaker Toggle
                    _buildControlButton(
                      icon: _isSpeakerOn ? Icons.volume_up : Icons.phone_in_talk,
                      isActive: _isSpeakerOn,
                      onPressed: _toggleSpeaker,
                    ),

                    // 4. End Call (Prominent)
                    Container(
                      height: 64,
                      width: 80,
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444), // Emergency Red
                        borderRadius: BorderRadius.all(Radius.circular(32)),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.call_end, color: Colors.white, size: 32),
                        onPressed: _handleEndCall,
                      ),
                    ),
                    
                    // 5. Camera Switch (Only active if video is on, but shown in UI)
                     _buildControlButton(
                      icon: Icons.flip_camera_ios_outlined,
                      isActive: false, 
                      onPressed: () {
                         if (_localStream != null) {
                            Helper.switchCamera(_localStream!.getVideoTracks()[0]);
                         }
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withOpacity(0.3) : Colors.white.withOpacity(0.1), 
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: 24),
        onPressed: onPressed,
      ),
    );
  }
}
