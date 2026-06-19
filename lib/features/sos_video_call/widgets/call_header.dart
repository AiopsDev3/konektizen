import 'dart:async';
import 'package:flutter/material.dart';

class CallHeader extends StatefulWidget {
  final String callId;
  final bool isConnected;
  const CallHeader({super.key, required this.callId, required this.isConnected});
  @override
  State<CallHeader> createState() => _CallHeaderState();
}

class _CallHeaderState extends State<CallHeader> with SingleTickerProviderStateMixin {
  Timer? _durationTimer;
  Duration _elapsed = Duration.zero;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    if (widget.isConnected) _startTimer();
  }

  @override
  void didUpdateWidget(covariant CallHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isConnected && !oldWidget.isConnected) {
      _startTimer();
    } else if (!widget.isConnected && oldWidget.isConnected) {
      _stopTimer();
    }
  }

  @override
  void dispose() {
    _stopTimer();
    _pulseController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _durationTimer?.cancel();
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _elapsed = _elapsed + const Duration(seconds: 1));
    });
  }

  void _stopTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
  }

  String _formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final m = twoDigits(d.inMinutes.remainder(60));
    final s = twoDigits(d.inSeconds.remainder(60));
    return d.inHours > 0 ? '${twoDigits(d.inHours)}:$m:$s' : '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xD9000000), Color(0x99000000), Color(0x00000000)],
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D9488).withOpacity(0.2),
                        border: Border.all(color: const Color(0xFF0D9488).withOpacity(0.6), width: 1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) => Opacity(
                              opacity: _pulseAnimation.value,
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF2DD4BF),
                                  shape: BoxShape.circle,
                                  boxShadow: [BoxShadow(color: Color(0xFF2DD4BF), blurRadius: 4, spreadRadius: 1)],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text('SECURE LINK', style: TextStyle(color: Color(0xFF2DD4BF), fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                        ],
                      ),
                    ),
                    if (widget.isConnected) ...[
                      const SizedBox(width: 8),
                      Text(
                        _formatDuration(_elapsed),
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700, fontFamily: 'monospace', letterSpacing: 0.5),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Command Center',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5, shadows: [Shadow(color: Colors.black45, offset: Offset(0, 2), blurRadius: 6)]),
                ),
                const SizedBox(height: 3),
                Text(widget.callId, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.54), fontSize: 12, fontFamily: 'monospace', letterSpacing: 0.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
