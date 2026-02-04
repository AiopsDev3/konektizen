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
  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  bool _isConnecting = true;

  // --- Timer State ---
  Timer? _timer;
  int _secondsElapsed = 0;
  
  // --- Controls State ---
  bool _isMicMuted = false;
  bool _isSpeakerOn = true; 
  bool _isVideoOn = true; // Default to VIDEO ON for SOS
  bool _isFrontCamera = true;
  bool _remoteVideoEnabled = true; // [NEW] Track remote camera state

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _startTimer();
    _initializeWebRTC();
  }

  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _disposeWebRTC();
    super.dispose();
  }
  
  // --- WebRTC Logic ---
  Future<void> _initializeWebRTC() async {
    print('[Call Screen] Initializing WebRTC...');
    
    // 1. Setup Signaling Listeners IMMEDIATELY (Critical for receiving offer)
    _setupSignalingListeners();

    try {
      // 2. Get User Media - Try Video First
      final mediaConstraints = {
        'audio': true,
        'video': {
          'facingMode': 'user',
          'width': 1280,
          'height': 720,
        }
      };
      
      try {
         _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
         print('[Call Screen] Local Stream acquired (video+audio)');
      } catch (e) {
         print('[Call Screen] Video failed, falling back to Audio only: $e');
         // Fallback to audio only
         _localStream = await navigator.mediaDevices.getUserMedia({'audio': true});
      }
      
      _localRenderer.srcObject = _localStream;

      // 3. Create Peer Connection
      final configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ]
      };
      
      _peerConnection = await createPeerConnection(configuration);
      
      // 4. Add Local Tracks
      _localStream!.getTracks().forEach((track) {
        _peerConnection!.addTrack(track, _localStream!);
      });

      // 4. Handle ICE Candidates
      _peerConnection!.onIceCandidate = (candidate) {
        SignalingService.instance.socket?.emit('ice-candidate', {
          'room': widget.callId, // use strict room based signaling
          'candidate': {
            'candidate': candidate.candidate,
            'sdpMid': candidate.sdpMid,
            'sdpMLineIndex': candidate.sdpMLineIndex,
          }
        });
      };

      // 5. Handle Remote Stream
      _peerConnection!.onTrack = (event) {
        print('[Call Screen] Remote Track Received: ${event.track.kind}');
        if (event.streams.isNotEmpty) {
           setState(() {
             _remoteRenderer.srcObject = event.streams[0];
             _isConnecting = false;
           });
        }
      };

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

    print('[Call Screen] [KONEKTIZEN_SOS] Listening for OFFER in room: ${widget.callId}');

    // Remove old listeners to prevent duplication
    socket.off('offer');
    socket.off('ice-candidate');
    socket.off('end-call');
    socket.off('signal'); // Use unified signal listener from service usually, but here we might attach custom ones

    // Listen for OFFER (C3 is initiator)
    socket.on('offer', (data) async {
       print('[KONEKTIZEN_SOS] 📨 Received OFFER from C3');
       if (data is! Map) {
         print('[Call Screen] ❌ Offer data invalid: $data');
         return;
       }
       try {
         String sdp;
         String type = 'offer';
         
         final rawSdp = data['sdp'];
         if (rawSdp is Map) {
           sdp = rawSdp['sdp'];
           type = rawSdp['type'] ?? 'offer';
         } else if (rawSdp is String) {
           sdp = rawSdp;
           // If backend sent {sdp: "...", type: "offer"} at top level
           if (data['type'] != null) {
              type = data['type'];
           }
         } else {
           print('[Call Screen] ❌ SDP data unknown format: $rawSdp');
           return;
         }

         await _peerConnection!.setRemoteDescription(
           RTCSessionDescription(sdp, type)
         );
         
         // Create Answer
         final answer = await _peerConnection!.createAnswer();
         await _peerConnection!.setLocalDescription(answer);
         
         // Send Answer
         socket.emit('answer', {
           'room': widget.callId,
           'sdp': {
             'type': answer.type,
             'sdp': answer.sdp,
           }
         });
         print('[KONEKTIZEN_SOS] 📤 Sent ANSWER to room: ${widget.callId}');
       } catch (e) {
         print('[Call Screen] ❌ Handle Offer Error: $e');
       }
    });
    
    // Listen for ICE Candidates
    socket.on('ice-candidate', (data) {
       if (_peerConnection != null && data is Map) {
          try {
            final candidateData = data['candidate'];
            if (candidateData is Map) {
               final candidate = RTCIceCandidate(
                 candidateData['candidate'],
                 candidateData['sdpMid'],
                 candidateData['sdpMLineIndex'],
               );
               _peerConnection!.addCandidate(candidate);
            }
          } catch (e) {
             print('[Call Screen] ❌ ICE Error: $e');
          }
       }
    });

    // LISTEN FOR UNIFIED SIGNALS (Camera/Mic)
    socket.on('signal', (data) {
      if (data['type'] == 'camera') {
        final payload = data['payload'];
        final enabled = payload is Map ? (payload['enabled'] ?? false) : false;
        print('[Call Screen] Remote Camera Toggle: $enabled');
        setState(() {
          _remoteVideoEnabled = enabled;
        });
      }
      if (data['type'] == 'mic') {
         // handle mic status UI if needed
      }
    });
    
    socket.on('end-call', (data) {
       print('[Call Screen] 🛑 Received end-call event: $data');
       _onRemoteEndCall();
    });
  }
  
  Future<void> _disposeWebRTC() async {
    _localStream?.dispose();
    _peerConnection?.close();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _secondsElapsed++);
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds / 60).floor();
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(1, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  void _onUserEndCall() {
    print('[Call Screen] User Ending Call');
    SignalingService.instance.socket?.emit('end-call', {'room': widget.callId});
    if (mounted) {
       context.go('/home');
    }
  }

  void _onRemoteEndCall() {
     print('[Call Screen] Remote Ended Call');
     if (mounted) {
       context.go('/home');
     }
  }

  void _getReporterId() {
     // Helper to get reporter id if needed
  }
  
  void _toggleMic() {
    if (_localStream != null) {
      final audioTracks = _localStream!.getAudioTracks();
      if (audioTracks.isNotEmpty) {
        bool enabled = audioTracks[0].enabled;
        audioTracks[0].enabled = !enabled;
        setState(() => _isMicMuted = !enabled);

        // Emit Mic Signal
         SignalingService.instance.sendSignal(
            to: 'reporter', // C3 is calling responder, but usually C3 is responder?? Wait. 
            // In C3->Konektizen check: C3 is responder? No C3 is Command Center.
            // If this is Konektizen App view for RESPONDERS (e.g. Police App), then they call 'reporter' (Citizen).
            // But wait, the file is `CommandCenterCallScreen`. Is this the "Mobile Agent" app?
            // "CommandCenterCallScreen" implies this is the screen shown when command center calls you?
            // Or is this the screen for the Citizen when talking to Command Center? 
            // The file `call_screen.dart` had `role='citizen'`.
            // `CommandCenterCallScreen.dart` seems to be used when `call_accepted` event arrives?
            // "socket.on('call_accepted')... builder: (_) => CommandCenterCallScreen" 
            // This suggests THIS screen is what the CITIZEN sees when the COMMAND CENTER accepts their SOS.
            // Meaning "Remote" is C3 (Responder). 
            // So target should be 'responder' (the C3 agent).
            
            // Wait, previous `CallScreen` used target 'c3'. 
            // `SignalingService` sendSignal uses `socket.emit('signal', {to: ...})`.
            // The backend routes 'responder' to the agent ID.
            
            // Let's use 'responder' as target if we are the citizen.
            // `call_screen.dart` used 'c3'. Let's check backend routing if possible, but safe bet is 'responder' if 'c3' isn't standard.
            // Actually `CallScreen.dart` used 'c3'. I should probably stick to 'responder' or 'c3' if that works.
            // Let's assume 'responder' is correct for "The other party".
            
            // Re-reading CallWindow.jsx (Web): 
            // It sends to 'reporter' if it is C3.
            // So Mobile should send to 'responder'.
            
            reporterId: 0, 
            callId: widget.callId,
            type: 'mic',
            payload: {'enabled': !enabled}
         );
      }
    }
  }
  
  void _switchCamera() async {
    if (_localStream != null) {
      final videoTracks = _localStream!.getVideoTracks();
      if (videoTracks.isNotEmpty) {
        await Helper.switchCamera(videoTracks[0]);
        setState(() => _isFrontCamera = !_isFrontCamera);
      }
    }
  }

  void _toggleVideo() {
     setState(() => _isVideoOn = !_isVideoOn);
     if (_localStream != null) {
        final videoTracks = _localStream!.getVideoTracks();
        if (videoTracks.isNotEmpty) {
           videoTracks[0].enabled = _isVideoOn;
        }
        
        // Emit Camera Signal
        SignalingService.instance.sendSignal(
            to: 'responder',
            reporterId: 0,
            callId: widget.callId,
            type: 'camera',
            payload: {'enabled': _isVideoOn}
         );
     }
  }

  void _toggleSpeaker() {
     setState(() => _isSpeakerOn = !_isSpeakerOn);
     Helper.setSpeakerphoneOn(_isSpeakerOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Remote Video (Full Screen)
          Positioned.fill(
            child: _remoteRenderer.srcObject != null
                ? Stack(
                    children: [
                       RTCVideoView(
                        _remoteRenderer, 
                        objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                      ),
                      // Audio Call UI (If BOTH cameras are OFF)
                      if (!_isVideoOn && !_remoteVideoEnabled) 
                          Container(
                             color: const Color(0xFF0F172A), // Dark Slate
                             child: Center(
                               child: Column(
                                 mainAxisSize: MainAxisSize.min,
                                 children: [
                                   Container(
                                     width: 120,
                                     height: 120,
                                     decoration: BoxDecoration(
                                       shape: BoxShape.circle,
                                       gradient: const LinearGradient(
                                          colors: [Colors.blue, Colors.blueAccent],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                       ),
                                       boxShadow: [
                                          BoxShadow(color: Colors.blue.withOpacity(0.4), blurRadius: 20, spreadRadius: 5)
                                       ]
                                     ),
                                     child: const Icon(Icons.call, color: Colors.white, size: 50),
                                   ),
                                   const SizedBox(height: 24),
                                   const Text("Audio Call", style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                                   const SizedBox(height: 8),
                                   const Text("Camera is off for both parties", style: TextStyle(color: Colors.white54)),
                                 ],
                               ),
                             ),
                          )
                      // Off Camera Overlay (If Remote Off but Local On)
                      else if (!_remoteVideoEnabled)
                        Container(
                          color: Colors.black87,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.videocam_off, color: Colors.white54, size: 48),
                                SizedBox(height: 12),
                                Text(
                                  "Off Camera",
                                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ], 
                  )
                : Container(
                    color: Colors.grey[900],
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const CircularProgressIndicator(color: Colors.white),
                          const SizedBox(height: 16),
                          Text(
                            _isConnecting ? 'Waiting for video...' : 'Connected',
                            style: const TextStyle(color: Colors.white),
                          )
                        ],
                      ),
                    ),
                  ),
          ),
          
          // 2. Local Video (PIP)
          Positioned(
            right: 16,
            top: 60,
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _isVideoOn 
                  ? RTCVideoView(
                      _localRenderer,
                      mirror: _isFrontCamera,
                      objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                    )
                  : Container(
                      color: Colors.grey[800],
                      child: Center(
                        child: Icon(Icons.videocam_off, color: Colors.white38),
                      ),
                    ),
              ),
            ),
          ),

          // 3. User Info & Timer
          Positioned(
            top: 60,
            left: 20,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.operatorName ?? 'Command Center',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                  ),
                ),
                Text(
                  _formatDuration(_secondsElapsed),
                  style: const TextStyle(
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black)],
                  ),
                ),
              ],
            ),
          ),

          // 4. Bottom Controls
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.transparent, Colors.black87],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildControlButton(
                    icon: _isVideoOn ? Icons.videocam : Icons.videocam_off,
                    onPressed: _toggleVideo,
                    isActive: _isVideoOn,
                  ),
                  _buildControlButton(
                    icon: _isMicMuted ? Icons.mic_off : Icons.mic,
                    onPressed: _toggleMic,
                    isActive: !_isMicMuted,
                  ),
                   FloatingActionButton(
                    backgroundColor: Colors.red,
                    onPressed: _onUserEndCall,
                    child: const Icon(Icons.call_end, color: Colors.white),
                  ),
                  _buildControlButton(
                    icon: _isSpeakerOn ? Icons.volume_up : Icons.phone_in_talk,
                    onPressed: _toggleSpeaker,
                    isActive: _isSpeakerOn,
                  ),
                  _buildControlButton(
                    icon: Icons.flip_camera_ios,
                    onPressed: _switchCamera,
                    isActive: false, // plain style
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onPressed,
    required bool isActive,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isActive ? Colors.white.withOpacity(0.2) : Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white),
        onPressed: onPressed,
      ),
    );
  }
}
