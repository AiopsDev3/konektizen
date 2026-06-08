import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:konektizen/features/auth/user_provider.dart';
import 'package:konektizen/theme/app_theme.dart';

class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final greeting = _greetingText(user.fullName);

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
                greeting,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _greetingText(String? fullName) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning'
        : hour < 18
        ? 'Good Afternoon'
        : 'Good Evening';
    final name = _displayName(fullName);
    return name == null ? greeting : '$greeting, $name';
  }

  String? _displayName(String? fullName) {
    final value = fullName?.trim();
    if (value == null || value.isEmpty) return null;
    if (RegExp(r'^\+?[0-9\s]+$').hasMatch(value) && value.length > 6) {
      return null;
    }
    return value.split(RegExp(r'\s+')).first;
  }
}
