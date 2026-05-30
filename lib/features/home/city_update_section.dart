import 'package:flutter/material.dart';
import 'package:konektizen/features/home/city_update_link.dart';
import 'package:konektizen/features/home/city_update_link_card.dart';

class CityUpdateSection extends StatelessWidget {
  const CityUpdateSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.links,
  });

  final String title;
  final String subtitle;
  final List<CityUpdateLink> links;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          ...links.map(
            (link) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: CityUpdateLinkCard(link: link),
            ),
          ),
        ],
      ),
    );
  }
}
