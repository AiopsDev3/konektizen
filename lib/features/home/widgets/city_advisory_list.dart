import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:konektizen/features/weather/weather_advisory_provider.dart';
import 'package:konektizen/features/home/widgets/city_advisory_models.dart';
import 'package:konektizen/features/home/widgets/city_advisory_filters.dart';
import 'package:konektizen/features/home/widgets/city_advisory_card.dart';

class CityAdvisoryList extends ConsumerWidget {
  const CityAdvisoryList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFilter = ref.watch(selectedCategoryFilterProvider);
    final advisoriesAsync = ref.watch(weatherAdvisoriesProvider);

    return advisoriesAsync.when(
      data: (items) {
        final List<AdvisoryDisplayItem> allItems = [];
        for (final item in items) {
          String category = 'Advisory';
          final titleLower = item.title.toLowerCase();
          final sourceLower = (item.sourceName ?? '').toLowerCase();
          final summaryLower = item.summary.toLowerCase();
          
          final isAlert = titleLower.contains('flood') || 
              titleLower.contains('typhoon') || 
              titleLower.contains('warning') || 
              titleLower.contains('alert') || 
              titleLower.contains('emergency') ||
              titleLower.contains('fire') ||
              titleLower.contains('earthquake') ||
              titleLower.contains('lindol') ||
              titleLower.contains('drill') ||
              summaryLower.contains('bagyo') ||
              summaryLower.contains('sunog') ||
              summaryLower.contains('pagbaha') ||
              summaryLower.contains('fire') ||
              summaryLower.contains('earthquake') ||
              summaryLower.contains('drill') ||
              summaryLower.contains('lindol');

          final isWeather = titleLower.contains('rain') || 
              titleLower.contains('weather') || 
              titleLower.contains('temp') || 
              titleLower.contains('heat') || 
              titleLower.contains('thunderstorm') || 
              titleLower.contains('lightning') || 
              titleLower.contains('cyclone') || 
              titleLower.contains('earthquake') ||
              sourceLower.contains('pagasa') ||
              sourceLower.contains('phivolcs') ||
              summaryLower.contains('rain') ||
              summaryLower.contains('weather') ||
              summaryLower.contains('thunderstorm');
              
          final isTraffic = titleLower.contains('road') || 
              titleLower.contains('traffic') || 
              titleLower.contains('closure') || 
              titleLower.contains('detour') || 
              titleLower.contains('street');

          final isFacebook = sourceLower.contains('facebook') || titleLower.contains('facebook') || item.signalId.toLowerCase().contains('facebook');

          if (isAlert) {
            category = 'Alerts';
          } else if (isWeather) {
            category = 'Weather';
          } else if (isTraffic) {
            category = 'Traffic';
          } else if (isFacebook) {
            category = 'Facebook';
          } else if (sourceLower.contains('news') || 
                     titleLower.contains('news') || 
                     sourceLower.contains('page') || 
                     sourceLower.contains('link') || 
                     sourceLower.contains('website') || 
                     sourceLower.contains('tribune') || 
                     sourceLower.contains('inquirer') || 
                     sourceLower.contains('bulletin') || 
                     sourceLower.contains('star') || 
                     sourceLower.contains('times') || 
                     sourceLower.contains('agency') || 
                     sourceLower.contains('online') || 
                     sourceLower.contains('journal')) {
            category = 'News';
          }

          final imageVal = item.metrics['imageUrl'];
          final String? imageUrl = imageVal?.toString();

          allItems.add(
            AdvisoryDisplayItem(
              category: category,
              title: item.title,
              source: item.sourceName ?? 'PAGASA',
              timeText: _formatTimeAgo(item.issuedAt),
              description: item.summary,
              url: item.sourceUrl,
              imageUrl: imageUrl,
            ),
          );
        }

        final filteredItems = allItems.where((item) {
          if (selectedFilter == 'All') return true;
          
          final categoryLower = item.category.toLowerCase();
          final titleLower = item.title.toLowerCase();
          final descLower = item.description.toLowerCase();
          final sourceLower = item.source.toLowerCase();
          
          final isFacebook = sourceLower.contains('facebook') || titleLower.contains('facebook');
          final isPAGASA = sourceLower.contains('pagasa');
          final isPHIVOLCS = sourceLower.contains('phivolcs');
          final isCDRRMO = sourceLower.contains('cdrrmo');
          
          final isAlertKeyword = titleLower.contains('flood') || 
              titleLower.contains('typhoon') || 
              titleLower.contains('warning') || 
              titleLower.contains('alert') || 
              titleLower.contains('emergency') ||
              titleLower.contains('fire') ||
              titleLower.contains('earthquake') ||
              titleLower.contains('lindol') ||
              titleLower.contains('drill') ||
              descLower.contains('bagyo') ||
              descLower.contains('sunog') ||
              descLower.contains('lindol') ||
              descLower.contains('pagbaha') ||
              descLower.contains('baha') ||
              descLower.contains('fire') ||
              descLower.contains('earthquake') ||
              descLower.contains('drill');
              
          final isWeatherKeyword = titleLower.contains('rain') || 
              titleLower.contains('weather') || 
              titleLower.contains('temp') || 
              titleLower.contains('heat') || 
              titleLower.contains('thunderstorm') || 
              titleLower.contains('lightning') || 
              titleLower.contains('cyclone') || 
              titleLower.contains('earthquake') ||
              descLower.contains('rain') ||
              descLower.contains('weather') ||
              descLower.contains('thunderstorm');

          if (selectedFilter == 'Alerts') {
            return categoryLower == 'alerts' || isAlertKeyword || isPAGASA || isPHIVOLCS || isCDRRMO;
          }
          if (selectedFilter == 'Weather') {
            return categoryLower == 'weather' || isWeatherKeyword || isPAGASA || isPHIVOLCS;
          }
          if (selectedFilter == 'Traffic') {
            return categoryLower == 'traffic' || titleLower.contains('traffic') || titleLower.contains('road') || titleLower.contains('street') || descLower.contains('traffic');
          }
          if (selectedFilter == 'News') {
            return categoryLower == 'news' || sourceLower.contains('news') || sourceLower.contains('inquirer') || sourceLower.contains('tribune') || sourceLower.contains('star');
          }
          if (selectedFilter == 'Facebook') {
            return isFacebook;
          }
          if (selectedFilter == 'Advisory') {
            return categoryLower == 'advisory' || categoryLower == 'alerts';
          }
          return false;
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (filteredItems.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 40),
                width: double.infinity,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.inbox_rounded,
                      color: Color(0xFF94A3B8),
                      size: 36,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'All clear! No active advisories found.',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  return CityAdvisoryCard(item: filteredItems[index]);
                },
              ),
          ],
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        width: double.infinity,
        alignment: Alignment.center,
        child: const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0F766E)),
        ),
      ),
      error: (err, stack) => Container(
        padding: const EdgeInsets.symmetric(vertical: 40),
        width: double.infinity,
        alignment: Alignment.center,
        child: Text(
          'Error loading advisories: $err',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.red,
          ),
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes} mins ago';
    if (diff.inHours < 24) return '${diff.inHours} hours ago';
    return '${diff.inDays} days ago';
  }
}
