import 'package:flutter/material.dart';
import 'package:konektizen/theme/app_theme.dart';

class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'KONEKTIZEN',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
              Text(
                'Good Morning, Citizen',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
          CircleAvatar(
            backgroundColor: AppTheme.secondary.withValues(alpha: 0.1),
            child: const Icon(
              Icons.notifications_none,
              color: AppTheme.secondary,
            ),
          ),
        ],
      ),
    );
  }
}
