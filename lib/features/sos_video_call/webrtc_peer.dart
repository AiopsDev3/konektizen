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
