import 'package:flutter/material.dart';
import 'package:konektizen/theme/app_theme.dart';

void showWeatherSnackBar(
  BuildContext context, {
  required String title,
  required String body,
  bool isAlert = false,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  messenger?.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: isAlert ? AppTheme.secondary : AppTheme.primary,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(body, maxLines: 3, overflow: TextOverflow.ellipsis),
        ],
      ),
    ),
  );
}
