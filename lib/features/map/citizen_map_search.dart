import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:konektizen/theme/app_theme.dart';

class CitizenMapSearchOverlay extends StatefulWidget {
  final VoidCallback onClose;
  final Function(double lat, double lng, String name) onSelect;

  const CitizenMapSearchOverlay({
    super.key,
    required this.onClose,
    required this.onSelect,
  });

  @override
  State<CitizenMapSearchOverlay> createState() => _CitizenMapSearchOverlayState();
}

class _CitizenMapSearchOverlayState extends State<CitizenMapSearchOverlay> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  bool _isLoading = false;
  List<Map<String, dynamic>> _results = [];

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    _debounce = Timer(const Duration(milliseconds: 600), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    try {
      final url = Uri.parse(
          "https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(query)}&city=Laoag&format=json&limit=6&countrycodes=ph");
      final response = await http.get(url, headers: {
        'User-Agent': 'Konektizen/1.0 (Mobile App)'
      }).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _results = data.cast<Map<String, dynamic>>();
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Search error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
      child: Container(
        color: Colors.white.withOpacity(0.4),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          onChanged: _onSearchChanged,
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.black87,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search places in Laoag...',
                            hintStyle: GoogleFonts.inter(color: Colors.black38),
                            prefixIcon: const Icon(Icons.search, color: Colors.black54),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, color: Colors.black54),
                                    onPressed: () {
                                      _searchController.clear();
                                      _onSearchChanged('');
                                    },
                                  )
                                : null,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: widget.onClose,
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.close, color: Colors.black87),
                      ),
                    ),
                  ],
                ),
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              if (!_isLoading && _results.isNotEmpty)
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _results.length,
                    separatorBuilder: (context, index) => Divider(color: Colors.black.withOpacity(0.05)),
                    itemBuilder: (context, index) {
                      final place = _results[index];
                      final displayName = place['display_name'] as String;
                      final nameParts = displayName.split(', ');
                      final title = nameParts.first;
                      final subtitle = nameParts.skip(1).join(', ');

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        tileColor: Colors.white.withOpacity(0.6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.place, color: AppTheme.primary),
                        ),
                        title: Text(
                          title,
                          style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 16, color: Colors.black87),
                        ),
                        subtitle: Text(
                          subtitle,
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.black54),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        onTap: () {
                          final lat = double.tryParse(place['lat'].toString()) ?? 0;
                          final lon = double.tryParse(place['lon'].toString()) ?? 0;
                          widget.onSelect(lat, lon, title);
                        },
                      );
                    },
                  ),
                ),
              if (!_isLoading && _results.isEmpty && _searchController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Text(
                    'No results found in Laoag City.',
                    style: GoogleFonts.inter(color: Colors.black54, fontSize: 15),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
