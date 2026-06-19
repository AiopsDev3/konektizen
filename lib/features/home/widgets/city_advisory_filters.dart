import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

final selectedCategoryFilterProvider = StateProvider<String>((ref) => 'All');

class CityAdvisoryFilters extends ConsumerWidget {
  const CityAdvisoryFilters({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFilter = ref.watch(selectedCategoryFilterProvider);
    final filters = [
      {'name': 'All', 'icon': Icons.grid_view_rounded, 'color': const Color(0xFF166534)},
      {'name': 'Alerts', 'icon': Icons.warning_amber_rounded, 'color': const Color(0xFFEF4444)},
      {'name': 'Weather', 'icon': Icons.cloudy_snowing, 'color': const Color(0xFF3B82F6)},
      {'name': 'Traffic', 'icon': Icons.traffic_rounded, 'color': const Color(0xFFF59E0B)},
      {'name': 'Advisory', 'icon': Icons.campaign_outlined, 'color': const Color(0xFF16A34A)},
      {'name': 'News', 'icon': Icons.article_outlined, 'color': const Color(0xFF9333EA)},
      {'name': 'Facebook', 'icon': Icons.facebook, 'color': const Color(0xFF1877F2)},
    ];

    return SizedBox(
      height: 36,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final String name = filter['name'] as String;
          final IconData icon = filter['icon'] as IconData;
          final Color color = filter['color'] as Color;
          final isSelected = selectedFilter == name;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                ref.read(selectedCategoryFilterProvider.notifier).state = name;
              },
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? color : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isSelected ? color : const Color(0xFFE2E8F0),
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 14,
                      color: isSelected ? Colors.white : color,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      name,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
                        color: isSelected ? Colors.white : const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
