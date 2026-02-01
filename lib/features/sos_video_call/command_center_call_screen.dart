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
                ? RTCVideoView(
                    _remoteRenderer, 
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
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
                child: RTCVideoView(
                  _localRenderer,
                  mirror: _isFrontCamera,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
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
