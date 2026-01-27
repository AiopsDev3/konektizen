import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:konektizen/theme/app_theme.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              // Placeholder for Logo/Illustration
              Container(
                height: 200,
                decoration: BoxDecoration(
                  color: AppTheme.tertiary.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_city_rounded,
                  size: 80,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 48),
              Text(
                'Maligayang pagdating sa KONEKTIZEN',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Bigyan ng boses ang bawat mamamayan. Mag-ulat ng problema, subaybayan ang solusyon, at magtayo ng mas magandang lungsod.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFF424242),
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  context.push('/auth/register');
                },
                child: const Text('Magsimula'),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  context.push('/auth/login');
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                ),
                child: const Text(
                  'Mayroon na akong account',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
