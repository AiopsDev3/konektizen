import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:konektizen/features/sos_video_call/pip_overlay.dart';
import 'package:konektizen/features/sos_video_call/signaling_service.dart';
import 'package:konektizen/features/sos_video_call/webrtc_peer.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class CallScreen extends StatefulWidget {
  final String callId;
  final String token;
  final String role; // 'citizen'
  final String? hotlineNumber; // Emergency hotline number

  const CallScreen({
    Key? key,
    required this.callId,
    required this.token,
    this.role = 'citizen',
    this.hotlineNumber,
  }) : super(key: key);

  @override
  _CallScreenState createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final SignalingService _signaling = SignalingService();
  final WebRTCManager _rtcManager = WebRTCManager();
  final RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  
  bool _inCall = false;
  bool _micOn = true;
  bool _cameraOn = true;
  bool _hasError = false;
  String _errorMessage = '';
  bool _isPiPMode = false;

  @override
  void initState() {
    super.initState();
    _initCall();
    
    // Listen for PiP mode changes from native Android
    PiPOverlay.setupPiPListener((bool isInPiP) {
      if (mounted) {
        setState(() {
          _isPiPMode = isInPiP;
        });
        print('[CallScreen] PiP mode changed: $_isPiPMode');
      }
    });
  }

  Future<void> _initCall() async {
    try {
      print('[CallScreen] Starting video call initialization...');
      print('[CallScreen] CallID: ${widget.callId}');
      print('[CallScreen] Token: ${widget.token}');
      print('[CallScreen] Role: ${widget.role}');
      
      // Request permissions
      print('[CallScreen] Requesting camera and microphone permissions...');
      final permissions = await [Permission.camera, Permission.microphone].request();
      
      if (permissions[Permission.camera] != PermissionStatus.granted ||
          permissions[Permission.microphone] != PermissionStatus.granted) {
        print('[CallScreen] ERROR: Permissions denied');
        setState(() {
          _hasError = true;
          _errorMessage = 'Camera and microphone permissions are required for video calls.';
        });
        return;
      }
      
      print('[CallScreen] Permissions granted');
      print('[CallScreen] Initializing renderers...');
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
      print('[CallScreen] Renderers initialized');
      
      print('[CallScreen] Initializing RTC manager...');
      await _rtcManager.init();
      print('[CallScreen] RTC manager initialized');
      
      // Setup Media
      print('[CallScreen] Getting user media...');
      final localStream = await _rtcManager.getUserMedia();
      setState(() {
        _localRenderer.srcObject = localStream;
      });
      print('[CallScreen] Local stream set');

      // Setup Signaling
      _signaling.onOffer = (data) async {
        print("[CallScreen] Received Offer from responder");
        var sdp = RTCSessionDescription(data['sdp'], data['type']);
        await _rtcManager.setRemoteDescription(sdp);
        var answer = await _rtcManager.createAnswer();
        print("[CallScreen] Sending Answer to responder");
        _signaling.sendAnswer(widget.callId, answer.toMap());
      };

      _signaling.onAnswer = (data) async {
         print("[CallScreen] Received Answer");
         var sdp = RTCSessionDescription(data['sdp'], data['type']);
         await _rtcManager.setRemoteDescription(sdp);
      };

      _signaling.onIceCandidate = (data) {
         print("[CallScreen] Received ICE Candidate");
         var candidate = RTCIceCandidate(
           data['candidate'], 
           data['sdpMid'], 
           data['sdpMLineIndex']
         );
         _rtcManager.addCandidate(candidate);
      };

      _signaling.onEndCall = () {
        print("[CallScreen] Call ended by remote");
        if (mounted) {
          _hangUp();
        }
      };
      
      // RTC Callbacks
      _rtcManager.onIceCandidate((candidate) {
        print("[CallScreen] Sending ICE Candidate");
        _signaling.sendIceCandidate(widget.callId, candidate.toMap());
      });

      _rtcManager.onAddStream((stream) {
        print("[CallScreen] Remote Stream Added - CONNECTION ESTABLISHED!");
        setState(() {
          _remoteRenderer.srcObject = stream;
          _inCall = true;
        });
      });

      // Connect Signaling
      print('[CallScreen] Connecting to signaling server...');
      _signaling.connect(widget.callId, widget.token, widget.role);
      
      // Set timeout for responder to join (2 minutes)
      Future.delayed(const Duration(minutes: 2), () {
        if (mounted && !_inCall) {
          print('[CallScreen] Timeout: Responder did not join');
          setState(() {
            _hasError = true;
            _errorMessage = 'Responder did not join the call. Please try again.';
          });
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) _hangUp();
          });
        }
      });
    } catch (e) {
      print('[CallScreen] ERROR initializing call: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Failed to start video call: ${e.toString()}';
        });
      }
    }
  }

  void _hangUp() {
    print('[CallScreen] _hangUp called. Trace: ${StackTrace.current}');
    try {
      _signaling.endCall(widget.callId);
    } catch (e) {
      print('Error ending call via signaling: $e');
    }
    
    // Clean up PiP if showing
    if (_isPiPMode) {
      PiPOverlay.hide();
      _isPiPMode = false;
    }
    
    try {
      _rtcManager.dispose();
    } catch (e) {
      print('Error disposing RTC manager: $e');
    }
    
    try {
      _localRenderer.dispose();
      _remoteRenderer.dispose();
    } catch (e) {
      print('Error disposing renderers: $e');
    }
    
    if (mounted) Navigator.pop(context);
  }
  
  void _minimizeToPiP() {
    // This method is no longer used - PiP only activates when calling 911
  }
  
  void _returnFromPiP() {
    // This method is no longer used - PiP only activates when calling 911
  }
  
  Future<void> _callHotline() async {
    if (widget.hotlineNumber != null) {
      print('[CallScreen] CALL 911 button pressed');
      
      // Enter native Android PiP mode FIRST
      if (_inCall && !_isPiPMode) {
        print('[CallScreen] Entering PiP mode before launching dialer');
        try {
          PiPOverlay.show(
            context: context,
            localRenderer: _localRenderer,
            onTap: () {}, 
            onClose: _hangUp,
          );
          setState(() {
            _isPiPMode = true;
          });
          // Give PiP time to activate
          await Future.delayed(const Duration(milliseconds: 800));
          print('[CallScreen] PiP mode activated');
        } catch (e) {
          print('[CallScreen] Error entering PiP: $e');
        }
      }
      
      // Now launch the dialer
      final Uri launchUri = Uri(scheme: 'tel', path: widget.hotlineNumber!);
      try {
        print('[CallScreen] Launching dialer for ${widget.hotlineNumber}');
        if (await canLaunchUrl(launchUri)) {
          await launchUrl(launchUri);
          print('[CallScreen] Dialer launched successfully');
        } else {
          print('[CallScreen] Cannot launch dialer for ${widget.hotlineNumber}');
        }
      } catch (e) {
        print('[CallScreen] Error launching dialer: $e');
      }
    }
  }

  void _toggleMic() {
    final audioTracks = _localRenderer.srcObject?.getAudioTracks();
    if (audioTracks != null && audioTracks.isNotEmpty) {
      final enabled = !_micOn;
      audioTracks[0].enabled = enabled;
      setState(() => _micOn = enabled);
    }
  }

  void _switchCamera() async {
    print('[CallScreen] Switching camera...');
    await _rtcManager.switchCamera();
    setState(() {
      _localRenderer.srcObject = _localRenderer.srcObject;
    });
  }

  void _toggleCamera() {
    final videoTracks = _localRenderer.srcObject?.getVideoTracks();
    if (videoTracks != null && videoTracks.isNotEmpty) {
      final enabled = !_cameraOn;
      videoTracks[0].enabled = enabled;
      setState(() => _cameraOn = enabled);
    }
  }

  @override
  void dispose() {
    try {
      _rtcManager.dispose();
    } catch (e) {
      print('Error in dispose: $e');
    }
    try {
      _localRenderer.dispose();
      _remoteRenderer.dispose();
    } catch (e) {
      print('Error disposing renderers: $e');
    }
    try {
      _signaling.dispose();
    } catch (e) {
      print('Error disposing signaling: $e');
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
            // Remote Video (Full Screen)
            Positioned.fill(
              child: _hasError
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 80),
                            const SizedBox(height: 24),
                            Text(
                              _errorMessage,
                              style: const TextStyle(color: Colors.white, fontSize: 18),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 32),
                            ElevatedButton(
                              onPressed: _hangUp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                              ),
                              child: const Text('CLOSE', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _remoteRenderer.srcObject != null
                      ? RTCVideoView(_remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
                      : Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text("Waiting for Responder...", style: TextStyle(color: Colors.white)),
                            ],
                          ),
                        ),
            ),
          // Local Video (Small Overlay) - Hidden in PiP mode
          if (!_isPiPMode)
            Positioned(
              right: 20,
              top: 50,
              child: Container(
                width: 100,
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.black, // Ensure opaque background
                  border: Border.all(color: Colors.white),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: RTCVideoView(
                    _localRenderer,
                    mirror: true,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  ),
                ),
              ),
            ),

          // Controls - Hidden in PiP mode
          if (!_isPiPMode)
            Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(_micOn ? Icons.mic : Icons.mic_off, color: Colors.white, size: 30),
                  onPressed: _toggleMic,
                  style: IconButton.styleFrom(backgroundColor: Colors.grey.withOpacity(0.5)),
                ),
                // Switch Camera Button
                IconButton(
                    icon: const Icon(Icons.cameraswitch, color: Colors.white, size: 30),
                    onPressed: _switchCamera,
                    style: IconButton.styleFrom(backgroundColor: Colors.grey.withOpacity(0.5)),
                ),
                if (widget.hotlineNumber != null)
                  IconButton(
                    icon: const Icon(Icons.phone, color: Colors.white, size: 30),
                    onPressed: _callHotline,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                // Hang Up Button
                  IconButton(
                    icon: const Icon(Icons.call_end, color: Colors.white, size: 30),
                    onPressed: _hangUp,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                IconButton(
                  icon: Icon(_cameraOn ? Icons.videocam : Icons.videocam_off, color: Colors.white, size: 30),
                  onPressed: _toggleCamera,
                  style: IconButton.styleFrom(backgroundColor: Colors.grey.withOpacity(0.5)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
