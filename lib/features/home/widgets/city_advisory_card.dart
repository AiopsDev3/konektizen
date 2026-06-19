import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:konektizen/features/home/widgets/city_advisory_models.dart';
import 'package:url_launcher/url_launcher.dart';

class CityAdvisoryCard extends StatelessWidget {
  final AdvisoryDisplayItem item;
  const CityAdvisoryCard({super.key, required this.item});

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    Color accentColor;
    Color lightBgColor;
    Color buttonBgColor;
    IconData icon;
    String badgeText;

    switch (item.category) {
      case 'Alerts':
        accentColor = const Color(0xFFEF4444);
        lightBgColor = const Color(0xFFFEF2F2);
        buttonBgColor = const Color(0xFFFEE2E2);
        icon = Icons.warning_amber_rounded;
        badgeText = 'EMERGENCY';
        break;
      case 'Weather':
        accentColor = const Color(0xFFEA580C);
        lightBgColor = const Color(0xFFFFF7ED);
        buttonBgColor = const Color(0xFFFFEDD5);
        icon = Icons.thunderstorm_outlined;
        badgeText = 'WEATHER';
        break;
      case 'Traffic':
        accentColor = const Color(0xFFD97706);
        lightBgColor = const Color(0xFFFEF3C7);
        buttonBgColor = const Color(0xFFFDE68A);
        icon = Icons.construction_rounded;
        badgeText = 'TRAFFIC';
        break;
      case 'News':
        accentColor = const Color(0xFF9333EA);
        lightBgColor = const Color(0xFFFAF5FF);
        buttonBgColor = const Color(0xFFF3E8FF);
        icon = Icons.article_outlined;
        badgeText = 'NEWS';
        break;
      case 'Facebook':
        accentColor = const Color(0xFF1877F2);
        lightBgColor = const Color(0xFFE8F0FE);
        buttonBgColor = const Color(0xFFD2E3FC);
        icon = Icons.facebook_rounded;
        badgeText = 'FACEBOOK';
        break;
      case 'Advisory':
      default:
        accentColor = const Color(0xFF16A34A);
        lightBgColor = const Color(0xFFF0FDF4);
        buttonBgColor = const Color(0xFFDCFCE7);
        icon = Icons.domain_rounded;
        badgeText = 'ADVISORY';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
          bottomRight: Radius.circular(16),
          topLeft: Radius.circular(4),
          bottomLeft: Radius.circular(4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0, top: 0, bottom: 0, width: 4,
            child: Container(
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(4), bottomLeft: Radius.circular(4)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 14, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: lightBgColor, shape: BoxShape.circle),
                  alignment: Alignment.center,
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        badgeText,
                        style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: accentColor, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.title,
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.source}  •  ${item.timeText}',
                        style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w500, color: const Color(0xFF94A3B8)),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.description,
                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w500, color: const Color(0xFF475569), height: 1.35),
                      ),
                      if (item.imageUrl != null && item.imageUrl!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            item.imageUrl!,
                            width: double.infinity,
                            height: 150,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        if (item.url != null && item.url!.isNotEmpty) {
                          _launchUrl(item.url!);
                        } else {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              title: Row(
                                children: [
                                  Icon(icon, color: accentColor),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 16),
                                    ),
                                  ),
                                ],
                              ),
                              content: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: lightBgColor,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            badgeText,
                                            style: GoogleFonts.inter(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w900,
                                              color: accentColor,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${item.source}  •  ${item.timeText}',
                                          style: GoogleFonts.inter(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF64748B),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    if (item.imageUrl != null && item.imageUrl!.isNotEmpty) ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: Image.network(
                                          item.imageUrl!,
                                          width: double.infinity,
                                          height: 200,
                                          fit: BoxFit.cover,
                                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                    ],
                                    Text(
                                      item.description,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: const Color(0xFF334155),
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(
                                    'Close',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF64748B),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                      },
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: buttonBgColor, borderRadius: BorderRadius.circular(14)),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'View Details',
                              style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w800, color: accentColor),
                            ),
                            const SizedBox(width: 2),
                            Icon(Icons.chevron_right, color: accentColor, size: 11),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
