import 'package:flutter/material.dart';


class CityUpdatesScreen extends StatelessWidget {
  const CityUpdatesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Mock Data for updates
    final updates = [
      {
        'title': 'Suspension of Classes',
        'date': 'Oct 24, 2025 • 6:00 AM',
        'content': 'Classes at all levels are suspended today due to Typhoon Kristine.',
        'type': 'Advisory',
        'color': Colors.orange,
      },
      {
        'title': 'Free Medical Mission',
        'date': 'Oct 20, 2025 • 8:00 AM',
        'content': 'Join us at the City Plaza for a free medical check-up and dental mission.',
        'type': 'Announcement',
        'color': Colors.blue,
      },
      {
        'title': 'Road Closure Alert',
        'date': 'Oct 18, 2025 • 10:30 AM',
        'content': 'Mabini Street will be closed for road repairs from 8:00 PM to 4:00 AM.',
        'type': 'Traffic',
        'color': Colors.red,
      },
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('City Updates'),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: updates.length,
        separatorBuilder: (context, index) => const SizedBox(height: 16),
        itemBuilder: (context, index) {
          final item = updates[index];
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (item['color'] as Color).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        (item['type'] as String).toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: item['color'] as Color,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      item['date'] as String,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  item['title'] as String,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  item['content'] as String,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
