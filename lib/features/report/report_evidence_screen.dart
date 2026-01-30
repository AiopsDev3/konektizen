import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:maplibre_gl/maplibre_gl.dart'; // Replaced Google Maps
import 'package:konektizen/core/services/location_service.dart';
import 'package:konektizen/core/services/media_service.dart';
import 'package:konektizen/features/report/report_provider.dart';
import 'package:konektizen/theme/app_theme.dart';

class ReportEvidenceScreen extends ConsumerStatefulWidget {
  const ReportEvidenceScreen({super.key});

  @override
  ConsumerState<ReportEvidenceScreen> createState() => _ReportEvidenceScreenState();
}

class _ReportEvidenceScreenState extends ConsumerState<ReportEvidenceScreen> {
  MaplibreMapController? _mapController; // Updated type
  LatLng? _selectedLocation;
  String _selectedAddress = '';
  bool _isLoadingLocation = false;
  bool _mapError = false;
  final TextEditingController _searchController = TextEditingController();
  bool _showMap = true; // Control map visibility to prevent crash on navigation
  
  List<File> _mediaFiles = [];
  List<String> _mediaTypes = [];
  bool _isUploadingMedia = false;

  @override
  void initState() {
    super.initState();
    _initializeLocation();
  }

  Future<void> _initializeLocation() async {
    if (_isLoadingLocation) return; // Prevent double loading
    
    setState(() => _isLoadingLocation = true);
    
    try {
      final position = await locationService.getCurrentLocation();
      if (position != null && mounted) {
        final latLng = LatLng(position.latitude, position.longitude);
        final address = await locationService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        final city = await locationService.getCityFromCoordinates(
          position.latitude,
          position.longitude,
        );
        
        if (mounted) {
          setState(() {
            _selectedLocation = latLng;
            _selectedAddress = address;
            _isLoadingLocation = false;
          });
          
        // Update draft with location
          ref.read(reportDraftProvider.notifier).state = 
            ref.read(reportDraftProvider).copyWith(
              latitude: position.latitude,
              longitude: position.longitude,
              address: address,
              city: city,
            );
          
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(latLng, 15),
          );
          _updateMarker(latLng);
        }
      } else {
        // Use default Manila location if no GPS
        if (mounted) {
          setState(() {
            _selectedLocation = const LatLng(14.5995, 120.9842); // Manila
            _isLoadingLocation = false;
          });
        }
      }
    } catch (e) {
      print('Error initializing location: $e');
      if (mounted) {
        setState(() {
          _selectedLocation = const LatLng(14.5995, 120.9842); // Manila fallback
          _isLoadingLocation = false;
          _mapError = false; // Don't show error, just use fallback
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
        final address = coordinates['address'] as String? ?? await locationService.getAddressFromCoordinates(
          coordinates['lat']!,
          coordinates['lng']!,
        );
        final city = await locationService.getCityFromCoordinates(
          coordinates['lat']!,
          coordinates['lng']!,
        );
        
        if (mounted) {
          setState(() {
            _selectedLocation = latLng;
            _selectedAddress = address;
            _isLoadingLocation = false;
          });
          
          // Update draft
          ref.read(reportDraftProvider.notifier).state = 
            ref.read(reportDraftProvider).copyWith(
              latitude: coordinates['lat']!,
              longitude: coordinates['lng']!,
              address: address,
              city: city,
            );
          
          _mapController?.animateCamera(
            CameraUpdate.newLatLngZoom(latLng, 18.0),
          );
          _updateMarker(latLng);
        }
      } else {
        if (mounted) {
          setState(() => _isLoadingLocation = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hindi mahanap ang lokasyon')),
          );
        }
      }
    } catch (e) {
      print('Search location error: $e');
      if (mounted) {
        setState(() => _isLoadingLocation = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error sa paghahanap ng lokasyon')),
        );
      }
    }
  }

  Future<void> _updateMarker(LatLng position) async {
    if (_mapController == null) return;
    
    // Clear previous circles
    await _mapController!.clearCircles();
    
    // Add new circle marker
    await _mapController!.addCircle(
      CircleOptions(
        geometry: position,
        circleColor: '#FF0000', // Red
        circleRadius: 10,
        circleStrokeWidth: 2,
        circleStrokeColor: '#FFFFFF',
      ),
    );
  }

  Future<void> _onMapTap(LatLng location) async {
    // Automatic pin-pointing is active to ensure reliability.
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Awtomatikong nakatutok ang lokasyon sa iyong GPS para sa mas tumpak na ulat.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showMediaPreview(String path, String type) {
    if (type == 'video') {
       return;
    }
    
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(0),
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
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
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

  Future<void> _pickFromGallery() async {
    final file = await mediaService.pickFromGallery();
    if (file != null) {
      setState(() {
        _mediaFiles.add(file);
        _mediaTypes.add('photo');
      });
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _mediaFiles.removeAt(index);
      _mediaTypes.removeAt(index);
    });
  }

  Future<void> _continue() async {
    if (_mediaFiles.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kailangan ng litrato o video bilang ebidensiya.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isUploadingMedia = true);

    // Capture reporter's current location for validation
    try {
      final currentPos = await locationService.getCurrentLocation();
      if (currentPos != null) {
        ref.read(reportDraftProvider.notifier).state = 
          ref.read(reportDraftProvider).copyWith(
            reporterLatitude: currentPos.latitude,
            reporterLongitude: currentPos.longitude,
          );
      }
    } catch (e) {
      print('Error capturing reporter location: $e');
    }

    // Upload media files and get URLs
    if (_mediaFiles.isNotEmpty) {
      
      final urls = <String>[];
      final successfulTypes = <String>[];
      
      for (int i = 0; i < _mediaFiles.length; i++) {
        try {
          // Use 'photo' as default if index out of range (safety)
          final type = i < _mediaTypes.length ? _mediaTypes[i] : 'photo';
          
          final url = await mediaService.uploadMedia(_mediaFiles[i], type);
          if (url != null) {
            urls.add(url);
            successfulTypes.add(type);
          } else {
             print('Failed to upload media at index $i');
          }
        } catch (e) {
          print('Exception uploading media at index $i: $e');
        }
      }
      
      setState(() => _isUploadingMedia = false);
      
      if (urls.isEmpty && _mediaFiles.isNotEmpty) {
          // If all uploads failed, don't proceed to empty draft? 
          // Or just warn? For now let's proceed but maybe show snackbar
          if (mounted) {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text('Failed to upload evidence. Please check connection and try again.')),
             );
             return; 
          }
      }
      
      // Update draft with media URLs
      ref.read(reportDraftProvider.notifier).state = 
        ref.read(reportDraftProvider).copyWith(
          mediaUrls: urls,
          mediaTypes: successfulTypes,
          localMediaPaths: _mediaFiles.map((f) => f.path).toList(),
        );
    }
    
    if (mounted) {
      // Unmount map before navigating to prevent GL context crash on Android
      setState(() => _showMap = false);
      // Wait a frame to allow map to unmount
      await Future.delayed(const Duration(milliseconds: 100));
      
      if (mounted) {
        context.push('/report/submit');
        // Restore map if we come back (e.g. back button)
        // Future.microtask(() => setState(() => _showMap = true));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ebidensya at Lokasyon'),
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Maghanap ng lokasyon (e.g., Quezon City)',
                prefixIcon: const Icon(Icons.search, color: AppTheme.primary),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.my_location, color: AppTheme.primary),
                  onPressed: _initializeLocation,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppTheme.primary, width: 2),
                ),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
              onSubmitted: _searchLocation,
            ),
          ),
          
          // Map Section
          Expanded(
            flex: 2,
            child: Stack(
              children: [
                if (_showMap) // Only show map if allowed
                   if (_mapError || _selectedLocation == null)
                     // Fallback UI when map fails or not ready
                     Container(
                       color: Colors.grey.shade200,
                       child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.map_outlined, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          if (_selectedLocation != null) ...[
                            const Text('Map unavailable', style: TextStyle(fontSize: 16)),
                            const SizedBox(height: 8),
                            Text(
                              'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}',
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                            Text(
                              'Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                              style: const TextStyle(fontFamily: 'monospace'),
                            ),
                          ] else
                            const CircularProgressIndicator(),
                        ],
                      ),
                    ),
                  )
                else
                  // MapLibre Map Implementation
                  MaplibreMap(
                    styleString: 'https://tiles.openfreemap.org/styles/liberty',
                    initialCameraPosition: CameraPosition(
                      target: _selectedLocation!,
                      zoom: 18.2,
                    ),
                    onMapCreated: (controller) {
                      _mapController = controller;
                      // Determine if we need to add a marker initially
                      if (_selectedLocation != null) {
                        _updateMarker(_selectedLocation!);
                      }
                    },
                    onMapClick: (point, latLng) {
                      _onMapTap(latLng);
                    },
                    myLocationEnabled: true,
                    trackCameraPosition: false, // Lock camera to prevent manual drift
                    myLocationRenderMode: MyLocationRenderMode.normal,
                  ),
                if (_isLoadingLocation)
                  Container(
                    color: Colors.black26,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
              ],
            ),
          ),
          
          // Address Display
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade100,
            child: Row(
              children: [
                const Icon(Icons.location_on, color: AppTheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedAddress.isEmpty ? 'I-tap ang mapa para pumili ng lokasyon' : _selectedAddress,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          
          // Media Section
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ebidensya',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  
                  // Media Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _capturePhoto,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Larawan'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: const BorderSide(color: AppTheme.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _recordVideo,
                          icon: const Icon(Icons.videocam),
                          label: const Text('Video'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.primary,
                            side: const BorderSide(color: AppTheme.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Media Thumbnails
                  if (_mediaFiles.isNotEmpty)
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _mediaFiles.length,
                        itemBuilder: (context, index) {
                          return Stack(
                            children: [
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                child: InkWell(
                                  onTap: () => _showMediaPreview(_mediaFiles[index].path, _mediaTypes[index]),
                                  child: Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      image: _mediaTypes[index] == 'photo'
                                          ? DecorationImage(
                                              image: FileImage(_mediaFiles[index]),
                                              fit: BoxFit.cover,
                                            )
                                          : null,
                                      color: Colors.grey.shade300,
                                    ),
                                    child: _mediaTypes[index] == 'video'
                                        ? const Icon(Icons.play_circle_outline, size: 40)
                                        : null,
                                  ),
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 12,
                                child: GestureDetector(
                                  onTap: () => _removeMedia(index),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          
          // Continue Button
          Container(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _selectedLocation == null || _isUploadingMedia || _mediaFiles.isEmpty
                    ? null 
                    : _continue,
                child: _isUploadingMedia
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Magpatuloy'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
