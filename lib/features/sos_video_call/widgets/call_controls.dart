import 'dart:ui';
import 'package:flutter/material.dart';

class CallControls extends StatelessWidget {
  final bool micEnabled;
  final bool cameraEnabled;
  final VoidCallback onToggleMic;
  final VoidCallback onToggleCamera;
  final VoidCallback onEnd;

  const CallControls({
    super.key,
    required this.micEnabled,
    required this.cameraEnabled,
    required this.onToggleMic,
    required this.onToggleCamera,
    required this.onEnd,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B).withOpacity(0.4),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withOpacity(0.12), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TactileControlButton(
                icon: micEnabled ? Icons.mic : Icons.mic_off,
                onPressed: onToggleMic,
                isEnabled: micEnabled,
                tooltip: micEnabled ? 'Mute Mic' : 'Unmute Mic',
              ),
              const SizedBox(width: 20),
              _TactileControlButton(
                icon: cameraEnabled ? Icons.videocam : Icons.videocam_off,
                onPressed: onToggleCamera,
                isEnabled: cameraEnabled,
                tooltip: cameraEnabled ? 'Stop Video' : 'Start Video',
              ),
              const SizedBox(width: 20),
              _TactileControlButton(
                icon: Icons.call_end,
                onPressed: onEnd,
                isEnabled: true,
                isDangerous: true,
                tooltip: 'End Call',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TactileControlButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final bool isEnabled;
  final bool isDangerous;
  final String tooltip;
  const _TactileControlButton({required this.icon, required this.onPressed, required this.isEnabled, this.isDangerous = false, required this.tooltip});
  @override
  State<_TactileControlButton> createState() => _TactileControlButtonState();
}

class _TactileControlButtonState extends State<_TactileControlButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 100));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.isDangerous
        ? const Color(0xFFEF4444)
        : widget.isEnabled
            ? const Color(0xFF0F172A).withOpacity(0.7)
            : const Color(0xFFEF4444).withOpacity(0.2);
    final iconColor = widget.isDangerous ? Colors.white : widget.isEnabled ? Colors.white : const Color(0xFFF87171);
    final border = widget.isDangerous ? null : Border.all(color: widget.isEnabled ? Colors.white.withOpacity(0.12) : const Color(0xFFEF4444).withOpacity(0.4), width: 1);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          onTapDown: (_) => _controller.forward(),
          onTapUp: (_) {
            _controller.reverse();
            widget.onPressed();
          },
          onTapCancel: () => _controller.reverse(),
          child: Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: bgColor,
              shape: BoxShape.circle,
              border: border,
              boxShadow: widget.isDangerous ? [BoxShadow(color: const Color(0xFFEF4444).withOpacity(0.4), blurRadius: 12, spreadRadius: 2)] : null,
            ),
            child: Icon(widget.icon, color: iconColor, size: 24),
          ),
        ),
      ),
    );
  }
}
