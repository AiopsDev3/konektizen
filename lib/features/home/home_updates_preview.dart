import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:konektizen/features/home/city_update_link.dart';
import 'package:konektizen/features/home/city_update_sources.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeUpdatesPreview extends ConsumerWidget {
  const HomeUpdatesPreview({super.key});

  Future<void> _openLink(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open this link right now.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final alerts = [
      {
        'link': alertNotificationLinks[0], // CDRRMO Alerts
        'time': '10:30 AM',
        'avatarBgColor': const Color(0xFFE8F5E9), // Light Green
        'iconColor': const Color(0xFF2E7D32), // Dark Green
      },
      {
        'link': alertNotificationLinks[1], // PAGASA Cyclone Bulletins
        'time': '9:15 AM',
        'avatarBgColor': const Color(0xFFFFF3E0), // Light Orange
        'iconColor': const Color(0xFFE65100), // Dark Orange
      },
      {
        'link': alertNotificationLinks[2], // PHIVOLCS Earthquake Info
        'time': '8:45 AM',
        'avatarBgColor': const Color(0xFFE0F2F1), // Light Teal
        'iconColor': const Color(0xFF00695C), // Dark Teal
      },
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Alerts & News',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
              ),
              TextButton(
                onPressed: () {
                  context.push('/home/city-updates');
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
          // Single white card holding all alert items with dividers
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.01),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Column(
              children: List.generate(alerts.length * 2 - 1, (index) {
                if (index.isOdd) {
                  return const Divider(
                    height: 1,
                    thickness: 1,
                    color: Color(0xFFF1F5F9),
                    indent: 64, // Align divider nicely past the avatar
                  );
                }

                final alertIndex = index ~/ 2;
                final alert = alerts[alertIndex];
                final item = alert['link'] as CityUpdateLink;
                final time = alert['time'] as String;
                final avatarBg = alert['avatarBgColor'] as Color;
                final iconColor = alert['iconColor'] as Color;

                return InkWell(
                  onTap: () => _openLink(context, item.url),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Circle avatar badge
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: avatarBg,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            item.icon,
                            color: iconColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 14),
                        // Text column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                item.title,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1E293B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.description,
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFF64748B),
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Trailing info
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              time,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                            const SizedBox(width: 2),
                            const Icon(
                              Icons.chevron_right,
                              color: Color(0xFF94A3B8),
                              size: 16,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
