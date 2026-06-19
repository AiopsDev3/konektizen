import 'package:flutter/material.dart';

class PulsingSOSButton extends StatefulWidget {
  final VoidCallback onTap;

  const PulsingSOSButton({super.key, required this.onTap});

  @override
  State<PulsingSOSButton> createState() => _PulsingSOSButtonState();
}

class _PulsingSOSButtonState extends State<PulsingSOSButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        width: 260,
        height: 260,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                // Outer wave 3
                _buildRing(1.0 + (_controller.value * 0.4), 0.05 * (1.0 - _controller.value)),
                // Outer wave 2
                _buildRing(1.0 + (_controller.value * 0.25), 0.12 * (1.0 - _controller.value)),
                // Outer wave 1
                _buildRing(1.0 + (_controller.value * 0.1), 0.20 * (1.0 - _controller.value)),
                // Center white circle with shadow
                Container(
                  width: 130,
                  height: 130,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 16,
                        offset: Offset(0, 8),
                      )
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.phone_in_talk_rounded,
                      size: 52,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildRing(double scale, double opacity) {
    if (opacity <= 0) return const SizedBox.shrink();
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: opacity),
        ),
      ),
    );
  }
}
