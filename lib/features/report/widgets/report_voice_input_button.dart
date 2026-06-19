import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:konektizen/theme/app_theme.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ReportVoiceInputButton extends StatefulWidget {
  final ValueChanged<String> onTextChanged;
  final String tapToSpeakLabel;
  final String listeningLabel;

  const ReportVoiceInputButton({
    super.key,
    required this.onTextChanged,
    required this.tapToSpeakLabel,
    required this.listeningLabel,
  });

  @override
  State<ReportVoiceInputButton> createState() => _ReportVoiceInputButtonState();
}

class _ReportVoiceInputButtonState extends State<ReportVoiceInputButton> {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;

  @override
  void dispose() {
    _speech.stop();
    super.dispose();
  }

  Future<void> _toggleListening() async {
    if (!_isListening) {
      try {
        bool available = await _speech.initialize(
          onStatus: (status) {
            if (status == 'done' || status == 'notListening') {
              if (mounted) setState(() => _isListening = false);
            }
          },
          onError: (error) {
            if (mounted) setState(() => _isListening = false);
          },
        );
        if (available && mounted) {
          setState(() => _isListening = true);
          _speech.listen(
            onResult: (result) {
              widget.onTextChanged(result.recognizedWords);
            },
          );
        }
      } catch (_) {
        if (mounted) setState(() => _isListening = false);
      }
    } else {
      if (mounted) setState(() => _isListening = false);
      await _speech.stop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _toggleListening,
        borderRadius: BorderRadius.circular(30),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: _isListening
                ? Colors.redAccent.withValues(alpha: 0.08)
                : AppTheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
              color: _isListening
                  ? Colors.redAccent.withValues(alpha: 0.2)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isListening ? Icons.stop_circle_rounded : Icons.mic_rounded,
                color: _isListening ? Colors.redAccent : AppTheme.primary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                _isListening ? widget.listeningLabel : widget.tapToSpeakLabel,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _isListening ? Colors.redAccent : AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
