import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:konektizen/features/home/widgets/city_advisory_models.dart';
import 'package:url_launcher/url_launcher.dart';

class CityAdvisorySources extends StatelessWidget {
  const CityAdvisorySources({super.key});

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  void _showAllSourcesBottomSheet(BuildContext context, List<VerifiedSourceItem> allSources) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _AllSourcesBottomSheet(allSources: allSources);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final sources = [
      const VerifiedSourceItem(
        name: 'Laoag CDRRMO',
        description: 'Official disaster risk reduction and emergency updates.',
        icon: Icons.shield_outlined,
        iconColor: Color(0xFF15803D), // Green
        url: 'https://www.facebook.com/laoagcitycdrrmo',
      ),
      const VerifiedSourceItem(
        name: 'PAGASA',
        description: 'Official weather bulletins and updates.',
        icon: Icons.cloud_outlined,
        iconColor: Color(0xFF1D4ED8), // Blue
        url: 'https://bagong.pagasa.dost.gov.ph/',
      ),
      const VerifiedSourceItem(
        name: 'PHIVOLCS',
        description: 'Official earthquake and volcano updates.',
        icon: Icons.landscape_outlined,
        iconColor: Color(0xFF0F766E), // Teal
        url: 'https://www.phivolcs.dost.gov.ph/',
      ),
      const VerifiedSourceItem(
        name: 'City Government of Laoag',
        description: 'Official city announcements and public advisories.',
        icon: Icons.account_balance_outlined,
        iconColor: Color(0xFF0D9488), // Teal
        url: 'https://laoagcity.gov.ph/',
      ),
      const VerifiedSourceItem(
        name: 'Facebook',
        description: 'Real-time community reports and local hazard posts.',
        icon: Icons.facebook,
        iconColor: Color(0xFF1877F2), // Facebook Blue
        url: 'https://www.facebook.com/',
      ),
      const VerifiedSourceItem(
        name: 'INEC (Ilocos Norte Electric)',
        description: 'Official power distribution and maintenance advisories.',
        icon: Icons.flash_on_outlined,
        iconColor: Color(0xFFD97706), // Amber
        url: 'https://www.facebook.com/INECofficial',
      ),
      const VerifiedSourceItem(
        name: 'Bombo Radyo Laoag',
        description: 'Real-time local news reports and radio broadcasts.',
        icon: Icons.radio_outlined,
        iconColor: Color(0xFFDC2626), // Red
        url: 'https://laoag.bomboradyo.com/',
      ),
      const VerifiedSourceItem(
        name: 'Aksyon Radyo Laoag',
        description: 'Local community public service radio broadcasts.',
        icon: Icons.podcasts_outlined,
        iconColor: Color(0xFF9333EA), // Purple
        url: 'https://www.facebook.com/dzjcaksyonradyolaoag',
      ),
      const VerifiedSourceItem(
        name: 'Laoag City Police Station',
        description: 'Public safety alerts and crime prevention notices.',
        icon: Icons.local_police_outlined,
        iconColor: Color(0xFF1E3A8A), // Navy
        url: 'https://www.facebook.com/LaoagCityPoliceStation',
      ),
      const VerifiedSourceItem(
        name: 'DepEd Laoag City',
        description: 'Official class suspension updates and school advisories.',
        icon: Icons.school_outlined,
        iconColor: Color(0xFF0284C7), // Sky Blue
        url: 'https://www.facebook.com/depedtayolaoagcity',
      ),
      const VerifiedSourceItem(
        name: 'DOH Ilocos Region',
        description: 'Department of Health regional advisory bulletins.',
        icon: Icons.health_and_safety_outlined,
        iconColor: Color(0xFF059669), // Emerald
        url: 'https://ro1.doh.gov.ph/',
      ),
    ];

    // Show only the first 4 in the initial widget summary list
    final summarySources = sources.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Verified Sources',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1E293B),
              ),
            ),
            TextButton(
              onPressed: () => _showAllSourcesBottomSheet(context, sources),
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
                      color: const Color(0xFF166534),
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
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.015),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: List.generate(summarySources.length, (index) {
              final item = summarySources[index];
              final isLast = index == summarySources.length - 1;

              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        // Icon Circle
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: item.iconColor.withValues(alpha: 0.08),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(item.icon, color: item.iconColor, size: 20),
                        ),
                        const SizedBox(width: 12),
                        
                        // Texts
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.name,
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
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFF64748B),
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        
                        // Checkmark
                        const Icon(
                          Icons.check_circle,
                          color: Color(0xFF16A34A),
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        
                        // Launch button
                        IconButton(
                          icon: const Icon(
                            Icons.open_in_new,
                            color: Color(0xFF94A3B8),
                            size: 18,
                          ),
                          onPressed: () => _launchUrl(item.url),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      height: 1,
                      color: const Color(0xFFF1F5F9),
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}

class _AllSourcesBottomSheet extends StatefulWidget {
  final List<VerifiedSourceItem> allSources;
  const _AllSourcesBottomSheet({required this.allSources});

  @override
  State<_AllSourcesBottomSheet> createState() => _AllSourcesBottomSheetState();
}

class _AllSourcesBottomSheetState extends State<_AllSourcesBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<VerifiedSourceItem> _filteredSources = [];

  @override
  void initState() {
    super.initState();
    _filteredSources = widget.allSources;
  }

  void _filterSources(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredSources = widget.allSources;
      } else {
        _filteredSources = widget.allSources
            .where((item) =>
                item.name.toLowerCase().contains(query.toLowerCase()) ||
                item.description.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      margin: const EdgeInsets.only(top: 60),
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: const Color(0xFFCBD5E1),
              borderRadius: BorderRadius.circular(2.5),
            ),
          ),
          const SizedBox(height: 20),
          
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Verified Advisory Sources',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF64748B)),
                  onPressed: () => Navigator.pop(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Search Field
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.01),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _filterSources,
                decoration: InputDecoration(
                  hintText: 'Search verified sources...',
                  hintStyle: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A3B8),
                  ),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Color(0xFF94A3B8), size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _filterSources('');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Source list
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.65 - bottomInset,
              ),
              child: _filteredSources.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search_off_outlined, color: Color(0xFF94A3B8), size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'No sources match your search',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(24, 4, 24, 24 + bottomInset),
                      shrinkWrap: true,
                      itemCount: _filteredSources.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final item = _filteredSources[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.01),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: () async {
                              final uri = Uri.parse(item.url);
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: item.iconColor.withValues(alpha: 0.08),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Icon(item.icon, color: item.iconColor, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.name,
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
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF64748B),
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.check_circle,
                                    color: Color(0xFF16A34A),
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.open_in_new,
                                    color: Color(0xFFCBD5E1),
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
