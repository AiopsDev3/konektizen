import 'package:flutter/material.dart';

class CameraOffPlaceholder extends StatelessWidget {
  final String name;
  final bool compact;
  final bool isSpeaking;

  const CameraOffPlaceholder({
    super.key,
    required this.name,
    required this.compact,
    required this.isSpeaking,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? 'C3'
        : name
            .trim()
            .split(RegExp(r'\s+'))
            .map((s) => s.isNotEmpty ? s[0] : '')
            .take(2)
            .join()
            .toUpperCase();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0B132B),
            Color(0xFF1C2541),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: compact ? 48 : 80,
              height: compact ? 48 : 80,
              decoration: BoxDecoration(
                color: isSpeaking
                    ? const Color(0xFF2DD4BF).withOpacity(0.15)
                    : Colors.white.withOpacity(0.06),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSpeaking
                      ? const Color(0xFF2DD4BF).withOpacity(0.8)
                      : Colors.white.withOpacity(0.12),
                  width: isSpeaking ? 2.5 : 1.5,
                ),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    color: isSpeaking ? const Color(0xFF2DD4BF) : Colors.white70,
                    fontSize: compact ? 16 : 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 12),
              Text(
                name,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Camera Off',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
