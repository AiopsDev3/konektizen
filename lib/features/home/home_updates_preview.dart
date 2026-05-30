import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:konektizen/features/home/city_update_link.dart';
import 'package:konektizen/features/home/city_update_sources.dart';
import 'package:konektizen/features/weather/weather_advisory_card.dart';
import 'package:konektizen/features/weather/weather_advisory_provider.dart';
import 'package:konektizen/theme/app_theme.dart';

class HomeUpdatesPreview extends ConsumerWidget {
  const HomeUpdatesPreview({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final advisories = ref.watch(weatherAdvisoriesProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alerts at Balita',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          advisories.when(
            loading: () => const _LoadingBox(),
            error: (error, stackTrace) => _SourceList(
              title: 'Alerts & Notifications',
              items: alertNotificationLinks,
            ),
            data: (items) {
              if (items.isEmpty) {
                return _SourceList(
                  title: 'Alerts & Notifications',
                  items: alertNotificationLinks,
                );
              }
              return Column(
                children: items
                    .take(2)
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: WeatherAdvisoryCard(advisory: item),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 8),
          _SourceList(title: 'News Sources', items: cityNewsLinks),
        ],
      ),
    );
  }
}

class _SourceList extends StatelessWidget {
  const _SourceList({required this.title, required this.items});

  final String title;
  final List<CityUpdateLink> items;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ...items.map((item) => _SourceRow(item: item)),
        ],
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  const _SourceRow({required this.item});

  final CityUpdateLink item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(item.icon, size: 20, color: AppTheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  item.description,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: CircularProgressIndicator(),
      ),
    );
  }
}
