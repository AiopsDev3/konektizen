import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:konektizen/theme/app_theme.dart';

BoxDecoration mapGlassDecoration(double radius) {
  return BoxDecoration(
    color: Colors.white.withValues(alpha: 0.85),
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: Colors.white.withValues(alpha: 0.5)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.1),
        blurRadius: 15,
        offset: const Offset(0, 5),
      ),
    ],
  );
}

class GlassMapButton extends StatelessWidget {
  const GlassMapButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.loading = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
        child: Container(
          width: 48,
          height: 48,
          decoration: mapGlassDecoration(24),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(24),
              child: Center(
                child: loading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary,
                        ),
                      )
                    : Icon(icon, color: Colors.black87, size: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
