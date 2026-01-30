import 'package:flutter_webrtc/flutter_webrtc.dart';

typedef StreamStateCallback = void Function(MediaStream stream);

class WebRTCManager {
  RTCPeerConnection? _peerConnection;
  MediaStream? _localStream;
  bool _isFrontCamera = true;
  
  final Map<String, dynamic> _configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
    ]
  };

  Future<void> init() async {
    _peerConnection = await createPeerConnection(_configuration);
  }

  Future<MediaStream> getUserMedia() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'facingMode': _isFrontCamera ? 'user' : 'environment',
      }
    };
    
    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localStream!.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });
    
    return _localStream!;
  }

  // C3 Spec: Start with audio-only
  Future<MediaStream> getUserMediaAudioOnly() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': false,
    };
    
    _localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
    _localStream!.getTracks().forEach((track) {
      _peerConnection?.addTrack(track, _localStream!);
    });
    
    // Add video transceiver for future camera toggle
    await _peerConnection?.addTransceiver(
      kind: RTCRtpMediaType.RTCRtpMediaTypeVideo,
      init: RTCRtpTransceiverInit(direction: TransceiverDirection.RecvOnly),
    );
    
    print('[WebRTC] Started with audio-only + video transceiver (recvonly)');
    return _localStream!;
  }

  // C3 Spec: Toggle camera on/off with renegotiation
  Future<void> toggleCameraEnabled({
    required bool enabled,
    required Function(RTCSessionDescription) onOfferCreated,
  }) async {
    if (_peerConnection == null) {
      print('[WebRTC] Cannot toggle camera: peer connection is null');
      return;
    }

    if (enabled) {
      print('[WebRTC] Enabling camera...');
      
      // Get video stream
      final videoStream = await navigator.mediaDevices.getUserMedia({
        'audio': false,
        'video': {
          'facingMode': _isFrontCamera ? 'user' : 'environment',
        }
      });
      
      final videoTrack = videoStream.getVideoTracks()[0];
      
      // Find video sender and replace track
      final senders = await _peerConnection!.getSenders();
      RTCRtpSender? videoSender;
      
      for (var sender in senders) {
        if (sender.track?.kind == 'video') {
          videoSender = sender;
          break;
        }
      }
      
      if (videoSender != null) {
        await videoSender.replaceTrack(videoTrack);
        print('[WebRTC] Replaced video track');
      } else {
        // Add track if no sender exists
        await _peerConnection!.addTrack(videoTrack, _localStream!);
        print('[WebRTC] Added new video track');
      }
      
      // Store video track in local stream
      _localStream?.addTrack(videoTrack);
      
    } else {
      print('[WebRTC] Disabling camera...');
      
      // Find video sender and remove track
      final senders = await _peerConnection!.getSenders();
      for (var sender in senders) {
        if (sender.track?.kind == 'video') {
          await sender.replaceTrack(null);
          print('[WebRTC] Removed video track');
          break;
        }
      }
    }
    
    // Renegotiate
    print('[WebRTC] Creating new offer for renegotiation...');
    final offer = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(offer);
    onOfferCreated(offer);
  }

  Future<void> switchCamera() async {
    if (_localStream == null) return;
    
    // Toggle camera state
    _isFrontCamera = !_isFrontCamera;
    
    // Helper to find video track
    MediaStreamTrack? videoTrack;
    try {
      videoTrack = _localStream!.getVideoTracks().first;
    } catch (e) {
      print('[WebRTC] No video track found to switch');
      return;
    }

    if (_localStream != null) {
      await Helper.switchCamera(videoTrack);
      print('[WebRTC] Camera switched to ${_isFrontCamera ? "front" : "back"}');
    }
  }

  Future<RTCSessionDescription> createOffer() async {
    RTCSessionDescription description = await _peerConnection!.createOffer();
    await _peerConnection!.setLocalDescription(description);
    return description;
  }

  Future<RTCSessionDescription> createAnswer() async {
    RTCSessionDescription description = await _peerConnection!.createAnswer();
    await _peerConnection!.setLocalDescription(description);
    return description;
  }

  Future<void> setRemoteDescription(RTCSessionDescription description) async {
    await _peerConnection!.setRemoteDescription(description);
  }

  Future<void> addCandidate(RTCIceCandidate candidate) async {
    await _peerConnection!.addCandidate(candidate);
  }

  void onIceCandidate(Function(RTCIceCandidate) callback) {
    _peerConnection?.onIceCandidate = callback;
  }

  void onTrack(Function(RTCTrackEvent) callback) {
    _peerConnection?.onTrack = callback;
  }

  void onAddStream(StreamStateCallback callback) {
    _peerConnection?.onAddStream = callback;
  }

  void dispose() {
    _localStream?.dispose();
    _peerConnection?.dispose();
  }
}
