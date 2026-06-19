import 'package:flutter/material.dart';

class GarbageIllustration extends StatelessWidget {
  const GarbageIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 60,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          // Black trash bags
          Positioned(
            right: 0,
            bottom: 4,
            child: Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF1E293B),
              ),
            ),
          ),
          Positioned(
            right: 16,
            bottom: 4,
            child: Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFF475569),
              ),
            ),
          ),
          // Green trash bin
          Positioned(
            right: 24,
            bottom: 4,
            child: Container(
              width: 32,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981),
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  )
                ],
              ),
              child: const Center(
                child: Icon(Icons.recycling_rounded, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class RoadIllustration extends StatelessWidget {
  const RoadIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 60,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Positioned(
            right: 4,
            bottom: 4,
            child: Container(
              width: 44,
              height: 8,
              decoration: BoxDecoration(
                color: const Color(0xFFF97316),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 14,
                  height: 10,
                  color: const Color(0xFFF97316),
                ),
                Container(
                  width: 20,
                  height: 10,
                  color: Colors.white,
                ),
                Container(
                  width: 28,
                  height: 10,
                  color: const Color(0xFFF97316),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FloodIllustration extends StatelessWidget {
  const FloodIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 60,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Positioned(
            right: 14,
            bottom: 16,
            child: Icon(Icons.home_rounded, color: const Color(0xFF0284C7).withValues(alpha: 0.6), size: 36),
          ),
          Positioned(
            right: 0,
            bottom: 4,
            left: 0,
            child: Icon(Icons.waves_rounded, color: const Color(0xFF0EA5E9), size: 32),
          ),
          Positioned(
            right: 8,
            bottom: -2,
            left: 0,
            child: Icon(Icons.waves_rounded, color: const Color(0xFF38BDF8), size: 28),
          ),
        ],
      ),
    );
  }
}

class StreetlightIllustration extends StatelessWidget {
  const StreetlightIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 60,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Positioned(
            right: 6,
            bottom: 4,
            child: Container(
              width: 32,
              height: 42,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFFF59E0B).withValues(alpha: 0.4),
                    const Color(0xFFF59E0B).withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 20,
            bottom: 4,
            child: Container(
              width: 4,
              height: 48,
              color: const Color(0xFF64748B),
            ),
          ),
          Positioned(
            right: 12,
            top: 4,
            child: Container(
              width: 12,
              height: 6,
              decoration: const BoxDecoration(
                color: Color(0xFF475569),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TrafficIllustration extends StatelessWidget {
  const TrafficIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 60,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          Positioned(
            right: 28,
            bottom: 4,
            child: Container(
              width: 4,
              height: 20,
              color: const Color(0xFF475569),
            ),
          ),
          Positioned(
            right: 22,
            bottom: 24,
            child: Container(
              width: 16,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(4),
              ),
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CircleAvatar(radius: 3, backgroundColor: Color(0xFFEF4444)),
                  CircleAvatar(radius: 3, backgroundColor: Color(0xFFF59E0B)),
                  CircleAvatar(radius: 3, backgroundColor: Color(0xFF10B981)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CategoryIllustration extends StatelessWidget {
  final String category;

  const CategoryIllustration({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    switch (category.toUpperCase()) {
      case 'BASURA':
        return const GarbageIllustration();
      case 'KALSADA':
        return const RoadIllustration();
      case 'PAGBAHA':
        return const FloodIllustration();
      case 'ILAW_SA_KALYE':
        return const StreetlightIllustration();
      case 'TRAPIKO':
        return const TrafficIllustration();
      default:
        return const SizedBox.shrink();
    }
  }
}
