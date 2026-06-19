import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:konektizen/features/profile/accessibility_provider.dart';
import 'package:konektizen/features/sos/emergency_hotlines_data.dart';

class EmergencyHotlinesScreen extends ConsumerStatefulWidget {
  const EmergencyHotlinesScreen({super.key});

  @override
  ConsumerState<EmergencyHotlinesScreen> createState() => _EmergencyHotlinesScreenState();
}

class _EmergencyHotlinesScreenState extends ConsumerState<EmergencyHotlinesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final isScreenReader = ref.read(accessibilityProvider).screenReader;
    if (isScreenReader) {
      // ignore: deprecated_member_use
      SemanticsService.announce('Emergency Hotline Numbers Opened', TextDirection.ltr);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _makeCall(String number) async {
    final clean = number.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isHighContrast = ref.watch(accessibilityProvider).highContrast;

    final filteredGroups = emergencyHotlineCategories.map((group) {
      final matchedItems = group.items.where((item) {
        final query = _searchQuery.toLowerCase();
        return item.name.toLowerCase().contains(query) ||
            item.number.contains(query) ||
            item.desc.toLowerCase().contains(query);
      }).toList();
      return HotlineGroupModel(
        title: group.title,
        icon: group.icon,
        color: group.color,
        items: matchedItems,
      );
    }).where((group) => group.items.isNotEmpty).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: filteredGroups.isEmpty
                ? Center(
                    child: Text(
                      'No matching hotlines found.',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    itemCount: filteredGroups.length + 1,
                    itemBuilder: (context, index) {
                      if (index == filteredGroups.length) {
                        return _buildFooterCard(isHighContrast);
                      }
                      final group = filteredGroups[index];
                      return _buildGroupSection(group, isHighContrast);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 24,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F5132), Color(0xFF1B6A45)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EMERGENCY HOTLINES',
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Quick access to important hotlines and departments',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search hotlines or departments...',
                hintStyle: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B)),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Color(0xFF64748B)),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : const Padding(
                        padding: EdgeInsets.only(right: 12),
                        child: Icon(Icons.tune_rounded, color: Color(0xFF64748B)),
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroupSection(HotlineGroupModel group, bool isHighContrast) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
          child: Row(
            children: [
              Icon(group.icon, color: isHighContrast ? Colors.black : group.color, size: 18),
              const SizedBox(width: 8),
              Text(
                group.title.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: isHighContrast ? Colors.black : const Color(0xFF475569),
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        ...group.items.map((item) => _buildHotlineCard(item, group.color, isHighContrast)),
      ],
    );
  }

  Widget _buildHotlineCard(HotlineItemModel item, Color themeColor, bool isHighContrast) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 4,
              color: isHighContrast ? Colors.black : themeColor,
            ),
            const SizedBox(width: 12),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: _buildIconContainer(item, themeColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      item.name,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: isHighContrast ? Colors.black : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.number,
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: isHighContrast ? Colors.black : themeColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.desc,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: const Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 52,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isHighContrast ? Colors.black : themeColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => _makeCall(item.number),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.call_rounded, size: 18, color: Colors.white),
                      const SizedBox(height: 2),
                      Text(
                        'CALL',
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconContainer(HotlineItemModel item, Color categoryColor) {
    if (item.number == '911') {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: categoryColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '911',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: categoryColor,
              ),
            ),
            Icon(
              Icons.phone_rounded,
              size: 10,
              color: categoryColor,
            ),
          ],
        ),
      );
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: categoryColor.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(
        _getIconForName(item.name),
        color: categoryColor,
        size: 22,
      ),
    );
  }

  IconData _getIconForName(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('office') || lower.contains('station') || lower.contains('hospital') || lower.contains('center') || lower.contains('ablan') || lower.contains('clinic') || lower.contains('chapter')) {
      if (lower.contains('police')) {
        return Icons.local_police_rounded;
      }
      if (lower.contains('hospital') || lower.contains('clinic') || lower.contains('ablan') || lower.contains('red cross')) {
        return Icons.local_hospital_rounded;
      }
      return Icons.business_rounded;
    }
    if (lower.contains('smart') || lower.contains('globe') || lower.contains('mobile')) {
      if (lower.contains('globe')) {
        return Icons.public_rounded;
      }
      return Icons.phone_android_rounded;
    }
    if (lower.contains('alt line') || lower.contains('secondary')) {
      return Icons.headset_mic_rounded;
    }
    return Icons.phone_in_talk_rounded;
  }

  Widget _buildFooterCard(bool isHighContrast) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isHighContrast ? Colors.white : const Color(0xFFF0FDF4),
        border: Border.all(
          color: isHighContrast ? Colors.black : const Color(0xFFDCFCE7),
          width: isHighContrast ? 2 : 1.5,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isHighContrast ? Colors.black : const Color(0xFFDCFCE7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.verified_user_rounded,
              color: isHighContrast ? Colors.white : const Color(0xFF15803D),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'In Case of Emergency',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isHighContrast ? Colors.black : const Color(0xFF166534),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Stay calm and call the appropriate hotline. Your safety is our priority.',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: isHighContrast ? Colors.black : const Color(0xFF15803D),
                    fontWeight: FontWeight.w500,
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
