import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:konektizen/features/verification/barangay_data.dart';

class LocationCard extends StatefulWidget {
  final TextEditingController barangayController;
  final TextEditingController streetController;
  final bool isLoading;

  const LocationCard({
    super.key,
    required this.barangayController,
    required this.streetController,
    required this.isLoading,
  });

  @override
  State<LocationCard> createState() => _LocationCardState();
}

class _LocationCardState extends State<LocationCard> {
  String? _selectedBarangay;
  late List<String> _laoagBarangays;

  @override
  void initState() {
    super.initState();
    _laoagBarangays = BarangayData.getBarangays('Laoag City');
    if (_laoagBarangays.contains(widget.barangayController.text)) {
      _selectedBarangay = widget.barangayController.text;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF3E0), // Light orange container
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: Color(0xFFE65100), // Dark orange icon
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Alert Location',
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          DropdownButtonFormField<String>(
            initialValue: _selectedBarangay,
            isExpanded: true,
            hint: Text(
              widget.barangayController.text.isNotEmpty
                  ? widget.barangayController.text
                  : 'Select your barangay',
              style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF64748B)),
              overflow: TextOverflow.ellipsis,
            ),
            decoration: const InputDecoration(
              labelText: 'Barangay',
              prefixIcon: Icon(Icons.location_city_outlined, size: 20),
            ),
            items: _laoagBarangays
                .map(
                  (barangay) => DropdownMenuItem(
                    value: barangay,
                    child: Text(
                      barangay,
                      style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1E293B)),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: widget.isLoading
                ? null
                : (value) {
                    setState(() {
                      _selectedBarangay = value;
                      widget.barangayController.text = value ?? '';
                    });
                  },
            validator: (value) {
              if ((value == null || value.isEmpty) &&
                  widget.barangayController.text.isEmpty) {
                return 'Please select your barangay';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: widget.streetController,
            enabled: !widget.isLoading,
            style: GoogleFonts.inter(fontSize: 14, color: const Color(0xFF1E293B)),
            decoration: const InputDecoration(
              labelText: 'Street / House Address (Optional)',
              prefixIcon: Icon(Icons.home_outlined, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
