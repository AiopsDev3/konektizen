import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

const _iconPrefix = 'c3-facility-icon';

const Map<String, IconData> _facilityIconData = {
  'Hospital': Icons.local_hospital,
  'Health Center': Icons.medical_services,
  'Fire Station': Icons.local_fire_department,
  'Police Station': Icons.local_police,
  'Evacuation Center': Icons.home_work,
  'Command Center': Icons.account_balance,
  'Warehouse': Icons.warehouse,
  'Water Source': Icons.water_drop,
};

const Map<String, Color> _facilityColors = {
  'Hospital': Color(0xffef4444),
  'Health Center': Color(0xff06b6d4),
  'Fire Station': Color(0xfff97316),
  'Police Station': Color(0xff2563eb),
  'Evacuation Center': Color(0xff22c55e),
  'Command Center': Color(0xff8b5cf6),
  'Warehouse': Color(0xff64748b),
  'Water Source': Color(0xff0ea5e9),
};

String c3FacilityIconImageId(String type) {
  final normalized = type.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  return '$_iconPrefix-$normalized';
}

Future<void> registerC3FacilityMapIcons(
  MapLibreMapController controller,
) async {
  for (final type in _facilityIconData.keys) {
    final bytes = await _buildMarkerPng(
      icon: _facilityIconData[type]!,
      color: _facilityColors[type]!,
    );
    await controller.addImage(c3FacilityIconImageId(type), bytes);
  }
}

Future<Uint8List> _buildMarkerPng({
  required IconData icon,
  required Color color,
}) async {
  const size = 88.0;
  const center = Offset(size / 2, size / 2);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  final shadowPaint = Paint()
    ..color = const Color(0x33000000)
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
  canvas.drawCircle(center.translate(0, 3), 31, shadowPaint);

  final ringPaint = Paint()..color = Colors.white;
  canvas.drawCircle(center, 31, ringPaint);

  final fillPaint = Paint()..color = color;
  canvas.drawCircle(center, 26, fillPaint);

  final iconPaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.fill;
    
  final strokePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3.5
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  if (color == const Color(0xffef4444) || color == const Color(0xff06b6d4)) {
    // Hospital / Health Center - Cross
    final w = 6.0;
    final l = 20.0;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: w, height: l), const Radius.circular(2)), iconPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: l, height: w), const Radius.circular(2)), iconPaint);
  } else if (color == const Color(0xfff97316)) {
    // Fire Station - Flame
    final path = Path();
    path.moveTo(center.dx, center.dy - 12);
    path.quadraticBezierTo(center.dx + 12, center.dy - 2, center.dx + 10, center.dy + 8);
    path.arcToPoint(Offset(center.dx - 10, center.dy + 8), radius: const Radius.circular(10), clockwise: false);
    path.quadraticBezierTo(center.dx - 12, center.dy - 2, center.dx, center.dy - 12);
    canvas.drawPath(path, iconPaint);
  } else if (color == const Color(0xff2563eb)) {
    // Police Station - Shield
    final path = Path();
    path.moveTo(center.dx, center.dy - 14);
    path.lineTo(center.dx + 12, center.dy - 10);
    path.lineTo(center.dx + 12, center.dy + 2);
    path.quadraticBezierTo(center.dx + 12, center.dy + 12, center.dx, center.dy + 16);
    path.quadraticBezierTo(center.dx - 12, center.dy + 12, center.dx - 12, center.dy + 2);
    path.lineTo(center.dx - 12, center.dy - 10);
    path.close();
    canvas.drawPath(path, strokePaint..style = PaintingStyle.stroke..strokeWidth = 3);
    canvas.drawCircle(center.translate(0, 2), 3, iconPaint);
  } else if (color == const Color(0xff22c55e)) {
    // Evacuation Center - House/Shelter
    final path = Path();
    path.moveTo(center.dx, center.dy - 12);
    path.lineTo(center.dx + 14, center.dy);
    path.lineTo(center.dx + 10, center.dy);
    path.lineTo(center.dx + 10, center.dy + 12);
    path.lineTo(center.dx - 10, center.dy + 12);
    path.lineTo(center.dx - 10, center.dy);
    path.lineTo(center.dx - 14, center.dy);
    path.close();
    canvas.drawPath(path, iconPaint);
  } else if (color == const Color(0xff8b5cf6)) {
    // Command Center - Radar / Node
    canvas.drawCircle(center, 4, iconPaint);
    canvas.drawCircle(center, 10, strokePaint..strokeWidth = 2.5);
    canvas.drawCircle(center, 16, strokePaint..strokeWidth = 2);
  } else if (color == const Color(0xff64748b)) {
    // Warehouse - Box/Building
    final path = Path();
    path.moveTo(center.dx - 12, center.dy + 10);
    path.lineTo(center.dx - 12, center.dy - 6);
    path.lineTo(center.dx, center.dy - 12);
    path.lineTo(center.dx + 12, center.dy - 6);
    path.lineTo(center.dx + 12, center.dy + 10);
    path.close();
    canvas.drawPath(path, strokePaint..style = PaintingStyle.stroke..strokeWidth = 3.5);
    canvas.drawLine(Offset(center.dx - 4, center.dy + 10), Offset(center.dx - 4, center.dy + 2), strokePaint..strokeWidth = 2);
    canvas.drawLine(Offset(center.dx + 4, center.dy + 10), Offset(center.dx + 4, center.dy + 2), strokePaint..strokeWidth = 2);
    canvas.drawLine(Offset(center.dx - 4, center.dy + 2), Offset(center.dx + 4, center.dy + 2), strokePaint..strokeWidth = 2);
  } else if (color == const Color(0xff0ea5e9)) {
    // Water Source - Drop
    final path = Path();
    path.moveTo(center.dx, center.dy - 14);
    path.quadraticBezierTo(center.dx + 10, center.dy - 2, center.dx + 10, center.dy + 6);
    path.arcToPoint(Offset(center.dx - 10, center.dy + 6), radius: const Radius.circular(10), clockwise: false);
    path.quadraticBezierTo(center.dx - 10, center.dy - 2, center.dx, center.dy - 14);
    canvas.drawPath(path, iconPaint);
  } else {
    // Fallback simple circle
    canvas.drawCircle(center, 10, iconPaint);
  }

  final image = await recorder.endRecording().toImage(
    size.toInt(),
    size.toInt(),
  );
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
