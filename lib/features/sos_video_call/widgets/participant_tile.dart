import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:konektizen/features/sos_video_call/widgets/camera_off_placeholder.dart';

class ParticipantTile extends StatefulWidget {
  final Participant participant;
  final bool compact;
  const ParticipantTile({super.key, required this.participant, this.compact = false});
  @override
  State<ParticipantTile> createState() => _ParticipantTileState();
}

class _ParticipantTileState extends State<ParticipantTile> with SingleTickerProviderStateMixin {
  late AnimationController _speakingController;
  late Animation<double> _speakingAnimation;

  @override
  void initState() {
    super.initState();
    _speakingController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    if (widget.participant.isSpeaking) _speakingController.repeat(reverse: true);
    _speakingAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _speakingController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(covariant ParticipantTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.participant.isSpeaking) {
      if (!_speakingController.isAnimating) _speakingController.repeat(reverse: true);
    } else {
      if (_speakingController.isAnimating) {
        _speakingController.stop();
        _speakingController.animateTo(0.0);
      }
    }
  }

  @override
  void dispose() {
    _speakingController.dispose();
    super.dispose();
  }

  VideoTrack? _videoTrack() {
    for (final publication in widget.participant.videoTrackPublications) {
      final track = publication.track;
      if (track is VideoTrack && !publication.muted && !track.muted) return track;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final videoTrack = _videoTrack();
    final isSpeaking = widget.participant.isSpeaking;
    final isMicEnabled = widget.participant.isMicrophoneEnabled();
    final name = widget.participant.name.isNotEmpty ? widget.participant.name : widget.participant.identity;
    final cleanName = name.replaceFirst(RegExp(r'-(?:\d{8,}|[A-Za-z0-9]{6})$'), '');

    return AnimatedBuilder(
      animation: _speakingAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isSpeaking ? _speakingAnimation.value : 1.0,
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF0B132B),
              borderRadius: BorderRadius.circular(widget.compact ? 16 : 24),
              border: Border.all(
                color: isSpeaking ? const Color(0xFF2DD4BF) : Colors.white.withOpacity(0.12),
                width: isSpeaking ? 3 : 1.5,
              ),
              boxShadow: isSpeaking ? [BoxShadow(color: const Color(0xFF2DD4BF).withOpacity(0.4), blurRadius: 16, spreadRadius: 2)] : null,
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (videoTrack != null)
                  VideoTrackRenderer(videoTrack, renderMode: VideoRenderMode.auto, key: ValueKey(videoTrack.sid))
                else
                  CameraOffPlaceholder(name: cleanName, compact: widget.compact, isSpeaking: isSpeaking),
                Positioned(
                  left: widget.compact ? 8 : 16,
                  bottom: widget.compact ? 8 : 16,
                  right: widget.compact ? 8 : 16,
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: widget.compact ? 8 : 12, vertical: widget.compact ? 4 : 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withOpacity(0.85),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isMicEnabled ? Icons.mic : Icons.mic_off,
                              color: isMicEnabled ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                              size: widget.compact ? 12 : 14,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                widget.compact ? 'You' : cleanName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: widget.compact ? 10 : 12,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
