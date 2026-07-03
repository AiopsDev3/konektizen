import 'dart:async';
import 'dart:convert';
import 'dart:math';
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
    with WidgetsBindingObserver, TickerProviderStateMixin {
  static const List<String> _aiGreetingOptions = [
    'AIGOR ito from the command center. Nandito ako. Ano ang emergency?',
    'This is AIGOR from the command center. I am listening. What is happening right now?',
    'AIGOR from the command center ito. Nandito ako. Ano ang kailangan mong tulong?',
  ];
  static const List<String> _noSpeechPromptOptions = [
    'Nandito pa ako. Hindi pa malinaw ang dating ng boses mo. Subukan ulit, kahit maikli lang.',
    'I am still listening. Sabihin mo muna kung ano ang emergency sa harap mo ngayon.',
    'Narito ako. Magsalita ka lang kapag kaya mo, at makikinig ako ulit.',
    'Hold mo ulit ang AIGOR mic at sabihin ang pinaka-importanteng nangyayari ngayon.',
  ];

  final Random _voiceRandom = Random();
  int _noSpeechPromptCursor = 0;

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
  bool _isPushToTalkRecording = false;
  bool _isHandlingCallerTranscript = false;
  bool _hasRequestedCallEnd = false;
  bool _speechInterruptedByCaller = false;
  final bool _speechDiagnosticsEnabled = true;
  int _aiListenAttempt = 0;
  int _callerTurnId = 0;
  int _latestTranscriptTurnId = 0;
  String? _aiCallerSessionId;
  String? _acceptedOperatorName;
  String? _preferredSpeechLocaleId;
  String? _bargeInPrompt;
  Timer? _bargeInTimer;
  Timer? _followUpFallbackTimer;
  Timer? _silenceNudgeTimer;
  Completer<void>? _activeNeuralVoiceCompleter;
  DateTime? _listenStartedAt;
  DateTime? _ignoreSpeechUntil;
  String _callerReportDraft = '';
  String _pushToTalkDraft = '';
  String _latestCallerTranscript = '';
  String _pendingAiReportTranscript = '';
  String _aiStatusMessage = 'AIGOR is preparing...';
  String _latestAigorSpeech =
      "Hello! I'm AIGOR, your AI emergency assistant. I'm here to help you.";
  Timer? _durationTimer;
  Duration _elapsed = Duration.zero;
  bool _isCallOnHold = false;
  bool _isSpeakerOn = true;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _roomName = widget.roomName ?? _roomNameForCall(widget.callId);
    _aiCallerSessionId =
        widget.aiCallerSessionId ?? _deriveAiSessionId(widget.callId);
    _operatorAccepted = !_isAiTriageCall;
    if (_operatorAccepted) {
      _acceptedOperatorName = widget.operatorName;
    }
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
    SignalingService.instance.socket?.on(
      'operator_accepted_sos',
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
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() => _elapsed = _elapsed + const Duration(seconds: 1));
      }
    });
    WakelockPlus.enable();
    if (_isAiTriageCall) {
      Future.delayed(const Duration(milliseconds: 180), () {
        unawaited(_speakAiGreeting());
      });
    }
  }

  @override
  void dispose() {
    if (!_hasRequestedCallEnd && !_controller.isEnding) {
      _hasRequestedCallEnd = true;
      SignalingService.instance.endCall(_roomName);
    }
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
      'operator_accepted_sos',
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
    _pulseController.dispose();
    _durationTimer?.cancel();
    _bargeInTimer?.cancel();
    _followUpFallbackTimer?.cancel();
    _silenceNudgeTimer?.cancel();
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
        (widget.aiCallerSessionId?.trim().isNotEmpty ?? false);
  }

  bool get _usesCallStreamForAiHearing => false;

  bool get _usesPushToTalkForAiTriage => true;

  bool get _canUseAigorPushToTalk {
    return _isAiTriageCall &&
        !_operatorAccepted &&
        !_handoffRequested &&
        !_hasSubmittedAiReport &&
        !_isSubmittingAiReport &&
        !_controller.isEnding;
  }

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
    final normalized = lower.replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (lower == 'ai' ||
        lower.contains('aigor') ||
        lower.contains('emergency ai') ||
        lower.contains('ai caller') ||
        normalized == 'systemad' ||
        normalized == 'ystemad' ||
        normalized == 'systemadmin' ||
        normalized == 'ystemadmin' ||
        normalized == 'administrator' ||
        normalized == 'admin' ||
        normalized.contains('systemad') ||
        normalized.contains('ystemad') ||
        normalized.startsWith('system')) {
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
      await _speakText(
        _pickVoiceLine(_aiGreetingOptions),
        allowInterrupt: true,
      );
    } catch (error) {
      debugPrint('[SOS AI Voice] TTS speak failed: $error');
    } finally {
      if (_isAiTriageCall &&
          !_controller.isEnding &&
          !_operatorAccepted &&
          !_handoffRequested &&
          !_hasSubmittedAiReport &&
          !_isSubmittingAiReport) {
        Future.delayed(const Duration(milliseconds: 250), () {
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

  Future<bool> _speakText(String text, {bool allowInterrupt = false}) async {
    if (_operatorAccepted) return false;
    if (mounted) {
      setState(() {
        _latestAigorSpeech = text;
      });
    }
    try {
      _bargeInTimer?.cancel();
      _silenceNudgeTimer?.cancel();
      _bargeInActive = false;
      _bargeInPrompt = null;
      _speechInterruptedByCaller = false;
      _ignoreSpeechUntil = DateTime.now().add(
        Duration(milliseconds: allowInterrupt ? 250 : 900),
      );
      try {
        await _speech.stop();
      } catch (_) {}
      _isAiSpeaking = true;
      if (allowInterrupt && !_usesPushToTalkForAiTriage) {
        await _startBargeInListening(text);
      }
      final playedNeuralVoice = await _playAigorNeuralVoice(text);
      if (!playedNeuralVoice) {
        debugPrint(
          '[SOS AI Voice] AIGOR voice was not played. Local phone TTS is disabled for this call.',
        );
      }
    } finally {
      _isAiSpeaking = false;
      _ignoreSpeechUntil = _isPushToTalkRecording
          ? null
          : DateTime.now().add(const Duration(milliseconds: 900));
      await _endBargeInWindow();
    }
    return _speechInterruptedByCaller;
  }

  String _pickVoiceLine(List<String> options) {
    if (options.isEmpty) return '';
    return options[_voiceRandom.nextInt(options.length)];
  }

  String _pickNoSpeechPrompt() {
    final context = [
      _pendingAiReportTranscript,
      _callerReportDraft,
      _latestCallerTranscript,
    ].where((part) => part.trim().isNotEmpty).join(' ').toLowerCase();
    final options = <String>[];
    if (_containsAny(context, [
      'aksidente',
      'accident',
      'bangga',
      'nagbanggaan',
      'nagkabanggaan',
      'nagbungguan',
      'kotse',
      'sasakyan',
      'crash',
    ])) {
      options.addAll([
        'Narinig ko ang aksidente. Hold mo ulit ang mic at sabihin kung may nasaktan, naipit, o nasa kalsada pa.',
        'May accident report na akong narinig. Sabihin mo kung kailangan ng ambulance o rescue ngayon.',
      ]);
    } else if (_containsAny(context, [
      'sunog',
      'fire',
      'apoy',
      'usok',
      'smoke',
    ])) {
      options.addAll([
        'Narinig ko ang sunog. Hold mo ulit ang mic at sabihin kung may tao sa loob o may nasaktan.',
        'May fire report na akong narinig. Sabihin mo kung saan ang apoy o usok at sino ang nanganganib.',
      ]);
    } else if (_containsAny(context, ['baha', 'flood', 'lubog'])) {
      options.addAll([
        'Narinig ko ang baha. Hold mo ulit ang mic at sabihin kung may stranded o kailangang i-rescue.',
        'May flood report na akong narinig. Sabihin mo kung gaano kataas ang tubig at sino ang nanganganib.',
      ]);
    }
    options.addAll(_noSpeechPromptOptions);
    final line = options[_noSpeechPromptCursor % options.length];
    _noSpeechPromptCursor += 1;
    return line;
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
          .timeout(const Duration(seconds: 8));
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
      final fallbackTimer = Timer(const Duration(seconds: 10), () {
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

  Future<void> _startBargeInListening(String prompt) async {
    if (!_isAiTriageCall ||
        _controller.isEnding ||
        _operatorAccepted ||
        _hasSubmittedAiReport ||
        _isSubmittingAiReport) {
      return;
    }
    try {
      final hasMicPermission = await _ensureMicrophonePermission();
      if (!hasMicPermission) return;
      final available = await _speech.initialize(
        onStatus: _handleSpeechStatus,
        onError: _handleSpeechError,
        debugLogging: _speechDiagnosticsEnabled,
        finalTimeout: const Duration(seconds: 1),
      );
      if (!available) return;
      _preferredSpeechLocaleId ??= await _pickSpeechLocaleId();
      _bargeInActive = true;
      _bargeInPrompt = prompt;
      _callerReportDraft = '';
      await _speech.listen(
        onResult: _handleSpeechResult,
        onSoundLevelChange: _handleSpeechSoundLevel,
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 20),
          pauseFor: const Duration(seconds: 1),
          localeId: _preferredSpeechLocaleId,
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );
      _bargeInTimer = Timer(const Duration(seconds: 20), () {
        unawaited(_endBargeInWindow());
      });
    } catch (error) {
      debugPrint('[SOS AI Voice] Barge-in listener failed: $error');
      _bargeInActive = false;
      _bargeInPrompt = null;
    }
  }

  bool _isPayloadForThisCall(dynamic data) {
    if (data is! Map) return false;
    final payload = Map<String, dynamic>.from(data);
    final action = payload['action']?.toString();
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
    final matchesCurrentCall =
        _callAliasesFor(widget.callId).contains(payloadCallId) ||
        _callAliasesFor(_roomName).contains(payloadCallId);
    if (matchesCurrentCall) return true;

    if (action == 'accepted' && _handoffRequested) {
      final currentAliases = {
        ..._callAliasesFor(widget.callId),
        ..._callAliasesFor(_roomName),
      };
      final payloadAliases = _callAliasesFor(payloadCallId);
      return payloadAliases.any(currentAliases.contains);
    }
    return false;
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
          'Na-save ni AIGOR ang report. Waiting for command center...',
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
            'Hindi malinaw ang audio. Ipapasa ka namin sa human operator.',
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
    if (_usesPushToTalkForAiTriage) {
      _hasStartedAiListening = false;
      _silenceNudgeTimer?.cancel();
      if (_canUseAigorPushToTalk) {
        _setAiStatus(
          'Hold the AIGOR mic button while speaking. Release when done.',
        );
        _armSilenceNudge();
      }
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
        await Future.delayed(const Duration(milliseconds: 150));
      }
      _setAiStatus('Starting phone speech recognition...');
      final available = await _speech.initialize(
        onStatus: _handleSpeechStatus,
        onError: _handleSpeechError,
        debugLogging: _speechDiagnosticsEnabled,
        finalTimeout: const Duration(seconds: 5),
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
          listenFor: const Duration(seconds: 120),
          pauseFor: const Duration(seconds: 5),
          localeId: _preferredSpeechLocaleId,
          partialResults: true,
          cancelOnError: false,
          listenMode: ListenMode.dictation,
        ),
      );
      _armSilenceNudge();
      _setAiStatus(
        _speech.isListening
            ? 'Listening now. Please say the emergency clearly.'
            : 'Speech recognition started, waiting for microphone...',
      );
    } catch (error) {
      debugPrint('[SOS AI Voice] Speech listen failed: $error');
      _setAiStatus('AIGOR could not start listening: $error');
      await _speakAndHandoff(
        'Nagkaproblema ako sa pakikinig. Ikokonekta na kita sa command center.',
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

  void _armSilenceNudge() {
    _silenceNudgeTimer?.cancel();
    _silenceNudgeTimer = Timer(const Duration(seconds: 10), () {
      if (_controller.isEnding ||
          _operatorAccepted ||
          _hasSubmittedAiReport ||
          _isSubmittingAiReport ||
          _isHandlingCallerTranscript ||
          _isAiSpeaking) {
        return;
      }
      final heardAnything = _callerReportDraft.trim().isNotEmpty;
      if (heardAnything) return;
      _hasStartedAiListening = false;
      unawaited(_speech.stop().catchError((_) {}));
      unawaited(
        _speakText(_pickNoSpeechPrompt(), allowInterrupt: true).then((_) {
          if (!_controller.isEnding &&
              !_operatorAccepted &&
              !_hasSubmittedAiReport &&
              !_isSubmittingAiReport) {
            unawaited(_startAiReportListening());
          }
        }),
      );
    });
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
    final ignoreUntil = _ignoreSpeechUntil;
    if (words.isNotEmpty &&
        ignoreUntil != null &&
        DateTime.now().isBefore(ignoreUntil)) {
      debugPrint('[SOS AI Voice] Ignoring likely AIGOR speaker echo: "$words"');
      return;
    }
    if (ignoreUntil != null && DateTime.now().isAfter(ignoreUntil)) {
      _ignoreSpeechUntil = null;
    }
    if (words.isNotEmpty && mounted) {
      _silenceNudgeTimer?.cancel();
      setState(() {
        _latestCallerTranscript = words;
        _aiStatusMessage = 'Narinig ni AIGOR: $words';
      });
    }
    if (_isPushToTalkRecording) {
      if (_isLikelyCallerSpeech(
        words,
        confidence: result.confidence,
        forInterrupt: false,
      )) {
        _callerReportDraft = words;
        _pushToTalkDraft = words;
        if (mounted) {
          setState(() => _aiStatusMessage = 'Recording: $words');
        }
      }
      return;
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
        _speechInterruptedByCaller = true;
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
    if (_usesPushToTalkForAiTriage && !_bargeInActive) {
      return;
    }
    if (status == 'notListening' || status == 'done') {
      _silenceNudgeTimer?.cancel();
      if (_bargeInActive && _isAiSpeaking) {
        final draft = _callerReportDraft.trim();
        if (_isLikelyCallerSpeech(draft, forInterrupt: true)) {
          _bargeInActive = false;
          _speechInterruptedByCaller = true;
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
    _silenceNudgeTimer?.cancel();
    if (_usesPushToTalkForAiTriage && !_bargeInActive) {
      if (_isPushToTalkRecording) {
        _isPushToTalkRecording = false;
        _hasStartedAiListening = false;
      }
      _setAiStatus(
        'Hindi malinaw ang nakuha. Hold the AIGOR mic and speak close to the phone.',
      );
      if (_pendingAiReportTranscript.trim().isEmpty) {
        _armSilenceNudge();
      } else {
        _armFollowUpFallback();
      }
      return;
    }
    if (_bargeInActive && _isAiSpeaking) {
      return;
    }
    if (!_hasSubmittedAiReport &&
        !_isSubmittingAiReport &&
        !_isHandlingCallerTranscript) {
      final draft = _callerReportDraft.trim();
      if (_isLikelyCallerSpeech(draft, forInterrupt: false)) {
        unawaited(_handleCallerTranscript(draft));
        return;
      }
      if (_isSpeechTimeout(error) && _aiListenAttempt < 8) {
        _hasStartedAiListening = false;
        Future.delayed(const Duration(milliseconds: 800), () {
          if (!_controller.isEnding && !_hasSubmittedAiReport) {
            unawaited(_startAiReportListening());
          }
        });
        return;
      }
      unawaited(_retryOrHandoffAfterNoSpeech());
    }
  }

  bool _isSpeechTimeout(SpeechRecognitionError error) {
    final message = error.errorMsg.toLowerCase();
    return message.contains('speech_timeout') ||
        message.contains('speech timeout') ||
        message.contains('no speech');
  }

  Future<void> _retryOrHandoffAfterNoSpeech() async {
    if (_controller.isEnding ||
        _hasSubmittedAiReport ||
        _isSubmittingAiReport ||
        _isHandlingCallerTranscript) {
      return;
    }
    _hasStartedAiListening = false;
    if (_aiListenAttempt < 8) {
      await _speakText(_retryPromptForAttempt(), allowInterrupt: true);
      unawaited(_startAiReportListening());
      return;
    }
    await _speakText(_pickNoSpeechPrompt(), allowInterrupt: true);
    unawaited(_startAiReportListening());
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
    if (_usesPushToTalkForAiTriage && !_bargeInActive) {
      switch (status) {
        case 'listening':
          return 'Recording. Keep holding while speaking.';
        case 'notListening':
        case 'done':
          return _callerReportDraft.trim().isEmpty
              ? 'Release received. No clear words yet.'
              : 'Release received. AIGOR is checking your message.';
        default:
          return 'Hold the AIGOR mic button while speaking.';
      }
    }
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
    return _pickNoSpeechPrompt();
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
    final conversational = _looksLikeHumanCallerMessage(normalized);
    if (forInterrupt) {
      return urgent ||
          conversational ||
          tokens.length >= 3 ||
          normalized.length >= 14;
    }
    return urgent ||
        conversational ||
        tokens.isNotEmpty ||
        normalized.length >= 3;
  }

  bool _looksLikeHumanCallerMessage(String words) {
    final normalized = _normalizeSpeechText(words);
    if (normalized.isEmpty) return false;
    if (_containsAny(normalized, [
      'hello',
      'helo',
      'hi',
      'hey',
      'aigor',
      'ai',
      'musta',
      'kumusta',
      'naririnig',
      'nandyan',
      'yes',
      'oo',
      'opo',
      'hindi',
      'no',
      'wait',
      'sandali',
      'teka',
      'tulong',
      'help',
      'saklolo',
    ])) {
      return true;
    }
    return normalized.length >= 3;
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

  bool _isCurrentCallerTurn(int turnId) {
    return turnId == _latestTranscriptTurnId &&
        !_controller.isEnding &&
        !_hasSubmittedAiReport &&
        !_isSubmittingAiReport;
  }

  Future<void> _handleCallerTranscript(String transcript, {int? turnId}) async {
    final cleaned = transcript.trim();
    final currentTurnId = turnId ?? ++_callerTurnId;
    if (turnId == null) {
      _latestTranscriptTurnId = currentTurnId;
      _latestCallerTranscript = cleaned;
    }
    if (cleaned.isEmpty ||
        _hasSubmittedAiReport ||
        _isSubmittingAiReport ||
        _controller.isEnding) {
      return;
    }
    if (currentTurnId != _latestTranscriptTurnId) return;
    if (_isHandlingCallerTranscript) {
      if (mounted) {
        setState(
          () =>
              _aiStatusMessage = 'AIGOR is switching to your latest message...',
        );
      }
      return;
    }

    _isHandlingCallerTranscript = true;
    try {
      await _speech.stop();
    } catch (_) {}

    try {
      final previousTranscript = _pendingAiReportTranscript.trim();
      final combinedTranscript = [
        previousTranscript,
        cleaned,
      ].where((part) => part.isNotEmpty).join(' ');
      unawaited(_syncAiTranscriptChunk(cleaned));

      if (!_isCurrentCallerTurn(currentTurnId)) return;
      if (_shouldSubmitImmediately(combinedTranscript)) {
        _followUpFallbackTimer?.cancel();
        _pendingAiReportTranscript = combinedTranscript;
        if (mounted) {
          setState(
            () => _aiStatusMessage = 'AIGOR understood. Saving report...',
          );
        }
        await _submitAiReport(combinedTranscript);
        return;
      }

      _followUpFallbackTimer?.cancel();
      _pendingAiReportTranscript = combinedTranscript;
      _hasStartedAiListening = false;
      if (mounted) {
        setState(() => _aiStatusMessage = 'AIGOR is thinking...');
      }
      final aiReply = await _requestAigorFollowUp(
        cleaned,
        history: previousTranscript,
      );
      if (!_isCurrentCallerTurn(currentTurnId)) return;
      final readyToSubmit = aiReply['ready_to_submit'] == true;
      final mergedTranscript =
          aiReply['merged_transcript']?.toString().trim() ?? combinedTranscript;
      if (readyToSubmit && _shouldSubmitImmediately(mergedTranscript)) {
        if (!_isCurrentCallerTurn(currentTurnId)) return;
        await _submitAiReport(
          mergedTranscript.isNotEmpty ? mergedTranscript : combinedTranscript,
        );
        return;
      }
      final followUp =
          aiReply['caller_reply']?.toString().trim().isNotEmpty == true
          ? aiReply['caller_reply'].toString().trim()
          : _buildAigorFollowUp(combinedTranscript);
      if (!_isCurrentCallerTurn(currentTurnId)) return;
      await _speakText(followUp, allowInterrupt: true);
      if (!_isCurrentCallerTurn(currentTurnId)) return;
      if (!_controller.isEnding &&
          !_hasSubmittedAiReport &&
          !_isSubmittingAiReport) {
        _callerReportDraft = '';
        unawaited(_startAiReportListening());
        _armFollowUpFallback();
      }
    } finally {
      _isHandlingCallerTranscript = false;
      final latestTranscript = _latestCallerTranscript.trim();
      if (_latestTranscriptTurnId > currentTurnId &&
          latestTranscript.isNotEmpty &&
          !_controller.isEnding &&
          !_hasSubmittedAiReport &&
          !_isSubmittingAiReport) {
        unawaited(
          _handleCallerTranscript(
            latestTranscript,
            turnId: _latestTranscriptTurnId,
          ),
        );
      }
    }
  }

  Future<void> _startPushToTalkRecording() async {
    if (!_canUseAigorPushToTalk || _isPushToTalkRecording) return;

    _silenceNudgeTimer?.cancel();
    _followUpFallbackTimer?.cancel();
    _bargeInTimer?.cancel();
    _bargeInActive = false;
    _bargeInPrompt = null;
    _speechInterruptedByCaller = true;
    _ignoreSpeechUntil = null;
    _callerTurnId += 1;
    _latestTranscriptTurnId = _callerTurnId;
    _latestCallerTranscript = '';
    unawaited(_stopAiSpeech());
    _callerReportDraft = '';
    _pushToTalkDraft = '';
    _isPushToTalkRecording = true;
    _hasStartedAiListening = true;
    _aiListenAttempt += 1;
    _listenStartedAt = DateTime.now();

    if (mounted) {
      setState(
        () => _aiStatusMessage =
            'Recording. Hold steady and speak close to the phone.',
      );
    }

    try {
      final hasMicPermission = await _ensureMicrophonePermission();
      if (!hasMicPermission) {
        throw StateError('Microphone permission was not granted.');
      }
      await _prepareSpeechRecognizerForCaller();
      final available = await _speech.initialize(
        onStatus: _handleSpeechStatus,
        onError: _handleSpeechError,
        debugLogging: _speechDiagnosticsEnabled,
        finalTimeout: const Duration(seconds: 2),
      );
      if (!available) {
        throw StateError('Speech recognition is not available on this device.');
      }
      _preferredSpeechLocaleId ??= await _pickSpeechLocaleId();
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
    } catch (error) {
      debugPrint('[SOS AI Voice] Push-to-talk failed: $error');
      _isPushToTalkRecording = false;
      _hasStartedAiListening = false;
      _setAiStatus(
        'AIGOR could not open the microphone. Please try holding the mic again.',
      );
    }
  }

  Future<void> _finishPushToTalkRecording() async {
    if (!_isPushToTalkRecording) return;

    _isPushToTalkRecording = false;
    _hasStartedAiListening = false;
    if (mounted) {
      setState(() => _aiStatusMessage = 'Checking your message...');
    }

    try {
      await _speech.stop();
    } catch (_) {}
    await Future.delayed(const Duration(milliseconds: 180));

    final draft =
        (_pushToTalkDraft.trim().isNotEmpty
                ? _pushToTalkDraft
                : _callerReportDraft)
            .trim();
    _pushToTalkDraft = '';

    if (_isLikelyCallerSpeech(draft, forInterrupt: false)) {
      final turnId = _latestTranscriptTurnId;
      _latestCallerTranscript = draft;
      if (_isHandlingCallerTranscript) {
        unawaited(_syncAiTranscriptChunk(draft));
        if (mounted) {
          setState(
            () => _aiStatusMessage =
                'AIGOR heard your latest message and is switching to it now.',
          );
        }
        return;
      }
      unawaited(_handleCallerTranscript(draft, turnId: turnId));
      return;
    }

    if (mounted && _canUseAigorPushToTalk) {
      setState(
        () => _aiStatusMessage =
            'Hindi pa malinaw ang nakuha. Hold the AIGOR mic and speak close to the phone.',
      );
    }
    if (_pendingAiReportTranscript.trim().isEmpty) {
      _armSilenceNudge();
    } else {
      _armFollowUpFallback();
    }
  }

  Future<void> _syncAiTranscriptChunk(String transcript) async {
    final cleaned = transcript.trim();
    if (cleaned.isEmpty || _controller.isEnding) return;
    try {
      final token = await apiService.getToken();
      final sessionId = _aiCallerSessionId ?? _deriveAiSessionId(widget.callId);
      final uri = Uri.parse(
        '${ApiService.baseUrl}/ai-caller/sessions/${Uri.encodeComponent(sessionId)}/transcript',
      );
      await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({
              'text': cleaned,
              'final': false,
              'analyze': false,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (error) {
      debugPrint('[SOS AI Voice] Transcript chunk sync failed: $error');
    }
  }

  Future<Map<String, dynamic>> _requestAigorFollowUp(
    String transcript, {
    String history = '',
  }) async {
    final fallback = <String, dynamic>{
      'ready_to_submit': false,
      'caller_reply': _buildAigorFollowUp(transcript),
      'merged_transcript': [
        history.trim(),
        transcript.trim(),
      ].where((part) => part.isNotEmpty).join(' '),
    };

    try {
      final token = await apiService.getToken();
      final sessionId = _aiCallerSessionId ?? _deriveAiSessionId(widget.callId);
      final uri = Uri.parse(
        '${ApiService.baseUrl}/ai-caller/sessions/${Uri.encodeComponent(sessionId)}/reply',
      );
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'text': transcript, 'history': history}),
          )
          .timeout(const Duration(seconds: 8));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return fallback;
      }
      final decoded = jsonDecode(response.body);
      final reply = decoded is Map ? decoded['reply'] : null;
      if (reply is! Map) return fallback;
      return Map<String, dynamic>.from(reply);
    } catch (error) {
      debugPrint('[SOS AI Voice] AIGOR follow-up request failed: $error');
      return fallback;
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
      _hasStartedAiListening = false;
      unawaited(
        _speakCurrentTranscriptFollowUp(pending).then((_) {
          if (!_controller.isEnding &&
              !_hasSubmittedAiReport &&
              !_isSubmittingAiReport) {
            unawaited(_startAiReportListening());
          }
        }),
      );
    });
  }

  Future<void> _speakCurrentTranscriptFollowUp(String pendingTranscript) async {
    final currentTranscript = pendingTranscript.trim();
    if (currentTranscript.isEmpty ||
        _controller.isEnding ||
        _hasSubmittedAiReport ||
        _isSubmittingAiReport) {
      return;
    }

    final aiReply = await _requestAigorFollowUp(currentTranscript);
    final mergedTranscript =
        aiReply['merged_transcript']?.toString().trim() ?? currentTranscript;
    if (aiReply['ready_to_submit'] == true &&
        _shouldSubmitImmediately(mergedTranscript)) {
      await _submitAiReport(
        mergedTranscript.isNotEmpty ? mergedTranscript : currentTranscript,
      );
      return;
    }

    final followUp =
        aiReply['caller_reply']?.toString().trim().isNotEmpty == true
        ? aiReply['caller_reply'].toString().trim()
        : _buildAigorFollowUp(currentTranscript);
    await _speakText(followUp, allowInterrupt: true);
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
        return 'Copy, may sunog. Lumayo sa usok kung kaya. Saan banda ito, at nasa loob ba o labas ang taong nanganganib?';
      }
      return 'Copy, may sunog. Kung ligtas magsalita, ano ang nangyayari ngayon, saan banda, at may tao ba sa loob o may nasaktan?';
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
      'nagbanggaan',
      'nagkabanggaan',
      'nagbungguan',
      'bungguan',
      'salpukan',
      'kotse',
      'sasakyan',
      'crash',
      'nadisgrasya',
    ])) {
      return 'Narinig ko ang aksidente. May nasaktan, naipit, o kailangan ng ambulance ngayon?';
    }
    if (_containsAny(text, ['baha', 'flood', 'lubog', 'ulan'])) {
      return 'Copy, baha ang narinig ko. Pumunta sa mas mataas na lugar kung kaya. Saan banda at may stranded ba o kailangan ng rescue?';
    }
    if (_containsAny(text, ['tulong', 'help', 'saklolo', 'emergency'])) {
      return 'Nandito ako. Sabihin mo muna ang pinaka-importanteng nangyayari: sunog, aksidente, baha, gulo, o may nasaktan?';
    }
    return 'Narinig kita. Para maipasa ko nang tama, ano ang emergency at may tao bang nasaktan o nanganganib ngayon?';
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any(text.contains);
  }

  bool _shouldSubmitImmediately(String transcript) {
    final text = transcript.toLowerCase();
    if (!_hasEnoughEmergencyDetailForSubmit(text)) return false;
    final normalized = _normalizeSpeechText(text);
    final tokens = normalized
        .split(' ')
        .where((token) => token.trim().length > 1)
        .toList();
    if (tokens.length >= 8 && !_looksLikeOnlyGreetingOrHelp(normalized)) {
      return true;
    }
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
      'nagbanggaan',
      'nagkabanggaan',
      'nagbungguan',
      'bungguan',
      'salpukan',
      'kotse',
      'sasakyan',
      'medical',
      'ambulance',
      'nasaktan',
      'sugat',
      'baril',
      'armas',
      'saksak',
      'kidnap',
      'nawawala',
      'missing',
      'robbery',
      'holdap',
      'nakawan',
      'snatching',
      'suntukan',
      'away',
      'gulo',
      'riot',
      'violence',
      'domestic',
      'threat',
      'self harm',
      'suicide',
      'aggressive',
      'rescue',
      'trapped',
      'stranded',
      'drowning',
      'nalulunod',
      'gas leak',
      'chemical',
      'toxic',
      'hazmat',
      'kuryente',
      'brownout',
      'live wire',
      'water leak',
      'poste',
      'pothole',
      'harang',
      'obstruction',
      'aso',
      'dog bite',
      'animal',
      'rabies',
      'basura',
      'garbage',
      'kanal',
      'landslide',
      'bagyo',
      'typhoon',
      'storm surge',
      'tsunami',
      'ashfall',
      'collapse',
    ]);
  }

  bool _looksLikeOnlyGreetingOrHelp(String text) {
    final tokens = text
        .split(' ')
        .where((token) => token.trim().isNotEmpty)
        .toList();
    if (tokens.length > 4) return false;
    const vagueWords = {
      'hello',
      'hi',
      'hey',
      'aigor',
      'help',
      'tulong',
      'saklolo',
      'emergency',
      'urgent',
      'po',
      'please',
      'pls',
    };
    return tokens.isNotEmpty && tokens.every(vagueWords.contains);
  }

  bool _hasEnoughEmergencyDetailForSubmit(String transcript) {
    final normalized = _normalizeSpeechText(transcript);
    final tokens = normalized
        .split(' ')
        .where((token) => token.trim().length > 1)
        .toList();
    if (tokens.length >= 5) return true;
    return _containsAny(normalized, [
      'dito sa',
      'sa bahay',
      'sa kalsada',
      'sa building',
      'sa loob',
      'may tao',
      'may bata',
      'may injured',
      'may nasaktan',
      'may sugat',
      'may dugo',
      'may naipit',
      'may namatay',
      'may patay',
      'hindi makahinga',
      'kailangan ambulance',
      'kailangan rescue',
      'kailangan ng rescue',
      'need ambulance',
      'need rescue',
      'malapit sa',
      'nagbanggaan',
      'nagkabanggaan',
      'nagbungguan',
      'bungguan',
      'salpukan',
      'kotse',
      'sasakyan',
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
          .timeout(const Duration(seconds: 16));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('AI report save failed: ${response.statusCode}');
      }

      final decoded = jsonDecode(response.body);
      final session = decoded is Map ? decoded['session'] : null;
      final sessionPayload = session is Map
          ? Map<String, dynamic>.from(session)
          : <String, dynamic>{};
      if (!_isAiSessionReadyForHandoff(sessionPayload)) {
        _hasSubmittedAiReport = false;
        _isSubmittingAiReport = false;
        final followUp = _buildAiFollowUpFromSession(
          sessionPayload,
          fallbackTranscript: cleaned,
        );
        if (mounted) {
          setState(() => _aiStatusMessage = 'AIGOR needs one more detail...');
        }
        await _speakText(followUp, allowInterrupt: true);
        if (!_controller.isEnding &&
            !_hasSubmittedAiReport &&
            !_isSubmittingAiReport) {
          _callerReportDraft = '';
          _hasStartedAiListening = false;
          unawaited(_startAiReportListening());
          _armFollowUpFallback();
        }
        return;
      }
      final responseText = _buildAiAcknowledgement(session);
      await _speakAndHandoff(responseText);
    } catch (error) {
      debugPrint('[SOS AI Voice] Report submit failed: $error');
      await _speakAndHandoff(
        'Nagkaproblema sa pag-save ng report, pero ipapasa pa rin namin kayo sa aming human operator para mas mabilis kayong matulungan. Huwag patayin ang call.',
      );
    } finally {
      _isSubmittingAiReport = false;
    }
  }

  bool _isAiSessionReadyForHandoff(Map<String, dynamic> session) {
    final analysis = session['analysis'] is Map
        ? Map<String, dynamic>.from(session['analysis'] as Map)
        : <String, dynamic>{};
    final status = session['status']?.toString();
    final hasReport =
        session['report_id'] != null || session['reportId'] != null;
    final hasIncident =
        session['incident_id'] != null || session['incidentId'] != null;
    final aiReady =
        analysis['ai_ready_for_handoff'] == true ||
        analysis['aiReadyForHandoff'] == true;
    return hasReport &&
        hasIncident &&
        aiReady &&
        (status == 'report_created' || status == 'handoff');
  }

  String _buildAiFollowUpFromSession(
    Map<String, dynamic> session, {
    required String fallbackTranscript,
  }) {
    final analysis = session['analysis'] is Map
        ? Map<String, dynamic>.from(session['analysis'] as Map)
        : <String, dynamic>{};
    final callerReply =
        analysis['caller_reply']?.toString().trim() ??
        analysis['callerReply']?.toString().trim();
    if (callerReply != null && callerReply.isNotEmpty) {
      return callerReply;
    }
    return _buildAigorFollowUp(fallbackTranscript);
  }

  String _buildAiAcknowledgement(dynamic session) {
    final payload = session is Map
        ? Map<String, dynamic>.from(session)
        : <String, dynamic>{};
    final analysis = payload['analysis'] is Map
        ? Map<String, dynamic>.from(payload['analysis'] as Map)
        : <String, dynamic>{};
    final callerReply =
        analysis['caller_reply']?.toString().trim() ??
        analysis['callerReply']?.toString().trim();
    if (callerReply != null && callerReply.isNotEmpty) {
      return callerReply;
    }
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
    return 'Okay, na-save ko na: $details.$severityText $safetyLine Ipapasa na namin kayo sa aming human operator para mas mabilis kayong matulungan. Huwag patayin ang call habang kinokonekta namin kayo.';
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
      final interrupted = await _speakText(message, allowInterrupt: true);
      if (interrupted) {
        return;
      }
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

  Future<void> _manualTransferToOperator() async {
    if (_controller.isEnding || _operatorAccepted || _handoffRequested) return;
    _handoffRequested = true;
    _followUpFallbackTimer?.cancel();
    _silenceNudgeTimer?.cancel();
    _bargeInTimer?.cancel();
    if (mounted) {
      setState(
        () => _aiStatusMessage =
            'Manual transfer requested. Waiting for the command center to accept...',
      );
    }
    try {
      await _speech.stop();
    } catch (_) {}
    try {
      await _stopAiSpeech();
    } catch (_) {}

    try {
      final token = await apiService.getToken();
      final sessionId = _aiCallerSessionId ?? _deriveAiSessionId(widget.callId);
      final uri = Uri.parse(
        '${ApiService.baseUrl}/ai-caller/sessions/${Uri.encodeComponent(sessionId)}/manual-handoff',
      );
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              if (token != null) 'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'reason': 'caller_requested_operator'}),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw StateError('Manual handoff failed: ${response.statusCode}');
      }
    } catch (error) {
      debugPrint('[SOS AI Voice] Manual handoff request failed: $error');
      _handoffRequested = false;
      if (mounted) {
        setState(
          () => _aiStatusMessage =
              'Could not request manual transfer yet. Please try again.',
        );
      }
    }
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
      final response = await http
          .post(
            uri,
            headers: {if (token != null) 'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        _handoffRequested = false;
        if (mounted) {
          setState(() => _aiStatusMessage = 'AIGOR needs more details first.');
        }
        return;
      }
    } catch (error) {
      debugPrint('[SOS AI Voice] Handoff request failed: $error');
      _handoffRequested = false;
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
      if (!_controller.hasRemoteParticipant && !_controller.isConnecting) {
        unawaited(_connectOperatorVideo());
      }
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
    await _connectOperatorVideo();
  }

  Future<void> _connectOperatorVideo() async {
    if (_controller.isEnding) return;
    try {
      await _speech.stop();
    } catch (_) {}
    try {
      await _stopAiSpeech();
    } catch (_) {}
    try {
      SignalingService.instance.joinCallRoom(_roomName, role: 'reporter');
      await _controller.ensureCameraEnabled();
      await _controller.setNativeMicrophoneMuted(false);
      await _controller.resumePublishingAfterAiTriage();
      await _controller.recoverVideoSurfaces();
      Future.delayed(const Duration(milliseconds: 900), () {
        if (!mounted || _controller.isEnding || !_operatorAccepted) return;
        unawaited(_controller.recoverVideoSurfaces());
      });
    } catch (error) {
      debugPrint(
        '[SOS AI Voice] Could not resume AITELLIGENZ room publishing: $error',
      );
    }
  }

  Future<void> _closeFromRemoteEnd() async {
    _submitPendingAiReportBeforeClosing();
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
    if (!_isPayloadForThisCall(data)) return;
    unawaited(_closeFromRemoteEnd());
  }

  Future<void> _endCall() async {
    if (_hasRequestedCallEnd) return;
    _hasRequestedCallEnd = true;
    _submitPendingAiReportBeforeClosing();
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

  void _submitPendingAiReportBeforeClosing() {
    if (_hasSubmittedAiReport || _isSubmittingAiReport) return;
    final transcript = _visibleCallerTranscript.trim();
    if (!_isLikelyCallerSpeech(transcript, forInterrupt: false)) return;
    unawaited(_submitAiReport(transcript));
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

  void _showCallSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF00A2FF),
        ),
      );
  }

  // ignore: unused_element
  Future<void> _setCallHold(bool hold) async {
    if (_isCallOnHold == hold) return;
    if (mounted) setState(() => _isCallOnHold = hold);
    await _controller.setNativeMicrophoneMuted(
      hold || !_controller.isMicEnabled,
    );
    if (!hold) {
      _showCallSnack('Call resumed.');
    }
  }

  Future<void> _toggleMute() async {
    if (_isCallOnHold && mounted) {
      setState(() => _isCallOnHold = false);
    }
    await _controller.toggleMicrophone();
    await _controller.setNativeMicrophoneMuted(!_controller.isMicEnabled);
    if (mounted) setState(() {});
  }

  Future<void> _toggleSpeaker() async {
    final nextSpeakerState = !_isSpeakerOn;
    if (mounted) setState(() => _isSpeakerOn = nextSpeakerState);
    await _controller.setSpeakerEnabled(nextSpeakerState);
    _showCallSnack(
      nextSpeakerState ? 'Speaker audio is on.' : 'Speaker audio is off.',
    );
  }

  // ignore: unused_element
  Future<void> _toggleCamera() async {
    await _controller.toggleCamera();
    if (mounted) setState(() {});
  }

  // ignore: unused_element
  Future<void> _shareLocationNow() async {
    await _controller.shareCurrentLocationNow();
    _showCallSnack('Live location shared with the command center.');
  }

  String get _visibleCallerTranscript {
    return _pushToTalkDraft.trim().isNotEmpty
        ? _pushToTalkDraft.trim()
        : _callerReportDraft.trim().isNotEmpty
        ? _callerReportDraft.trim()
        : _latestCallerTranscript.trim().isNotEmpty
        ? _latestCallerTranscript.trim()
        : _pendingAiReportTranscript.trim();
  }

  void _showCallInfoSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF041225),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Call Info',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 16),
                _CallInfoRow(label: 'Call ID', value: widget.callId),
                _CallInfoRow(label: 'Room', value: _roomName),
                _CallInfoRow(
                  label: 'Connected to',
                  value: _currentPeerDisplayName,
                ),
                _CallInfoRow(
                  label: 'Duration',
                  value: _formatDuration(_elapsed),
                ),
                _CallInfoRow(
                  label: 'Status',
                  value: _operatorAccepted
                      ? 'Connected to command center'
                      : _aiStatusMessage,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ignore: unused_element
  Future<void> _showTextMessageSheet() async {
    final messageController = TextEditingController();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF041225),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              18,
              20,
              20 + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Message AIGOR',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 5,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Type what happened...',
                    hintStyle: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.06),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: Color(0xFF00A2FF)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final text = messageController.text.trim();
                      if (text.isEmpty) return;
                      Navigator.of(sheetContext).pop();
                      unawaited(_handleCallerTranscript(text));
                      _showCallSnack('Message sent to AIGOR.');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00A2FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Icon(Icons.send),
                    label: const Text('Send to AIGOR'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
    messageController.dispose();
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final m = twoDigits(d.inMinutes.remainder(60));
    final s = twoDigits(d.inSeconds.remainder(60));
    return d.inHours > 0 ? '${twoDigits(d.inHours)}:$m:$s' : '$m:$s';
  }

  Widget _buildControlItem({
    required IconData icon,
    required String label,
    required bool active,
    VoidCallback? onTap,
    VoidCallback? onPressStart,
    VoidCallback? onPressEnd,
    bool isEndCall = false,
  }) {
    final bgColor = isEndCall
        ? const Color(0xFFFF3B30) // Red
        : active
            ? const Color(0xFF00A2FF).withValues(alpha: 0.18)
            : const Color(0xFF161F30);
    final borderColor = isEndCall
        ? Colors.transparent
        : active
            ? const Color(0xFF00A2FF)
            : Colors.white.withValues(alpha: 0.06);
    final iconColor = isEndCall
        ? Colors.white
        : active
            ? const Color(0xFF00A2FF)
            : Colors.white;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          onTapDown: onPressStart == null ? null : (_) => onPressStart(),
          onTapUp: onPressEnd == null ? null : (_) => onPressEnd(),
          onTapCancel: onPressEnd,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: isEndCall ? 68 : 56,
            height: isEndCall ? 68 : 56,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: Border.all(
                color: borderColor,
                width: active ? 2.0 : 1.0,
              ),
              boxShadow: isEndCall
                  ? [
                      BoxShadow(
                        color: const Color(0xFFFF3B30).withValues(alpha: 0.35),
                        blurRadius: 14,
                        spreadRadius: 1,
                      ),
                    ]
                  : active
                      ? [
                          BoxShadow(
                            color: const Color(0xFF00A2FF).withValues(alpha: 0.2),
                            blurRadius: 10,
                            spreadRadius: 0,
                          ),
                        ]
                      : null,
            ),
            child: Icon(icon, color: iconColor, size: isEndCall ? 30 : 24),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ignore: unused_element
  Widget _buildVerticalDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.white.withValues(alpha: 0.06),
    );
  }

  Widget _buildAigorRedesignScreen(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final isTablet = screenWidth > 600;
    final contentWidth = isTablet ? 520.0 : double.infinity;

    return Scaffold(
      backgroundColor: const Color(0xFF020813),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF020813), Color(0xFF030D1B), Color(0xFF020813)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: contentWidth,
              ),
              child: Column(
                children: [
                  // 1. Top Header Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Back Button
                        GestureDetector(
                          onTap: _endCall,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.1),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                        // Center Titles
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text(
                                  'SOS CALL',
                                  style: TextStyle(
                                    color: Color(0xFF00B2FF),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF2D55),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text(
                                    'LIVE',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'AIGOR',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'AI Emergency Assistant',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.5),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        // Call Info Button
                        GestureDetector(
                          onTap: _showCallInfoSheet,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.15),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Call Info',
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.9),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.info,
                                  color: Color(0xFF00A2FF),
                                  size: 12,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2. Scrollable Body
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),

                          // Aigor Head & Waveform Graphics
                          SizedBox(
                            height: 220,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Waveform Background
                                Positioned.fill(
                                  child: AnimatedBuilder(
                                    animation: _pulseController,
                                    builder: (context, child) {
                                      return CustomPaint(
                                        painter: WaveformPainter(
                                          animationValue: _pulseController.value,
                                          isSpeaking: _isAiSpeaking,
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                // Concentric circles with Aigor Head
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    final pulse = _pulseController.value;
                                    return Container(
                                      width: 190 + (pulse * 6),
                                      height: 190 + (pulse * 6),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: const Color(0xFF00B2FF).withValues(alpha: 0.15 + (pulse * 0.15)),
                                          width: 1.5,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF00B2FF).withValues(alpha: 0.05 + (pulse * 0.05)),
                                            blurRadius: 25 + (pulse * 10),
                                            spreadRadius: 2 + (pulse * 2),
                                          ),
                                        ],
                                      ),
                                      alignment: Alignment.center,
                                      child: Container(
                                        width: 174,
                                        height: 174,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFF00B2FF).withValues(alpha: 0.3 + (pulse * 0.15)),
                                            width: 2.0,
                                          ),
                                        ),
                                        alignment: Alignment.center,
                                        child: Container(
                                          width: 156,
                                          height: 156,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFF00B2FF).withValues(alpha: 0.2),
                                                blurRadius: 15,
                                                spreadRadius: 2,
                                              ),
                                            ],
                                          ),
                                          child: ClipOval(
                                            child: Image.asset(
                                              'assets/images/aigor_avatar.png',
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Status Pill
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF051C33).withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF00A2FF).withValues(alpha: 0.35),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _isAiSpeaking
                                      ? Icons.volume_up
                                      : Icons.graphic_eq,
                                  color: const Color(0xFF00A2FF),
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  _isAiSpeaking
                                      ? 'AIGOR IS SPEAKING...'
                                      : _isPushToTalkRecording
                                      ? 'AIGOR IS LISTENING...'
                                      : 'AIGOR IS READY...',
                                  style: const TextStyle(
                                    color: Color(0xFF00A2FF),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Blinking dot
                                AnimatedBuilder(
                                  animation: _pulseController,
                                  builder: (context, child) {
                                    return Opacity(
                                      opacity: _pulseController.value,
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF00A2FF),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Message Bubble
                          Container(
                            padding: const EdgeInsets.all(16),
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF061121).withValues(alpha: 0.75),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFF0055FF).withValues(alpha: 0.12),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF00A2FF).withValues(alpha: 0.4),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/images/aigor_avatar.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _latestAigorSpeech,
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.9),
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w500,
                                          height: 1.45,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      const Text(
                                        'How can I assist you today?',
                                        style: TextStyle(
                                          color: Color(0xFF00A2FF),
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Caller Transcription Bubble
                          if (_visibleCallerTranscript.isNotEmpty) ...[
                            Container(
                              padding: const EdgeInsets.all(14),
                              margin: const EdgeInsets.symmetric(horizontal: 20),
                              decoration: BoxDecoration(
                                color: const Color(0xFF061A2F).withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: const Color(0xFF00A2FF).withValues(alpha: 0.18),
                                  width: 1.2,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.record_voice_over,
                                    color: Color(0xFF00A2FF),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          _isPushToTalkRecording
                                              ? 'LIVE TRANSCRIPTION'
                                              : 'YOUR LAST MESSAGE',
                                          style: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.48),
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.0,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _visibleCallerTranscript,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Recording Progress Card
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF13090A).withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: const Color(0xFF3D1216),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFF2D55),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AnimatedBuilder(
                                        animation: _pulseController,
                                        builder: (context, child) {
                                          return Opacity(
                                            opacity: _pulseController.value,
                                            child: Container(
                                              width: 6,
                                              height: 6,
                                              decoration: const BoxDecoration(
                                                color: Colors.white,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      const SizedBox(width: 4),
                                      const Text(
                                        'REC',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Text(
                                        'RECORDING IN PROGRESS',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Your call is being recorded for your safety.',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.5),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: List.generate(8, (index) {
                                        final height =
                                            4.0 +
                                            8.0 *
                                                (sin(
                                                  index +
                                                      _pulseController.value *
                                                          2 *
                                                          pi,
                                                ).abs());
                                        return Container(
                                          margin: const EdgeInsets.symmetric(
                                            horizontal: 1.5,
                                          ),
                                          width: 2,
                                          height: height,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFFF2D55),
                                            borderRadius: BorderRadius.circular(1),
                                          ),
                                        );
                                      }),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatDuration(_elapsed),
                                      style: const TextStyle(
                                        color: Color(0xFFFF2D55),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w900,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // Push-To-Talk Button
                          if (_canUseAigorPushToTalk || _isPushToTalkRecording)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: _AigorPushToTalkButton(
                                enabled: _canUseAigorPushToTalk || _isPushToTalkRecording,
                                isRecording: _isPushToTalkRecording,
                                onStart: _startPushToTalkRecording,
                                onStop: _finishPushToTalkRecording,
                              ),
                            ),

                          if (!_operatorAccepted) ...[
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              child: _ManualTransferButton(
                                enabled: !_handoffRequested && !_controller.isEnding,
                                waiting: _handoffRequested,
                                onTap: () => unawaited(_manualTransferToOperator()),
                              ),
                            ),
                          ],

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),

                  // 3. Bottom Controls Panel
                  _buildBottomControls(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20, top: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1624).withValues(alpha: 0.95), // Dark premium card
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.04),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildControlItem(
            icon: _controller.isMicEnabled ? Icons.mic : Icons.mic_off,
            label: 'Mute',
            active: !_controller.isMicEnabled,
            onTap: () => unawaited(_toggleMute()),
          ),
          _buildControlItem(
            icon: Icons.call_end,
            label: 'End Call',
            active: false,
            isEndCall: true,
            onTap: _endCall,
          ),
          _buildControlItem(
            icon: _isSpeakerOn ? Icons.volume_up : Icons.volume_down,
            label: 'Speaker',
            active: _isSpeakerOn,
            onTap: () => unawaited(_toggleSpeaker()),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isAiTriageCall && !_operatorAccepted) {
      return _buildAigorRedesignScreen(context);
    }

    final showOperatorCall = _operatorAccepted;
    final isConnected =
        _operatorAccepted &&
        (!_controller.isConnecting ||
            _controller.hasRemoteParticipant ||
            _controller.hasLocalPreview);
    final localPreview = showOperatorCall ? _controller.localView : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: !showOperatorCall
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
                      view: _controller.remoteView,
                      label: _controller.remoteView == null
                          ? (_operatorAccepted
                                ? _currentPeerDisplayName
                                : _aiStatusMessage)
                          : _currentPeerDisplayName,
                      compact: false,
                      showLabel: false,
                    ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: CallHeader(
                callId: widget.callId,
                isConnected: isConnected || showOperatorCall,
                displayName: _currentPeerDisplayName,
                showCallId: false,
              ),
            ),
            if (localPreview != null)
              Positioned(
                right: 16,
                top: 96,
                width: isConnected ? 128 : 140,
                height: isConnected ? 172 : 188,
                child: _ZegoVideoSurface(
                  view: localPreview,
                  label: isConnected ? 'You' : 'Camera ready',
                  compact: true,
                ),
              ),
            if (_isAiTriageCall &&
                !_operatorAccepted &&
                !_handoffRequested &&
                !_hasSubmittedAiReport)
              Positioned(
                left: 20,
                right: 20,
                bottom: 114,
                child: Center(
                  child: _AigorPushToTalkButton(
                    enabled: _canUseAigorPushToTalk || _isPushToTalkRecording,
                    isRecording: _isPushToTalkRecording,
                    onStart: _startPushToTalkRecording,
                    onStop: _finishPushToTalkRecording,
                  ),
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

class _CallInfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _CallInfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 105,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.48),
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
class _AigorActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  // ignore: unused_element_parameter
  const _AigorActionItem({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF081C33),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF00A2FF).withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Icon(icon, color: const Color(0xFF00A2FF), size: 20),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final double animationValue;
  final bool isSpeaking;
  WaveformPainter({required this.animationValue, required this.isSpeaking});

  @override
  void paint(Canvas canvas, Size size) {
    final double midY = size.height / 2;
    final int barCount = 32;
    final double spacing = size.width / (barCount - 1);

    for (int i = 0; i < barCount; i++) {
      final double x = i * spacing;
      final double distFromCenter = (x - size.width / 2).abs();
      // Leave space for the Aigor circle in the center
      if (distFromCenter < 100) continue;

      double baseHeight = 6.0;
      if (isSpeaking) {
        baseHeight += 28.0 * sin(i * 0.5 + animationValue * 2 * pi).abs();
      } else {
        baseHeight += 10.0 * sin(i * 0.2 + animationValue * pi).abs();
      }

      final double startY = midY - baseHeight / 2;
      final int dots = (baseHeight / 4).round().clamp(1, 8);
      final double step = baseHeight / (dots > 1 ? (dots - 1) : 1);
      
      final dotPaint = Paint()
        ..color = const Color(0xFF00D4FF).withValues(alpha: isSpeaking ? 0.75 : 0.4)
        ..style = PaintingStyle.fill;
        
      for (int d = 0; d < dots; d++) {
        final double y = startY + d * (dots > 1 ? step : 0);
        canvas.drawCircle(Offset(x, y), 1.5, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isSpeaking != isSpeaking;
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

String _deriveAiSessionId(String callId) {
  final cleaned = callId
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return 'ai_${cleaned.isEmpty ? 'unknown' : cleaned}';
}

class _AigorPushToTalkButton extends StatelessWidget {
  final bool enabled;
  final bool isRecording;
  final Future<void> Function() onStart;
  final Future<void> Function() onStop;

  const _AigorPushToTalkButton({
    required this.enabled,
    required this.isRecording,
    required this.onStart,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final active = isRecording;
    final mainColor = active
        ? const Color(0xFFFF3B4F)
        : const Color(0xFF00D4FF);
    final fillColor = active
        ? const Color(0xFF34111B)
        : const Color(0xFF06243A);

    return Opacity(
      opacity: enabled || active ? 1 : 0.58,
      child: Listener(
        onPointerDown: (_) {
          if (enabled) unawaited(onStart());
        },
        onPointerUp: (_) {
          if (enabled || active) unawaited(onStop());
        },
        onPointerCancel: (_) {
          if (enabled || active) unawaited(onStop());
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 236,
          height: 58,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: fillColor.withValues(alpha: active ? 0.96 : 0.9),
            borderRadius: BorderRadius.circular(29),
            border: Border.all(color: mainColor.withValues(alpha: 0.85)),
            boxShadow: [
              BoxShadow(
                color: mainColor.withValues(alpha: active ? 0.34 : 0.18),
                blurRadius: active ? 24 : 16,
                spreadRadius: active ? 2 : 0,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(active ? Icons.mic : Icons.mic_none, color: mainColor),
              const SizedBox(width: 10),
              Flexible(
                child: Text(
                  active ? 'Recording...' : 'Hold to talk to AIGOR',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: active ? Colors.white : const Color(0xFFE7F8FF),
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualTransferButton extends StatelessWidget {
  final bool enabled;
  final bool waiting;
  final VoidCallback onTap;

  const _ManualTransferButton({
    required this.enabled,
    required this.waiting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = waiting ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8);
    return Opacity(
      opacity: enabled || waiting ? 1 : 0.55,
      child: SizedBox(
        width: 236,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(29),
            child: Ink(
              height: 58,
              decoration: BoxDecoration(
                color: const Color(0xFF061A2F).withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(29),
                border: Border.all(color: color.withValues(alpha: 0.7)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: waiting ? 0.16 : 0.22),
                    blurRadius: waiting ? 12 : 18,
                    spreadRadius: waiting ? 0 : 1,
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    waiting ? Icons.hourglass_top : Icons.support_agent,
                    color: color,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      waiting
                          ? 'Waiting for human operator...'
                          : 'Transfer to human operator',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        letterSpacing: 0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ZegoVideoSurface extends StatelessWidget {
  final Widget? view;
  final String label;
  final bool compact;
  final bool showLabel;

  const _ZegoVideoSurface({
    required this.view,
    required this.label,
    required this.compact,
    this.showLabel = true,
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
          if (showLabel)
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
