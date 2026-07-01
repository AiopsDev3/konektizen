import 'dart:async';
import 'dart:convert';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:konektizen/core/api/api_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:konektizen/features/sos_video_call/call_controller.dart';
import 'package:konektizen/features/sos_video_call/signaling_service.dart';
import 'package:konektizen/features/sos_video_call/widgets/call_header.dart';
import 'package:konektizen/features/sos_video_call/widgets/call_controls.dart';
import 'package:konektizen/features/sos_video_call/widgets/call_status.dart';
import 'package:konektizen/features/sos_video_call/widgets/camera_off_placeholder.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class CommandCenterCallScreen extends StatefulWidget {
  final String callId;
  final String? roomName;
  final String? operatorName;
  final bool startWithCamera;
  final String? aiCallerSessionId;

  const CommandCenterCallScreen({
    super.key,
    required this.callId,
    this.roomName,
    this.operatorName,
    this.startWithCamera = true,
    this.aiCallerSessionId,
  });

  @override
  State<CommandCenterCallScreen> createState() =>
      _CommandCenterCallScreenState();
}

class _CommandCenterCallScreenState extends State<CommandCenterCallScreen>
    with WidgetsBindingObserver {
  static const String _aiGreeting =
      'AIGOR ito from C3. Nandito ako. Ano ang emergency?';

  late final CallController _controller;
  late final String _roomName;
  late final AudioPlayer _neuralVoicePlayer;
  late final SpeechToText _speech;
  bool _hasPlayedAiGreeting = false;
  bool _hasStartedAiListening = false;
  bool _isSubmittingAiReport = false;
  bool _hasSubmittedAiReport = false;
  bool _handoffRequested = false;
  bool _operatorAccepted = false;
  bool _isAiSpeaking = false;
  bool _bargeInActive = false;
  bool _isHandlingCallerTranscript = false;
  bool _hasAskedAiFollowUp = false;
  bool _hasRequestedCallEnd = false;
  final bool _speechDiagnosticsEnabled = true;
  int _aiListenAttempt = 0;
  String? _aiCallerSessionId;
  String? _acceptedOperatorName;
  String? _preferredSpeechLocaleId;
  String? _bargeInPrompt;
  Timer? _bargeInTimer;
  Timer? _followUpFallbackTimer;
  Completer<void>? _activeNeuralVoiceCompleter;
  DateTime? _listenStartedAt;
  String _callerReportDraft = '';
  String _pendingAiReportTranscript = '';
  String _aiStatusMessage = 'AIGOR is preparing...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _roomName = widget.roomName ?? _roomNameForCall(widget.callId);
    _aiCallerSessionId =
        widget.aiCallerSessionId ?? _deriveAiSessionId(widget.callId);
    _neuralVoicePlayer = AudioPlayer();
    _speech = SpeechToText();
    _controller = CallController(
      callId: widget.callId,
      roomName: _roomName,
      startWithCamera: widget.startWithCamera,
      deferPublishing: _isAiTriageCall,
      deferConnection: _isAiTriageCall,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
    );
    SignalingService.instance.rememberActiveCall(
      room: _roomName,
      callId: widget.callId,
      operatorName: widget.operatorName,
      aiCallerSessionId: _aiCallerSessionId,
    );
    SignalingService.instance.markCallScreenVisible(_roomName, true);
    SignalingService.instance.socket?.on('end-call', _handleRemoteEndCall);
    SignalingService.instance.socket?.on('call_ended', _handleRemoteEndCall);
    SignalingService.instance.socket?.on('call_declined', _handleRemoteEndCall);
    SignalingService.instance.socket?.on('sos_dismissed', _handleRemoteEndCall);
    SignalingService.instance.socket?.on(
      'call_accepted',
      _handleOperatorAccepted,
    );
    SignalingService.instance.socket?.on('c3_sos_ack', _handleOperatorAccepted);
    SignalingService.instance.socket?.on(
      'ai_caller_started',
      _handleAiCallerStarted,
    );
    SignalingService.instance.socket?.on(
      'ai_caller_audio_received',
      _handleAiCallerAudioReceived,
    );
    SignalingService.instance.socket?.on(
      'ai_caller_transcribed',
      _handleAiCallerTranscribed,
    );
    SignalingService.instance.socket?.on(
      'ai_triage_completed',
      _handleAiTriageCompleted,
    );
    SignalingService.instance.socket?.on(
      'ai_operator_handoff',
      _handleAiOperatorHandoff,
    );
    SignalingService.instance.socket?.on(
      'ai_caller_failed',
      _handleAiCallerFailed,
    );
    SignalingService.instance.onCallEnded = _handleGlobalCallEnded;
    WakelockPlus.enable();
    if (_isAiTriageCall) {
      Future.delayed(const Duration(milliseconds: 900), () {
        unawaited(_speakAiGreeting());
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SignalingService.instance.socket?.off('end-call', _handleRemoteEndCall);
    SignalingService.instance.socket?.off('call_ended', _handleRemoteEndCall);
    SignalingService.instance.socket?.off(
      'call_declined',
      _handleRemoteEndCall,
    );
    SignalingService.instance.socket?.off(
      'sos_dismissed',
      _handleRemoteEndCall,
    );
    SignalingService.instance.socket?.off(
      'call_accepted',
      _handleOperatorAccepted,
    );
    SignalingService.instance.socket?.off(
      'c3_sos_ack',
      _handleOperatorAccepted,
    );
    SignalingService.instance.socket?.off(
      'ai_caller_started',
      _handleAiCallerStarted,
    );
    SignalingService.instance.socket?.off(
      'ai_caller_audio_received',
      _handleAiCallerAudioReceived,
    );
    SignalingService.instance.socket?.off(
      'ai_caller_transcribed',
      _handleAiCallerTranscribed,
    );
    SignalingService.instance.socket?.off(
      'ai_triage_completed',
      _handleAiTriageCompleted,
    );
    SignalingService.instance.socket?.off(
      'ai_operator_handoff',
      _handleAiOperatorHandoff,
    );
    SignalingService.instance.socket?.off(
      'ai_caller_failed',
      _handleAiCallerFailed,
    );
    if (SignalingService.instance.onCallEnded == _handleGlobalCallEnded) {
      SignalingService.instance.onCallEnded = null;
    }
    SignalingService.instance.markCallScreenVisible(_roomName, false);
    WakelockPlus.disable();
    _bargeInTimer?.cancel();
    _followUpFallbackTimer?.cancel();
    _speech.stop();
    _neuralVoicePlayer.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_isAiTriageCall || _controller.isEnding || _operatorAccepted) return;
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(_speech.stop().catchError((_) {}));
      return;
    }
    if (state == AppLifecycleState.resumed &&
        !_hasSubmittedAiReport &&
        !_isSubmittingAiReport &&
        !_isHandlingCallerTranscript) {
      _hasStartedAiListening = false;
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted &&
            !_controller.isEnding &&
            !_operatorAccepted &&
            !_hasSubmittedAiReport &&
            !_isSubmittingAiReport) {
          unawaited(_startAiReportListening());
        }
      });
    }
  }

  bool get _isAiTriageCall {
    final name = (widget.operatorName ?? '').toLowerCase();
    return name.contains('ai') ||
        name.contains('aigor') ||
        (widget.aiCallerSessionId?.trim().isNotEmpty ?? false) ||
        (_aiCallerSessionId?.trim().isNotEmpty ?? false);
  }

  bool get _usesCallStreamForAiHearing => false;

  String get _currentPeerDisplayName {
    if (_isAiTriageCall && !_operatorAccepted) return 'AIGOR';
    return _humanOperatorDisplayName(
      _acceptedOperatorName ?? widget.operatorName,
    );
  }

  String _humanOperatorDisplayName(String? name) {
    final cleaned = name?.trim();
    if (cleaned == null || cleaned.isEmpty) return 'Command Center';
    final lower = cleaned.toLowerCase();
    if (lower == 'ai' ||
        lower.contains('aigor') ||
        lower.contains('emergency ai') ||
        lower.contains('ai caller')) {
      return 'Command Center';
    }
    return cleaned;
  }

  String? _operatorNameFromPayload(Map<String, dynamic> payload) {
    final value =
        payload['operatorName'] ??
        payload['operator_name'] ??
        payload['assignedOperatorName'] ??
        payload['assigned_operator_name'] ??
        payload['name'];
    final cleaned = value?.toString().trim();
    return cleaned == null || cleaned.isEmpty ? null : cleaned;
  }

  Future<void> _speakAiGreeting() async {
    if (_hasPlayedAiGreeting ||
        _controller.isEnding ||
        _operatorAccepted ||
        _handoffRequested ||
        _hasSubmittedAiReport) {
      return;
    }
    _hasPlayedAiGreeting = true;
    if (mounted) {
      setState(
        () => _aiStatusMessage = 'AIGOR is ready. You may talk anytime.',
      );
    }
    try {
      await _speakText(_aiGreeting, allowInterrupt: true);
    } catch (error) {
      debugPrint('[SOS AI Voice] TTS speak failed: $error');
    } finally {
      if (_isAiTriageCall &&
          !_controller.isEnding &&
          !_operatorAccepted &&
          !_handoffRequested &&
          !_hasSubmittedAiReport &&
          !_isSubmittingAiReport) {
        Future.delayed(const Duration(milliseconds: 650), () {
          if (!_controller.isEnding &&
              !_operatorAccepted &&
              !_handoffRequested &&
              !_hasSubmittedAiReport &&
              !_isSubmittingAiReport) {
            if (_usesCallStreamForAiHearing) {
              _startCallStreamAiListening();
            } else {
              unawaited(_startAiReportListening());
            }
          }
        });
      }
    }
  }

  Future<void> _speakText(String text, {bool allowInterrupt = false}) async {
    if (_operatorAccepted) return;
    try {
      _isAiSpeaking = true;
      final playedNeuralVoice = await _playAigorNeuralVoice(text);
      if (!playedNeuralVoice) {
        debugPrint(
          '[SOS AI Voice] AIGOR voice was not played. Local phone TTS is disabled for this call.',
        );
      }
    } finally {
      _isAiSpeaking = false;
      await _endBargeInWindow();
    }
  }

  Future<bool> _playAigorNeuralVoice(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;

    try {
      final uri = Uri.parse(
        '${ApiService.baseUrl}/ai/tts',
      ).replace(queryParameters: {'voice': 'aigor', 'text': trimmed});
      final response = await http
          .get(uri, headers: const {'Bypass-Tunnel-Reminder': 'true'})
          .timeout(const Duration(seconds: 12));
      final contentType = (response.headers['content-type'] ?? '')
          .toLowerCase();
      final bytes = response.bodyBytes;
      final isPlayableVoice =
          contentType.contains('mpeg') ||
          contentType.contains('mp3') ||
          contentType.contains('audio/mpeg') ||
          _looksLikeMp3(bytes);
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          !isPlayableVoice ||
          bytes.length < 1200) {
        return false;
      }

      final completion = Completer<void>();
      _activeNeuralVoiceCompleter = completion;
      late final StreamSubscription<void> completeSub;
      completeSub = _neuralVoicePlayer.onPlayerComplete.listen((_) {
        if (!completion.isCompleted) completion.complete();
      });
      final fallbackTimer = Timer(const Duration(seconds: 18), () {
        if (!completion.isCompleted) completion.complete();
      });

      try {
        await _neuralVoicePlayer.stop();
        await _neuralVoicePlayer.setReleaseMode(ReleaseMode.stop);
        await _neuralVoicePlayer.play(
          BytesSource(bytes, mimeType: 'audio/mpeg'),
        );
        await completion.future;
        return true;
      } finally {
        fallbackTimer.cancel();
        await completeSub.cancel();
        if (_activeNeuralVoiceCompleter == completion) {
          _activeNeuralVoiceCompleter = null;
        }
      }
    } catch (error) {
      debugPrint('[SOS AI Voice] AIGOR neural voice unavailable: $error');
      return false;
    }
  }

  bool _looksLikeMp3(List<int> bytes) {
    if (bytes.length < 3) return false;
    final startsWithId3 =
        bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33;
    final startsWithFrame =
        bytes.length >= 2 && bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0;
    return startsWithId3 || startsWithFrame;
  }

  Future<void> _stopAiSpeech() async {
    if (_activeNeuralVoiceCompleter != null &&
        !_activeNeuralVoiceCompleter!.isCompleted) {
      _activeNeuralVoiceCompleter!.complete();
    }
    try {
      await _neuralVoicePlayer.stop();
    } catch (_) {}
  }

  Future<void> _endBargeInWindow() async {
    _bargeInTimer?.cancel();
    _bargeInTimer = null;
    _bargeInPrompt = null;
    if (!_bargeInActive) return;
    _bargeInActive = false;
    try {
      await _speech.stop();
    } catch (_) {}
  }

  bool _isPayloadForThisCall(dynamic data) {
    if (data is! Map) return false;
    final payload = Map<String, dynamic>.from(data);
    final expectedSosId = widget.callId.startsWith('sos_')
        ? widget.callId.substring(4)
        : null;
    final payloadSosId =
        payload['sos_id']?.toString() ?? payload['sosId']?.toString();
    if (expectedSosId != null &&
        payloadSosId != null &&
        payloadSosId == expectedSosId) {
      return true;
    }
    final payloadSessionId =
        payload['session_id']?.toString() ??
        payload['sessionId']?.toString() ??
        payload['ai_caller_session_id']?.toString() ??
        payload['aiCallerSessionId']?.toString();
    final expectedSessionIds = <String>{
      if (_aiCallerSessionId?.trim().isNotEmpty ?? false) _aiCallerSessionId!,
      if (widget.aiCallerSessionId?.trim().isNotEmpty ?? false)
        widget.aiCallerSessionId!,
      _deriveAiSessionId(widget.callId),
    };
    if (payloadSessionId != null &&
        payloadSessionId.isNotEmpty &&
        expectedSessionIds.contains(payloadSessionId)) {
      return true;
    }
    final payloadCallId =
        payload['room']?.toString() ??
        payload['room_name']?.toString() ??
        payload['roomName']?.toString() ??
        payload['key']?.toString() ??
        payload['call_id']?.toString() ??
        payload['callId']?.toString() ??
        payload['id']?.toString();
    if (payloadCallId == null || payloadCallId.isEmpty) return false;
    return _callAliasesFor(widget.callId).contains(payloadCallId) ||
        _callAliasesFor(_roomName).contains(payloadCallId);
  }

  void _handleAiCallerStarted(dynamic data) {
    if (!_isPayloadForThisCall(data)) return;
    if (_operatorAccepted ||
        _handoffRequested ||
        _hasSubmittedAiReport ||
        _controller.isEnding) {
      return;
    }
    if (data is Map) {
      final payload = Map<String, dynamic>.from(data);
      final sessionId =
          payload['session_id']?.toString() ??
          payload['sessionId']?.toString() ??
          payload['ai_caller_session_id']?.toString() ??
          payload['aiCallerSessionId']?.toString();
      if (sessionId != null && sessionId.isNotEmpty) {
        _aiCallerSessionId = sessionId;
      }
    }
    unawaited(_speakAiGreeting());
  }

  void _handleAiCallerAudioReceived(dynamic data) {
    if (!_isPayloadForThisCall(data)) return;
    _startCallStreamAiListening();
  }

  void _handleAiCallerTranscribed(dynamic data) {
    if (!_isPayloadForThisCall(data)) return;
    if (!mounted || _controller.isEnding) return;
    setState(
      () => _aiStatusMessage =
          'Narinig ni AIGOR ang report. Inaayos ang details...',
    );
  }

  void _handleAiTriageCompleted(dynamic data) {
    if (!_isPayloadForThisCall(data)) return;
    _hasSubmittedAiReport = true;
    if (!mounted || _controller.isEnding) return;
    setState(
      () => _aiStatusMessage =
          'Na-save ni AIGOR ang report. Waiting for operator...',
    );
  }

  void _handleAiOperatorHandoff(dynamic data) {
    if (!_isPayloadForThisCall(data)) return;
    _handoffRequested = true;
    if (!mounted || _controller.isEnding) return;
    setState(
      () => _aiStatusMessage =
          'Report sent. Waiting for command center to accept...',
    );
  }

  void _handleAiCallerFailed(dynamic data) {
    if (!_isPayloadForThisCall(data)) return;
    if (mounted && !_controller.isEnding) {
      setState(
        () => _aiStatusMessage =
            'Hindi malinaw ang audio. Ikokonekta ka sa operator.',
      );
    }
    unawaited(_handoffToOperator());
  }

  void _startCallStreamAiListening() {
    if (_hasStartedAiListening ||
        _hasSubmittedAiReport ||
        _isSubmittingAiReport ||
        _controller.isEnding) {
      return;
    }
    _hasStartedAiListening = true;
    _aiListenAttempt += 1;
    _callerReportDraft = '';
    if (mounted) {
      setState(
        () => _aiStatusMessage =
            'Nakikinig si AIGOR sa tawag. Sabihin nang malinaw ang emergency.',
      );
    }
    unawaited(_controller.setNativeMicrophoneMuted(false));
  }

  Future<void> _startAiReportListening() async {
    if (_usesCallStreamForAiHearing) {
      _startCallStreamAiListening();
      return;
    }
    if (_hasStartedAiListening ||
        _hasSubmittedAiReport ||
        _isSubmittingAiReport ||
        _controller.isEnding) {
      return;
    }
    _hasStartedAiListening = true;
    _aiListenAttempt += 1;
    _callerReportDraft = '';
    _setAiStatus('Checking microphone for AIGOR...');

    try {
      final hasMicPermission = await _ensureMicrophonePermission();
      if (!hasMicPermission) {
        throw StateError('Microphone permission was not granted.');
      }
      _setAiStatus('Microphone is allowed. Preparing AIGOR to listen...');
      await _prepareSpeechRecognizerForCaller();
      if (_isAiTriageCall) {
        await Future.delayed(const Duration(milliseconds: 850));
      }
      _setAiStatus('Starting phone speech recognition...');
      final available = await _speech.initialize(
        onStatus: _handleSpeechStatus,
        onError: _handleSpeechError,
        debugLogging: _speechDiagnosticsEnabled,
        finalTimeout: const Duration(seconds: 2),
      );
      if (!available) {
        throw StateError('Speech recognition is not available on this device.');
      }
      _setAiStatus('Speech recognition ready. Listening now...');
      _preferredSpeechLocaleId ??= await _pickSpeechLocaleId();
      _listenStartedAt = DateTime.now();
      await _speech.listen(
        onResult: _handleSpeechResult,
        onSoundLevelChange: _handleSpeechSoundLevel,
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 45),
          pauseFor: const Duration(seconds: 8),
          localeId: _preferredSpeechLocaleId,
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );
      _setAiStatus(
        _speech.isListening
            ? 'Listening now. Please say the emergency clearly.'
            : 'Speech recognition started, waiting for microphone...',
      );
    } catch (error) {
      debugPrint('[SOS AI Voice] Speech listen failed: $error');
      _setAiStatus('AIGOR could not start listening: $error');
      await _speakAndHandoff(
        'Nagkaproblema ako sa pakikinig. Ikokonekta na kita sa operator.',
      );
    }
  }

  Future<void> _prepareSpeechRecognizerForCaller() async {
    try {
      if (_isAiTriageCall) {
        await _stopAiSpeech();
        await _controller.pausePublishingForAiTriage();
      }
    } catch (error) {
      debugPrint('[SOS AI Voice] Could not prepare call mic for STT: $error');
    }
    try {
      await _speech.stop();
    } catch (_) {}
  }

  Future<bool> _ensureMicrophonePermission() async {
    try {
      final current = await Permission.microphone.status;
      debugPrint('[SOS AI Voice] Microphone permission status: $current');
      if (current.isGranted || current.isLimited) return true;
      final requested = await Permission.microphone.request();
      debugPrint('[SOS AI Voice] Microphone permission requested: $requested');
      return requested.isGranted || requested.isLimited;
    } catch (error) {
      debugPrint('[SOS AI Voice] Microphone permission check failed: $error');
      return true;
    }
  }

  Future<String?> _pickSpeechLocaleId() async {
    try {
      final locales = await _speech.locales();
      final localeIds = locales.map((locale) => locale.localeId).toList();
      for (final preferred in ['fil_PH', 'tl_PH', 'en_PH', 'en_US']) {
        if (localeIds.contains(preferred)) return preferred;
      }
      final systemLocale = await _speech.systemLocale();
      return systemLocale?.localeId;
    } catch (error) {
      debugPrint('[SOS AI Voice] Could not choose speech locale: $error');
      return null;
    }
  }

  void _handleSpeechResult(SpeechRecognitionResult result) {
    final words = result.recognizedWords.trim();
    debugPrint(
      '[SOS AI Voice] Raw speech result="$words" final=${result.finalResult} confidence=${result.confidence}',
    );
    if (words.isNotEmpty && mounted) {
      setState(() => _aiStatusMessage = 'Narinig ni AIGOR: $words');
    }
    if (_bargeInActive && _isAiSpeaking) {
      if (!_isLikelyCallerSpeech(
        words,
        confidence: result.confidence,
        forInterrupt: true,
      )) {
        return;
      }
      _callerReportDraft = words;
      if (mounted) {
        setState(() => _aiStatusMessage = 'Narinig ko po: $words');
      }
      if (result.finalResult || _looksUrgentEnoughToInterrupt(words)) {
        _bargeInActive = false;
        unawaited(_stopAiSpeech());
        unawaited(_handleCallerTranscript(words));
      }
      return;
    }

    if (_isLikelyCallerSpeech(
      words,
      confidence: result.confidence,
      forInterrupt: false,
    )) {
      _callerReportDraft = words;
      if (mounted) {
        setState(() => _aiStatusMessage = 'Narinig ko po: $words');
      }
    }
    if (result.finalResult &&
        _isLikelyCallerSpeech(
          words,
          confidence: result.confidence,
          forInterrupt: false,
        )) {
      unawaited(_handleCallerTranscript(words));
    }
  }

  void _handleSpeechStatus(String status) {
    debugPrint('[SOS AI Voice] Speech status: $status');
    if (mounted) {
      setState(() => _aiStatusMessage = _speechStatusMessage(status));
    }
    if (status == 'notListening' || status == 'done') {
      if (_bargeInActive && _isAiSpeaking) {
        final draft = _callerReportDraft.trim();
        if (_isLikelyCallerSpeech(draft, forInterrupt: true)) {
          _bargeInActive = false;
          unawaited(_stopAiSpeech());
          unawaited(_handleCallerTranscript(draft));
        }
        return;
      }

      final draft = _callerReportDraft.trim();
      if (!_hasSubmittedAiReport &&
          !_isSubmittingAiReport &&
          !_isHandlingCallerTranscript) {
        if (_isLikelyCallerSpeech(draft, forInterrupt: false)) {
          unawaited(_handleCallerTranscript(draft));
        } else {
          final startedAt = _listenStartedAt;
          final listenedMs = startedAt == null
              ? 0
              : DateTime.now().difference(startedAt).inMilliseconds;
          if (listenedMs < 2500 && _aiListenAttempt < 4) {
            _hasStartedAiListening = false;
            Future.delayed(const Duration(milliseconds: 450), () {
              if (!_controller.isEnding && !_hasSubmittedAiReport) {
                unawaited(_startAiReportListening());
              }
            });
            return;
          }
          unawaited(_retryOrHandoffAfterNoSpeech());
        }
      }
    }
  }

  void _handleSpeechError(SpeechRecognitionError error) {
    debugPrint(
      '[SOS AI Voice] Speech error: ${error.errorMsg} permanent=${error.permanent}',
    );
    _setAiStatus('Speech error: ${error.errorMsg}');
    if (_bargeInActive && _isAiSpeaking) {
      return;
    }
    if (!_hasSubmittedAiReport &&
        !_isSubmittingAiReport &&
        !_isHandlingCallerTranscript) {
      unawaited(_retryOrHandoffAfterNoSpeech());
    }
  }

  Future<void> _retryOrHandoffAfterNoSpeech() async {
    if (_controller.isEnding ||
        _hasSubmittedAiReport ||
        _isSubmittingAiReport ||
        _isHandlingCallerTranscript) {
      return;
    }
    if (_hasAskedAiFollowUp && _pendingAiReportTranscript.trim().isNotEmpty) {
      await _submitAiReport(_pendingAiReportTranscript);
      return;
    }
    _hasStartedAiListening = false;
    if (_aiListenAttempt < 3) {
      await _speakText(_retryPromptForAttempt(), allowInterrupt: true);
      unawaited(_startAiReportListening());
      return;
    }
    await _speakAndHandoff(
      'Hindi ko pa rin malinaw na narinig. Ikokonekta ko na kayo sa operator.',
    );
  }

  void _handleSpeechSoundLevel(double level) {
    if (!_speechDiagnosticsEnabled) return;
    debugPrint('[SOS AI Voice] Sound level: ${level.toStringAsFixed(2)}');
  }

  void _setAiStatus(String message) {
    debugPrint('[SOS AI Voice] $message');
    if (!mounted) return;
    setState(() => _aiStatusMessage = message);
  }

  String _speechStatusMessage(String status) {
    switch (status) {
      case 'listening':
        return 'Listening now. Please say the emergency clearly.';
      case 'notListening':
        return _callerReportDraft.trim().isEmpty
            ? 'AIGOR stopped listening but did not receive words yet.'
            : 'AIGOR received your words.';
      case 'done':
        return _callerReportDraft.trim().isEmpty
            ? 'AIGOR finished listening but heard no clear words.'
            : 'AIGOR finished listening.';
      default:
        return 'Speech status: $status';
    }
  }

  String _retryPromptForAttempt() {
    if (_aiListenAttempt <= 1) {
      return 'AIGOR ito. Medyo mahina ang dating ng boses. Pakisabi ulit kung ano ang emergency.';
    }
    return 'Nandito pa ako. Sabihin mo kahit maikli lang, tulad ng sunog, aksidente, baha, o may nasaktan.';
  }

  bool _isLikelyCallerSpeech(
    String words, {
    double confidence = 0,
    bool forInterrupt = false,
  }) {
    final normalized = _normalizeSpeechText(words);
    if (normalized.isEmpty || _looksLikeAiEcho(words)) return false;

    final tokens = normalized
        .split(' ')
        .where((token) => token.trim().length > 1)
        .toList();
    if (tokens.isEmpty) return false;

    final fillerOnly = tokens.every(
      (token) => const {'ah', 'uh', 'um', 'hmm', 'mmm', 'ha'}.contains(token),
    );
    if (fillerOnly) return false;
    if (confidence > 0 && confidence < 0.18) return false;

    final urgent = _looksUrgentEnoughToInterrupt(normalized);
    if (forInterrupt) {
      return urgent || tokens.length >= 3 || normalized.length >= 14;
    }
    return urgent || tokens.length >= 2 || normalized.length >= 6;
  }

  bool _looksUrgentEnoughToInterrupt(String words) {
    final normalized = _normalizeSpeechText(words);
    return _containsAny(normalized, [
      'tulong',
      'help',
      'saklolo',
      'sunog',
      'fire',
      'baha',
      'flood',
      'aksidente',
      'accident',
      'nasaktan',
      'ambulance',
      'suntukan',
      'nagkakasuntukan',
      'away',
      'gulo',
      'baril',
      'armas',
      'saksak',
      'police',
      'pulis',
    ]);
  }

  Future<void> _handleCallerTranscript(String transcript) async {
    final cleaned = transcript.trim();
    if (cleaned.isEmpty ||
        _hasSubmittedAiReport ||
        _isSubmittingAiReport ||
        _isHandlingCallerTranscript ||
        _controller.isEnding) {
      return;
    }

    _isHandlingCallerTranscript = true;
    try {
      await _speech.stop();
    } catch (_) {}

    try {
      if (_shouldSubmitImmediately(cleaned)) {
        _followUpFallbackTimer?.cancel();
        _pendingAiReportTranscript = cleaned;
        if (mounted) {
          setState(
            () => _aiStatusMessage = 'AIGOR understood. Saving report...',
          );
        }
        await _submitAiReport(cleaned);
        return;
      }

      if (!_hasAskedAiFollowUp) {
        _followUpFallbackTimer?.cancel();
        _pendingAiReportTranscript = cleaned;
        _hasAskedAiFollowUp = true;
        _hasStartedAiListening = false;
        if (mounted) {
          setState(() => _aiStatusMessage = 'AIGOR is checking details...');
        }
        await _speakText(_buildAigorFollowUp(cleaned), allowInterrupt: true);
        if (!_controller.isEnding &&
            !_hasSubmittedAiReport &&
            !_isSubmittingAiReport) {
          _callerReportDraft = '';
          unawaited(_startAiReportListening());
          _armFollowUpFallback();
        }
        return;
      }

      _followUpFallbackTimer?.cancel();
      final combined = [
        _pendingAiReportTranscript.trim(),
        cleaned,
      ].where((part) => part.isNotEmpty).join(' ');
      await _submitAiReport(combined);
    } finally {
      _isHandlingCallerTranscript = false;
    }
  }

  void _armFollowUpFallback() {
    _followUpFallbackTimer?.cancel();
    _followUpFallbackTimer = Timer(const Duration(seconds: 10), () {
      final pending = _pendingAiReportTranscript.trim();
      if (pending.isEmpty ||
          _controller.isEnding ||
          _hasSubmittedAiReport ||
          _isSubmittingAiReport ||
          _isHandlingCallerTranscript) {
        return;
      }
      unawaited(_submitAiReport(pending));
    });
  }

  String _buildAigorFollowUp(String transcript) {
    final text = transcript.toLowerCase();
    final hasInjury = _containsAny(text, [
      'nasaktan',
      'injured',
      'sugat',
      'dugo',
      'nahimatay',
      'unconscious',
    ]);
    final hasTrapped = _containsAny(text, [
      'trapped',
      'naipit',
      'nakulong',
      'hindi makalabas',
      'stuck',
    ]);

    if (_containsAny(text, [
      'sunog',
      'fire',
      'nasusunog',
      'smoke',
      'usok',
      'apoy',
      'burning',
    ])) {
      if (hasInjury || hasTrapped) {
        return 'Copy, fire emergency with possible rescue need. Lumayo sa usok kung kaya. Nasaan banda ang tao, loob ba ng bahay o labas?';
      }
      return 'Copy, fire emergency. Ire-record ko agad ito. Kung ligtas magsalita, sabihin kung may tao sa loob o may nasaktan.';
    }
    if (_containsAny(text, [
      'suntukan',
      'nagkakasuntukan',
      'away',
      'gulo',
      'riot',
      'barilan',
      'saksak',
      'weapon',
      'armas',
    ])) {
      return 'Copy, may public safety threat. Lumayo at magtago kung kaya. May armas ba o may nasaktan?';
    }
    if (_containsAny(text, [
      'aksidente',
      'accident',
      'bangga',
      'nabangga',
      'crash',
      'nadisgrasya',
    ])) {
      return 'Copy, accident report. Ire-record ko ito. May injured ba o kailangan ng ambulance?';
    }
    if (_containsAny(text, ['baha', 'flood', 'lubog', 'ulan'])) {
      return 'Copy, flood emergency. Pumunta sa mas mataas na lugar kung kaya. May stranded ba o kailangan ng rescue?';
    }
    if (_containsAny(text, ['tulong', 'help', 'saklolo', 'emergency'])) {
      return 'Nandito ako. Sabihin mo muna ang pinaka-delikasong nangyayari: sunog, aksidente, baha, gulo, o may nasaktan?';
    }
    return 'Narinig kita. Para maipasa ko nang tama, ano ang emergency at may tao bang nasaktan o nanganganib ngayon?';
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any(text.contains);
  }

  bool _shouldSubmitImmediately(String transcript) {
    final text = transcript.toLowerCase();
    return _containsAny(text, [
      'sunog',
      'fire',
      'nasusunog',
      'apoy',
      'usok',
      'smoke',
      'burning',
      'baha',
      'flood',
      'lindol',
      'earthquake',
      'aksidente',
      'accident',
      'bangga',
      'medical',
      'ambulance',
      'nasaktan',
      'sugat',
      'baril',
      'armas',
      'saksak',
      'kidnap',
      'robbery',
      'holdap',
      'suntukan',
      'away',
      'gulo',
    ]);
  }

  Future<void> _submitAiReport(String transcript) async {
    final cleaned = transcript.trim();
    if (cleaned.isEmpty ||
        _hasSubmittedAiReport ||
        _isSubmittingAiReport ||
        _controller.isEnding) {
      return;
    }
    _hasSubmittedAiReport = true;
    _isSubmittingAiReport = true;
    _followUpFallbackTimer?.cancel();
    if (mounted) {
      setState(() => _aiStatusMessage = 'Sine-save ko po ang report ninyo...');
    }

    try {
      await _speech.stop();
    } catch (_) {}

    try {
      final token = await apiService.getToken();
      final sessionId = _aiCallerSessionId ?? _deriveAiSessionId(widget.callId);
      final uri = Uri.parse(
        '${ApiService.baseUrl}/ai-caller/sessions/${Uri.encodeComponent(sessionId)}/transcript',
      );
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'text': cleaned, 'final': true, 'analyze': true}),
          )
          .timeout(const Duration(seconds: 25));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('AI report save failed: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      final session = decoded is Map ? decoded['session'] : null;
      final responseText = _buildAiAcknowledgement(session);
      await _speakAndHandoff(responseText);
    } catch (error) {
      debugPrint('[SOS AI Voice] Report submit failed: $error');
      await _speakAndHandoff(
        'Nagkaproblema sa pag-save ng report. Ikokonekta na kita sa operator.',
      );
    } finally {
      _isSubmittingAiReport = false;
    }
  }

  String _buildAiAcknowledgement(dynamic session) {
    final payload = session is Map
        ? Map<String, dynamic>.from(session)
        : <String, dynamic>{};
    final analysis = payload['analysis'] is Map
        ? Map<String, dynamic>.from(payload['analysis'] as Map)
        : <String, dynamic>{};
    final title = analysis['title']?.toString().trim();
    final severity = analysis['severity']?.toString().trim();
    final category =
        analysis['operator_category']?.toString().trim() ??
        analysis['operatorCategory']?.toString().trim() ??
        analysis['category']?.toString().trim();
    final summary =
        payload['handoff_summary']?.toString().trim() ??
        payload['handoffSummary']?.toString().trim();

    final details = title != null && title.isNotEmpty
        ? title
        : (summary != null && summary.isNotEmpty
              ? summary
              : 'your emergency report');
    final severityText = severity != null && severity.isNotEmpty
        ? ' Priority niya ay $severity.'
        : '';
    final safetyLine = _safetyLineForCategory(category);
    return 'Okay, na-save ko na: $details.$severityText $safetyLine Ipapasa na kita sa operator. Stay on the line.';
  }

  String _safetyLineForCategory(String? category) {
    final normalized = (category ?? '').toLowerCase();
    if (normalized.contains('fire')) {
      return 'Lumayo muna sa apoy at usok kung kaya.';
    }
    if (normalized.contains('fight') ||
        normalized.contains('weapon') ||
        normalized.contains('police')) {
      return 'Unahin ang safety mo at lumayo sa gulo kung kaya.';
    }
    if (normalized.contains('medical')) {
      return 'Kung may injured, huwag gagalawin kung delikado ang galaw.';
    }
    if (normalized.contains('disaster')) {
      return 'Pumunta sa mas ligtas o mas mataas na lugar kung kaya.';
    }
    if (normalized.contains('traffic')) {
      return 'Kung nasa kalsada ka, lumipat sa ligtas na gilid kung kaya.';
    }
    return 'Manatili sa ligtas na lugar kung kaya.';
  }

  Future<void> _speakAndHandoff(String message) async {
    if (_controller.isEnding) return;
    if (mounted) {
      setState(() => _aiStatusMessage = 'AIGOR is responding...');
    }
    try {
      await _speech.stop();
    } catch (_) {}
    try {
      await _stopAiSpeech();
    } catch (_) {}
    try {
      await _speakText(message);
    } catch (error) {
      debugPrint('[SOS AI Voice] Acknowledgement failed: $error');
    }
    await _handoffToOperator();
  }

  bool _looksLikeAiEcho(String words) {
    final prompt = _bargeInPrompt;
    if (prompt == null || prompt.isEmpty) return false;
    final heard = _normalizeSpeechText(words);
    final spoken = _normalizeSpeechText(prompt);
    if (heard.length < 4 || spoken.isEmpty) return false;
    if (spoken.contains(heard)) return true;

    final heardTokens = heard.split(' ').where((token) => token.length > 2);
    final spokenTokens = spoken.split(' ').where((token) => token.length > 2);
    if (heardTokens.isEmpty) return false;
    final spokenSet = spokenTokens.toSet();
    final matches = heardTokens.where(spokenSet.contains).length;
    return matches / heardTokens.length >= 0.75;
  }

  String _normalizeSpeechText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9ñ ]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  Future<void> _handoffToOperator() async {
    if (_controller.isEnding || _handoffRequested) return;
    _handoffRequested = true;
    if (mounted) {
      setState(
        () => _aiStatusMessage =
            'Report sent. Waiting for the command center to accept...',
      );
    }
    try {
      final token = await apiService.getToken();
      final sessionId = _aiCallerSessionId ?? _deriveAiSessionId(widget.callId);
      final uri = Uri.parse(
        '${ApiService.baseUrl}/ai-caller/sessions/${Uri.encodeComponent(sessionId)}/handoff',
      );
      await http
          .post(
            uri,
            headers: {if (token != null) 'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
    } catch (error) {
      debugPrint('[SOS AI Voice] Handoff request failed: $error');
      if (mounted) {
        setState(
          () => _aiStatusMessage =
              'Report saved. Waiting for command center connection...',
        );
      }
    }
  }

  Future<void> _handleOperatorAccepted(dynamic data) async {
    String? incomingOperatorName;
    if (data is Map) {
      final payload = Map<String, dynamic>.from(data);
      final action = payload['action']?.toString();
      if (action != null && action != 'accepted') return;
      incomingOperatorName = _operatorNameFromPayload(payload);
    }
    if (!_isPayloadForThisCall(data)) return;
    if (incomingOperatorName != null) {
      _acceptedOperatorName = incomingOperatorName;
    }
    if (_operatorAccepted) {
      if (incomingOperatorName != null && mounted) setState(() {});
      return;
    }
    _operatorAccepted = true;
    _handoffRequested = true;
    _hasSubmittedAiReport = true;
    _followUpFallbackTimer?.cancel();
    _bargeInTimer?.cancel();
    if (mounted) {
      setState(
        () => _aiStatusMessage = 'Command center accepted. Connecting call...',
      );
    }
    try {
      await _speech.stop();
    } catch (_) {}
    try {
      await _stopAiSpeech();
    } catch (_) {}
    try {
      await _controller.setNativeMicrophoneMuted(false);
      await _controller.resumePublishingAfterAiTriage();
    } catch (error) {
      debugPrint('[SOS AI Voice] Could not resume ZEGO publishing: $error');
    }
  }

  Future<void> _closeFromRemoteEnd() async {
    if (!_controller.isEnding) {
      _controller.closeWithoutNativeCleanup();
    }
    _handoffRequested = true;
    SignalingService.instance.markCallEnded(_roomName);
    _followUpFallbackTimer?.cancel();
    try {
      await _speech.stop();
    } catch (_) {}
    try {
      await _stopAiSpeech();
    } catch (_) {}
    _returnHomeAfterCall();
  }

  void _handleRemoteEndCall(dynamic data) {
    if (!_isPayloadForThisCall(data)) return;
    _closeFromRemoteEnd();
  }

  void _handleGlobalCallEnded(Map<String, dynamic> data) {
    if (!_isPayloadForThisCall(data) && _hasExplicitCallIdentity(data)) return;
    unawaited(_closeFromRemoteEnd());
  }

  Future<void> _endCall() async {
    if (_hasRequestedCallEnd) return;
    _hasRequestedCallEnd = true;
    final shouldNotify = !_controller.isEnding;
    _controller.closeWithoutNativeCleanup();
    _handoffRequested = true;
    _followUpFallbackTimer?.cancel();
    SignalingService.instance.markCallEnded(_roomName);
    _returnHomeAfterCall();
    Future.microtask(() {
      if (shouldNotify) {
        SignalingService.instance.endCall(_roomName);
      }
      unawaited(_speech.stop().catchError((_) {}));
      unawaited(_stopAiSpeech().catchError((_) {}));
    });
  }

  void _returnHomeAfterCall() {
    if (!mounted) return;
    ScaffoldMessenger.maybeOf(context)?.hideCurrentSnackBar();
    context.go('/home');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = Navigator.of(context, rootNavigator: true);
      navigator.popUntil((route) => route.isFirst);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isConnected = _operatorAccepted && _controller.hasRemoteParticipant;
    final localPreview = isConnected ? _controller.localView : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: !isConnected
                  ? CallStatus(
                      message:
                          _controller.error ??
                          (_controller.isConnecting
                              ? _operatorAccepted
                                    ? 'Connecting to $_currentPeerDisplayName...'
                                    : 'Connecting to AIGOR...'
                              : _isAiTriageCall
                              ? _aiStatusMessage
                              : 'Waiting for Command Center...'),
                      loading:
                          _controller.isConnecting && _controller.error == null,
                    )
                  : _ZegoVideoSurface(
                      view: _controller.remoteView ?? _controller.localView,
                      label: _controller.remoteView == null
                          ? (_operatorAccepted
                                ? _currentPeerDisplayName
                                : _aiStatusMessage)
                          : _currentPeerDisplayName,
                      compact: false,
                    ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: CallHeader(
                callId: widget.callId,
                isConnected: isConnected,
                displayName: _currentPeerDisplayName,
              ),
            ),
            if (localPreview != null)
              Positioned(
                right: 16,
                top: 96,
                width: isConnected ? 118 : 136,
                height: isConnected ? 158 : 182,
                child: _ZegoVideoSurface(
                  view: localPreview,
                  label: isConnected ? 'You' : 'Camera ready',
                  compact: true,
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24,
              child: Center(
                child: CallControls(
                  micEnabled: _controller.isMicEnabled,
                  cameraEnabled: _controller.isCameraEnabled,
                  onToggleMic: _controller.toggleMicrophone,
                  onToggleCamera: _controller.toggleCamera,
                  onEnd: _endCall,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _roomNameForCall(String callId) {
  return callId.startsWith('call_') || callId.startsWith('sos_')
      ? callId
      : 'call_$callId';
}

Set<String> _callAliasesFor(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return const {};
  final aliases = <String>{raw};
  final withoutCall = raw.startsWith('call_') ? raw.substring(5) : raw;
  aliases.add(withoutCall);
  aliases.add('call_$withoutCall');
  if (withoutCall.startsWith('sos_')) {
    final sosId = withoutCall.substring(4);
    if (sosId.isNotEmpty) {
      aliases.add(sosId);
      aliases.add('call_$sosId');
      aliases.add('sos_$sosId');
      aliases.add('call_sos_$sosId');
    }
  }
  return aliases;
}

bool _hasExplicitCallIdentity(Map<String, dynamic> payload) {
  return payload.containsKey('room') ||
      payload.containsKey('room_name') ||
      payload.containsKey('roomName') ||
      payload.containsKey('key') ||
      payload.containsKey('call_id') ||
      payload.containsKey('callId') ||
      payload.containsKey('id') ||
      payload.containsKey('sos_id') ||
      payload.containsKey('sosId');
}

String _deriveAiSessionId(String callId) {
  final cleaned = callId
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return 'ai_${cleaned.isEmpty ? 'unknown' : cleaned}';
}

class _ZegoVideoSurface extends StatelessWidget {
  final Widget? view;
  final String label;
  final bool compact;

  const _ZegoVideoSurface({
    required this.view,
    required this.label,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B),
        borderRadius: BorderRadius.circular(compact ? 16 : 24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.12),
          width: 1.5,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (view != null)
            view!
          else
            CameraOffPlaceholder(
              name: label,
              compact: compact,
              isSpeaking: false,
            ),
          Positioned(
            left: compact ? 8 : 16,
            bottom: compact ? 8 : 16,
            right: compact ? 8 : 16,
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compact ? 8 : 12,
                  vertical: compact ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: compact ? 10 : 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
