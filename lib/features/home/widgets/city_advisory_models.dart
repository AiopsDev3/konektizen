import 'package:flutter/material.dart';

class AdvisoryDisplayItem {
  final String category; // 'Alerts', 'Weather', 'Traffic', 'Advisory', 'News', 'Facebook'
  final String title;
  final String source;
  final String timeText;
  final String description;
  final String? url;
  final String? imageUrl;
  
  AdvisoryDisplayItem({
    required this.category,
    required this.title,
    required this.source,
    required this.timeText,
    required this.description,
    this.url,
    this.imageUrl,
  });
}

class VerifiedSourceItem {
  final String name;
  final String description;
  final IconData icon;
  final Color iconColor;
  final String url;
  
  const VerifiedSourceItem({
    required this.name,
    required this.description,
    required this.icon,
    required this.iconColor,
    required this.url,
  });
}

class SkylinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(size.width, size.height);
    path.lineTo(size.width * 0.5, size.height);
    
    // Add Sinking Bell Tower silhouette
    path.lineTo(size.width * 0.55, size.height - 15);
    path.lineTo(size.width * 0.58, size.height - 15);
    path.lineTo(size.width * 0.58, size.height);
    
    path.lineTo(size.width * 0.64, size.height);
    path.lineTo(size.width * 0.64, size.height - 65); // Tier 1
    path.lineTo(size.width * 0.66, size.height - 65);
    path.lineTo(size.width * 0.66, size.height - 95); // Tier 2
    path.lineTo(size.width * 0.68, size.height - 95);
    path.lineTo(size.width * 0.68, size.height - 115); // Tier 3
    // Dome top
    path.arcToPoint(
      Offset(size.width * 0.72, size.height - 115),
      radius: const Radius.circular(15),
      clockwise: true,
    );
    path.lineTo(size.width * 0.72, size.height - 95);
    path.lineTo(size.width * 0.74, size.height - 95);
    path.lineTo(size.width * 0.74, size.height - 65);
    path.lineTo(size.width * 0.76, size.height - 65);
    path.lineTo(size.width * 0.76, size.height);
    
    // adjacent buildings
    path.lineTo(size.width * 0.80, size.height);
    path.lineTo(size.width * 0.80, size.height - 25);
    path.lineTo(size.width * 0.85, size.height - 25);
    path.lineTo(size.width * 0.85, size.height - 40);
    path.lineTo(size.width * 0.89, size.height - 25);
    path.lineTo(size.width * 0.92, size.height - 25);
    path.lineTo(size.width * 0.92, size.height);
    path.lineTo(size.width * 0.95, size.height);
    path.lineTo(size.width * 0.95, size.height - 35);
    path.lineTo(size.width * 0.98, size.height - 35);
    path.lineTo(size.width * 0.98, size.height);
    
    path.close();
    canvas.drawPath(path, paint);

    // Outline secondary layer
    final outlinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    final path2 = Path();
    path2.moveTo(size.width * 0.42, size.height);
    path2.lineTo(size.width * 0.45, size.height - 25);
    path2.lineTo(size.width * 0.49, size.height - 25);
    path2.lineTo(size.width * 0.51, size.height);
    
    path2.moveTo(size.width * 0.59, size.height);
    path2.lineTo(size.width * 0.61, size.height - 45);
    path2.lineTo(size.width * 0.63, size.height - 45);
    path2.lineTo(size.width * 0.63, size.height);
    
    canvas.drawPath(path2, outlinePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
