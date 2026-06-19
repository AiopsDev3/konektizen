import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:konektizen/core/localization/app_localizations.dart';
import 'package:konektizen/core/services/location_service.dart';
import 'package:konektizen/core/services/media_service.dart';
import 'package:konektizen/features/report/report_provider.dart';
import 'package:konektizen/features/report/widgets/evidence_media_selector.dart';
import 'package:konektizen/theme/app_theme.dart';

class ReportEvidenceScreen extends ConsumerStatefulWidget {
  const ReportEvidenceScreen({super.key});

  @override
  ConsumerState<ReportEvidenceScreen> createState() => _ReportEvidenceScreenState();
}

class _ReportEvidenceScreenState extends ConsumerState<ReportEvidenceScreen> {
  MapLibreMapController? _mapController;
  LatLng? _selectedLocation;
  String _selectedAddress = '';
  bool _isLoadingLocation = false;
  final bool _mapError = false;
  final TextEditingController _searchController = TextEditingController();
  bool _showMap = true;
  
  final List<File> _mediaFiles = [];
  final List<String> _mediaTypes = [];
  bool _isUploadingMedia = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    if (_isLoadingLocation) return;
    setState(() => _isLoadingLocation = true);
    
    try {
      final position = await locationService.getCurrentLocation();
      if (position != null && mounted) {
        final latLng = LatLng(position.latitude, position.longitude);
        final address = await locationService.getAddressFromCoordinates(position.latitude, position.longitude);
        final city = await locationService.getCityFromCoordinates(position.latitude, position.longitude);
        
        if (mounted) {
          setState(() {
            _selectedLocation = latLng;
            _selectedAddress = address;
            _isLoadingLocation = false;
          });
          
          final currentDraft = ref.read(reportDraftProvider);
          ref.read(reportDraftProvider.notifier).updateDraft(currentDraft.copyWith(
            latitude: position.latitude,
            longitude: position.longitude,
            address: address,
            city: city,
          ));
          
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16.5));
          _updateMarker(latLng);
        }
      } else {
        if (mounted) {
          setState(() {
            _selectedLocation = const LatLng(18.196, 120.598); // Laoag City
            _isLoadingLocation = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _selectedLocation = const LatLng(18.196, 120.598); // Fallback Laoag
          _isLoadingLocation = false;
        });
      }
    }
  }

  Future<void> _searchLocation(String query) async {
    if (query.isEmpty) return;
    setState(() => _isLoadingLocation = true);
    
    try {
      final coordinates = await locationService.searchLocation(query);
      if (coordinates != null && mounted) {
        final latLng = LatLng(coordinates['lat']!, coordinates['lng']!);
        final address = coordinates['address'] as String? ?? 
            await locationService.getAddressFromCoordinates(coordinates['lat']!, coordinates['lng']!);
        final city = await locationService.getCityFromCoordinates(coordinates['lat']!, coordinates['lng']!);
        
        if (mounted) {
          setState(() {
            _selectedLocation = latLng;
            _selectedAddress = address;
            _isLoadingLocation = false;
          });
          
          final currentDraft = ref.read(reportDraftProvider);
          ref.read(reportDraftProvider.notifier).updateDraft(currentDraft.copyWith(
            latitude: coordinates['lat']!,
            longitude: coordinates['lng']!,
            address: address,
            city: city,
          ));
          
          _mapController?.animateCamera(CameraUpdate.newLatLngZoom(latLng, 16.5));
          _updateMarker(latLng);
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingLocation = false);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingLocation = false);
      }
    }
  }

  Future<void> _updateMarker(LatLng position) async {
    if (_mapController == null) return;
    await _mapController!.clearCircles();
    await _mapController!.addCircle(
      CircleOptions(
        geometry: position,
        circleColor: '#FF0000',
        circleRadius: 8,
        circleStrokeWidth: 2,
        circleStrokeColor: '#FFFFFF',
      ),
    );
  }

  void _onMapTap(LatLng location, AppStrings strings) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.text('report.gpsAutoLocked')),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showMediaPreview(String path, String type) {
    if (type == 'video') return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              child: Image.file(
                File(path),
                fit: BoxFit.contain,
                errorBuilder: (c, e, s) => const Icon(Icons.broken_image, color: Colors.white, size: 64),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _capturePhoto() async {
    final file = await mediaService.capturePhoto();
    if (file != null) {
      setState(() {
        _mediaFiles.add(file);
        _mediaTypes.add('photo');
      });
    }
  }

  Future<void> _recordVideo() async {
    final file = await mediaService.recordVideo();
    if (file != null) {
      setState(() {
        _mediaFiles.add(file);
        _mediaTypes.add('video');
      });
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _mediaFiles.removeAt(index);
      _mediaTypes.removeAt(index);
    });
  }

  Future<void> _continue(AppStrings strings) async {
    if (_mediaFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(strings.text('report.evidenceRequired')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isUploadingMedia = true);

    try {
      final currentPos = await locationService.getCurrentLocation();
      if (currentPos != null) {
        final currentDraft = ref.read(reportDraftProvider);
        ref.read(reportDraftProvider.notifier).updateDraft(currentDraft.copyWith(
          reporterLatitude: currentPos.latitude,
          reporterLongitude: currentPos.longitude,
        ));
      }
    } catch (_) {}

    if (_mediaFiles.isNotEmpty) {
      final urls = <String>[];
      final successfulTypes = <String>[];
      
      for (int i = 0; i < _mediaFiles.length; i++) {
        try {
          final type = i < _mediaTypes.length ? _mediaTypes[i] : 'photo';
          final url = await mediaService.uploadMedia(_mediaFiles[i], type);
          if (url != null) {
            urls.add(url);
            successfulTypes.add(type);
          }
        } catch (_) {}
      }
      
      setState(() => _isUploadingMedia = false);
      
      if (urls.isEmpty && _mediaFiles.isNotEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(strings.text('report.failedUpload'))),
          );
          return; 
        }
      }
      
      final currentDraft = ref.read(reportDraftProvider);
      ref.read(reportDraftProvider.notifier).updateDraft(currentDraft.copyWith(
        mediaUrls: urls,
        mediaTypes: successfulTypes,
        localMediaPaths: _mediaFiles.map((f) => f.path).toList(),
      ));
    }
    
    if (mounted) {
      setState(() => _showMap = false);
      await Future.delayed(const Duration(milliseconds: 100));
      if (mounted) {
        context.push('/report/submit');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = ref.watch(appStringsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          strings.text('report.evidenceTitle'),
          style: GoogleFonts.inter(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Step progress indicator at 75%
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: LinearProgressIndicator(
              value: 0.75,
              color: AppTheme.primary,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
              minHeight: 5,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: TextField(
                controller: _searchController,
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: strings.text('report.searchLocation'),
                  hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                  prefixIcon: Icon(Icons.search_rounded, color: AppTheme.primary),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.my_location_rounded, color: AppTheme.primary),
                    onPressed: _initializeLocation,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
                onSubmitted: _searchLocation,
              ),
            ),
          ),
          
          // Map Section
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      if (_showMap && !_mapError && _selectedLocation != null)
                        MapLibreMap(
                          styleString: 'https://tiles.openfreemap.org/styles/liberty',
                          initialCameraPosition: CameraPosition(
                            target: _selectedLocation!,
                            zoom: 16.5,
                          ),
                          onMapCreated: (controller) {
                            _mapController = controller;
                            _updateMarker(_selectedLocation!);
                          },
                          onMapClick: (point, latLng) => _onMapTap(latLng, strings),
                          myLocationEnabled: true,
                          trackCameraPosition: false,
                          myLocationRenderMode: MyLocationRenderMode.normal,
                        )
                      else if (_selectedLocation == null && !_isLoadingLocation)
                        const Center(child: CircularProgressIndicator()),
                      if (_isLoadingLocation)
                        Container(
                          color: Colors.black.withValues(alpha: 0.15),
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Address Display Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_on_rounded, color: AppTheme.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedAddress.isEmpty ? strings.text('report.tapMap') : _selectedAddress,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF334155),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Media Selector Card
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: EvidenceMediaSelector(
                mediaFiles: _mediaFiles,
                mediaTypes: _mediaTypes,
                onCapturePhoto: _capturePhoto,
                onRecordVideo: _recordVideo,
                onRemoveMedia: _removeMedia,
                onShowPreview: _showMediaPreview,
              ),
            ),
          ),
          
          // Next / Continue Button
          Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _selectedLocation == null || _isUploadingMedia || _mediaFiles.isEmpty
                  ? null 
                  : () => _continue(strings),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: _isUploadingMedia
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(
                      strings.text('report.next'),
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 16),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
