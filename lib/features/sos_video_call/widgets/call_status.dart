import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:konektizen/features/sos_video_call/widgets/radar_scanner_painter.dart';

class CallStatus extends StatefulWidget {
  final String message;
  final bool loading;

  const CallStatus({
    super.key,
    required this.message,
    required this.loading,
  });

  @override
  State<CallStatus> createState() => _CallStatusState();
}

class _CallStatusState extends State<CallStatus>
    with SingleTickerProviderStateMixin {
  late AnimationController _rotationController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    if (widget.loading) {
      _rotationController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant CallStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.loading) {
      if (!_rotationController.isAnimating) {
        _rotationController.repeat();
      }
    } else {
      _rotationController.stop();
    }
  }

  @override
  void dispose() {
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.loading) ...[
              SizedBox(
                width: 140,
                height: 140,
                child: AnimatedBuilder(
                  animation: _rotationController,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: RadarScannerPainter(
                        angle: _rotationController.value * 2 * math.pi,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 32),
            ],
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.white.withOpacity(0.08),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.loading) ...[
                    const Text(
                      'ESTABLISHING SECURE GATEWAY',
                      style: TextStyle(
                        color: Color(0xFF2DD4BF),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    widget.message.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: widget.loading ? Colors.white70 : const Color(0xFFEF4444),
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
