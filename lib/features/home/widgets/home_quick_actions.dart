import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:konektizen/theme/app_theme.dart';

class HomeQuickActions extends StatelessWidget {
  const HomeQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final categories = [
      {
        'icon': Icons.delete_outline,
        'label': 'Basura',
        'category_key': 'BASURA',
        'color': AppTheme.secondary,
      },
      {
        'icon': Icons.add_road,
        'label': 'Kalsada',
        'category_key': 'KALSADA',
        'color': AppTheme.primary,
      },
      {
        'icon': Icons.water_drop_outlined,
        'label': 'Pagbaha',
        'category_key': 'PAGBAHA',
        'color': Colors.blue,
      },
      {
        'icon': Icons.lightbulb_outline,
        'label': 'Ilaw sa Kalye',
        'category_key': 'ILAW_SA_KALYE',
        'color': AppTheme.tertiary,
      },
      {
        'icon': Icons.traffic,
        'label': 'Trapiko',
        'category_key': 'TRAPIKO',
        'color': Colors.red,
      },
      {
        'icon': Icons.assignment_add,
        'label': 'Mag-ulat',
        'category_key': 'IBA_PA',
        'color': Colors.purple,
        'isReport': true,
      },
    ];

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Magsumbong',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 1.1,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final item = categories[index];
              return InkWell(
                onTap: () {
                  if (item['isReport'] == true) {
                    context.push('/report');
                  } else {
                    context.push('/report?category=${item['category_key']}');
                  }
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: (item['color'] as Color).withValues(alpha: 0.5),
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: (item['color'] as Color).withValues(
                            alpha: 0.1,
                          ),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          item['icon'] as IconData,
                          color: item['color'] as Color,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item['label'] as String,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
