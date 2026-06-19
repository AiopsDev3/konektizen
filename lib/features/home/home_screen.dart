import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:konektizen/features/home/home_updates_preview.dart';
import 'package:konektizen/features/home/widgets/home_header.dart';
import 'package:konektizen/features/home/widgets/home_weather_forecast.dart';
import 'package:konektizen/features/home/widgets/home_quick_actions.dart';
import 'package:konektizen/features/home/widgets/home_active_reports.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF8FAFC), // Modern Slate 50 background
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeHeader(),
            HomeWeatherForecast(),
            HomeQuickActions(),
            HomeUpdatesPreview(),
            HomeActiveReports(),
          ],
        ),
      ),
    );
  }
}
