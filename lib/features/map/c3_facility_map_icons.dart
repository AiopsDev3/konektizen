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

  final textPainter = TextPainter(
    text: TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        color: Colors.white,
        fontSize: 34,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();

  textPainter.paint(
    canvas,
    center - Offset(textPainter.width / 2, textPainter.height / 2),
  );

  final image = await recorder.endRecording().toImage(
    size.toInt(),
    size.toInt(),
  );
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
