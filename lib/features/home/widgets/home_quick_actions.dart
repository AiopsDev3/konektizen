import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:konektizen/core/localization/app_localizations.dart';
import 'package:konektizen/features/cases/cases_provider.dart';

class HomeQuickActions extends ConsumerWidget {
  const HomeQuickActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(appStringsProvider);
    final double screenWidth = MediaQuery.of(context).size.width;
    final cases = ref.watch(caseListProvider);

    int getReportCount(String categoryKey) {
      return cases.where((c) => c.category.toUpperCase() == categoryKey.toUpperCase()).length;
    }

    // Dynamically calculate responsive font sizes based on screen width
    final double titleFontSize = (screenWidth * 0.035).clamp(12.0, 14.5);
    final double descFontSize = (screenWidth * 0.026).clamp(9.2, 11.2);
    final double footerFontSize = (screenWidth * 0.026).clamp(9.2, 11.2);

    // centralize category list
    final categories = [
      {
        'icon': Icons.delete_outline_rounded,
        'label': t.text('home.category.garbage'),
        'description': 'Report waste collection issues in your area.',
        'reports': '${getReportCount('BASURA')} Reports',
        'category_key': 'BASURA',
        'color': const Color(0xFFEA580C), // Orange
      },
      {
        'icon': Icons.edit_road_rounded,
        'label': t.text('home.category.road'),
        'description': 'Report road damage, hazards, or obstructions.',
        'reports': '${getReportCount('KALSADA')} Reports',
        'category_key': 'KALSADA',
        'color': const Color(0xFF16A34A), // Green
      },
      {
        'icon': Icons.water_drop_rounded,
        'label': t.text('home.category.flood'),
        'description': 'Report flooding or water accumulation.',
        'reports': '${getReportCount('PAGBAHA')} Reports',
        'category_key': 'PAGBAHA',
        'color': const Color(0xFF2563EB), // Blue
      },
      {
        'icon': Icons.lightbulb_outline_rounded,
        'label': t.text('home.category.streetLight'),
        'description': 'Report faulty or non-working lights.',
        'reports': '${getReportCount('ILAW_SA_KALYE')} Reports',
        'category_key': 'ILAW_SA_KALYE',
        'color': const Color(0xFFEAB308), // Yellow
      },
      {
        'icon': Icons.traffic_rounded,
        'label': t.text('home.category.traffic'),
        'description': 'Report traffic issues or violations.',
        'reports': '${getReportCount('TRAPIKO')} Reports',
        'category_key': 'TRAPIKO',
        'color': const Color(0xFFDC2626), // Red
      },
      {
        'icon': Icons.assignment_add,
        'label': 'Other Request',
        'description': 'Report other concerns or service requests.',
        'reports': '${getReportCount('IBA_PA')} Requests',
        'category_key': 'IBA_PA',
        'color': const Color(0xFF9333EA), // Purple
        'isReport': true
      },
    ];

    // Compute dynamic child aspect ratio to ensure cards are taller on narrow screens
    final double cardWidth = (screenWidth - 32 - 20) / 3; // Subtracting margins and horizontal spacing
    final double targetHeight = (titleFontSize * 1.3) + (descFontSize * 3.0) + 98; // safe content height
    final double childAspectRatio = (cardWidth / targetHeight).clamp(0.58, 0.78);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Report & Request',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
              ),
              TextButton(
                onPressed: () {
                  context.push('/profile/my-cases');
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  children: [
                    Text(
                      'View All',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF166534), // Green Accent Link
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(
                      Icons.chevron_right,
                      color: Color(0xFF166534),
                      size: 14,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: childAspectRatio,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final item = categories[index];
              return _QuickActionCard(
                icon: item['icon'] as IconData,
                label: item['label'] as String,
                description: item['description'] as String,
                reports: item['reports'] as String,
                color: item['color'] as Color,
                titleFontSize: titleFontSize,
                descFontSize: descFontSize,
                footerFontSize: footerFontSize,
                onTap: () => item['isReport'] == true
                    ? context.push('/report')
                    : context.push('/report?category=${item['category_key']}'),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _QuickActionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final String description;
  final String reports;
  final Color color;
  final double titleFontSize;
  final double descFontSize;
  final double footerFontSize;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.reports,
    required this.color,
    required this.titleFontSize,
    required this.descFontSize,
    required this.footerFontSize,
    required this.onTap,
  });

  @override
  State<_QuickActionCard> createState() => _QuickActionCardState();
}

class _QuickActionCardState extends State<_QuickActionCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 80));
    _scale = Tween<double>(begin: 1.0, end: 0.96).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scale,
      child: GestureDetector(
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) {
          _controller.reverse();
          widget.onTap();
        },
        onTapCancel: () => _controller.reverse(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.01),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon Badge
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(widget.icon, color: widget.color, size: 20),
              ),
              const SizedBox(height: 8),
              // Category Name
              Text(
                widget.label,
                style: GoogleFonts.inter(
                  fontSize: widget.titleFontSize,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 3),
              // Description
              Expanded(
                child: Text(
                  widget.description,
                  style: GoogleFonts.inter(
                    fontSize: widget.descFontSize,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF64748B),
                    height: 1.25,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 6),
              // Footer link
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.reports,
                      style: GoogleFonts.inter(
                        fontSize: widget.footerFontSize,
                        fontWeight: FontWeight.w800,
                        color: widget.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: widget.color,
                    size: 13,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
