import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:konektizen/features/home/widgets/city_advisory_models.dart';
import 'package:konektizen/features/home/widgets/city_advisory_metrics.dart';
import 'package:konektizen/features/home/widgets/city_advisory_filters.dart';
import 'package:konektizen/features/home/widgets/city_advisory_list.dart';
import 'package:konektizen/features/home/widgets/city_advisory_sources.dart';
import 'package:konektizen/features/weather/weather_advisory_provider.dart';

class CityUpdatesScreen extends ConsumerWidget {
  const CityUpdatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double statusBarHeight = MediaQuery.of(context).padding.top;
    
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50 background
      body: RefreshIndicator(
        color: const Color(0xFF064E3B),
        onRefresh: () async {
          try {
            final result = await ref.read(weatherAdvisoryServiceProvider).syncAdvisories();
            final message = result['message'] ?? 'Sync successful!';
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(message),
                  backgroundColor: const Color(0xFF064E3B),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Sync failed: ${e.toString()}'),
                  backgroundColor: const Color(0xFFEF4444),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
          ref.invalidate(weatherAdvisoriesProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Stack with Bell Tower painting & Overlapping Metrics
              SizedBox(
                height: 230 + statusBarHeight,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // Green Header Background with Sinking Bell Tower painting
                    Positioned(
                      top: 0, left: 0, right: 0,
                      height: 180 + statusBarHeight,
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFF064E3B), // Emerald 900
                              Color(0xFF022C22), // Deep Emerald
                            ],
                          ),
                        ),
                        child: CustomPaint(
                          painter: SkylinePainter(),
                          child: SafeArea(
                            bottom: false,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const SizedBox(height: 10),
                                      Row(
                                        children: [
                                          if (Navigator.canPop(context))
                                            Padding(
                                              padding: const EdgeInsets.only(right: 12.0),
                                              child: GestureDetector(
                                                onTap: () => Navigator.maybePop(context),
                                                child: const Icon(
                                                  Icons.arrow_back_ios_new_rounded,
                                                  color: Colors.white,
                                                  size: 20,
                                                ),
                                              ),
                                            ),
                                          Text(
                                            'City Advisory',
                                            style: GoogleFonts.inter(
                                              fontSize: 26,
                                              fontWeight: FontWeight.w900,
                                              color: Colors.white,
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Stay informed. Stay safe.',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white.withValues(alpha: 0.9),
                                        ),
                                      ),
                                      Text(
                                        'Verified updates from Laoag City.',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white.withValues(alpha: 0.7),
                                        ),
                                      ),
                                    ],
                                  ),
                                  // Refresh Icon button instead of notification bell
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: IconButton(
                                      icon: const Icon(
                                        Icons.sync_rounded,
                                        color: Colors.white,
                                        size: 28,
                                      ),
                                      tooltip: 'Sync News',
                                      onPressed: () async {
                                        try {
                                          final result = await ref.read(weatherAdvisoryServiceProvider).syncAdvisories();
                                          final message = result['message'] ?? 'Sync successful!';
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text(message),
                                                backgroundColor: const Color(0xFF064E3B),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        } catch (e) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(
                                                content: Text('Sync failed: ${e.toString()}'),
                                                backgroundColor: const Color(0xFFEF4444),
                                                behavior: SnackBarBehavior.floating,
                                              ),
                                            );
                                          }
                                        }
                                        ref.invalidate(weatherAdvisoriesProvider);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    
                    // Floating Metrics Card (Overlaps the bottom of green header)
                    Positioned(
                      top: 135 + statusBarHeight,
                      left: 16,
                      right: 16,
                      child: const CityAdvisoryMetrics(),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Horizontal Filters (spans edge-to-edge but starts with horizontal padding)
              const CityAdvisoryFilters(),
              
              const SizedBox(height: 20),
              
              // Main Body Content with horizontal padding
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    CityAdvisoryList(),
                    SizedBox(height: 24),
                    CityAdvisorySources(),
                    SizedBox(height: 40),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
