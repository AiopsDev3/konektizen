import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:konektizen/features/home/city_update_section.dart';
import 'package:konektizen/features/home/city_update_sources.dart';
import 'package:konektizen/features/weather/weather_advisory.dart';
import 'package:konektizen/features/weather/weather_advisory_card.dart';
import 'package:konektizen/features/weather/weather_advisory_provider.dart';
import 'package:konektizen/theme/app_theme.dart';

class CityUpdatesScreen extends ConsumerWidget {
  const CityUpdatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advisories = ref.watch(weatherAdvisoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('City Advisory'), centerTitle: true),
      body: RefreshIndicator(
        onRefresh: () async => ref.refresh(weatherAdvisoriesProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
          children: [
            const _Header(),
            const SizedBox(height: 18),
            const CityUpdateSection(
              title: 'Official Pages',
              subtitle: 'Verified city pages residents can open anytime.',
              links: officialCityLinks,
            ),
            const SizedBox(height: 8),
            const CityUpdateSection(
              title: 'Events',
              subtitle: 'City events and public activities from Laoag pages.',
              links: cityEventLinks,
            ),
            const SizedBox(height: 8),
            const CityUpdateSection(
              title: 'Alerts & Notifications',
              subtitle: 'Local and national warning sources for fast checking.',
              links: alertNotificationLinks,
            ),
            const SizedBox(height: 8),
            const CityUpdateSection(
              title: 'News',
              subtitle: 'Source links from CDRRMO Laoag, PAGASA, and PHIVOLCS.',
              links: cityNewsLinks,
            ),
            const SizedBox(height: 8),
            _WeatherAlertsSection(advisories: advisories),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.campaign_outlined, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Laoag City events, alerts, and source-backed news in one place.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherAlertsSection extends StatelessWidget {
  const _WeatherAlertsSection({required this.advisories});

  final AsyncValue<List<WeatherAdvisory>> advisories;

  @override
  Widget build(BuildContext context) {
    return advisories.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (error, stackTrace) => const _WeatherError(),
      data: (items) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live Weather Advisories',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            const _WeatherEmpty()
          else
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: WeatherAdvisoryCard(advisory: item),
              ),
            ),
        ],
      ),
    );
  }
}

class _WeatherError extends StatelessWidget {
  const _WeatherError();

  @override
  Widget build(BuildContext context) {
    return const _MessageBox(
      icon: Icons.cloud_off_outlined,
      text: 'Weather updates are unavailable. Pull to refresh and try again.',
    );
  }
}

class _WeatherEmpty extends StatelessWidget {
  const _WeatherEmpty();

  @override
  Widget build(BuildContext context) {
    return const _MessageBox(
      icon: Icons.check_circle_outline,
      text: 'No active weather advisories in the last 72 hours.',
    );
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.secondary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, textAlign: TextAlign.left)),
        ],
      ),
    );
  }
}
