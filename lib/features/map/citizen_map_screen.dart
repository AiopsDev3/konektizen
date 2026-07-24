import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:konektizen/features/map/c3_local_feature_details_sheet.dart';
import 'package:konektizen/features/map/c3_local_feature_query.dart';
import 'package:konektizen/features/map/c3_local_layers_service.dart';
import 'package:konektizen/features/map/c3_local_marker_overlay.dart';
import 'package:konektizen/features/map/citizen_map_controls.dart';
import 'package:konektizen/features/map/citizen_map_glass.dart';
import 'package:konektizen/features/map/citizen_map_style.dart';
import 'package:konektizen/theme/app_theme.dart';
import 'package:konektizen/features/map/citizen_map_layer_manager.dart';
import 'package:konektizen/features/map/citizen_map_search.dart';
import 'package:konektizen/features/map/citizen_map_layer_settings_sheet.dart';

class CitizenMapScreen extends StatefulWidget {
  const CitizenMapScreen({super.key});

  @override
  State<CitizenMapScreen> createState() => _CitizenMapScreenState();
}

class _CitizenMapScreenState extends State<CitizenMapScreen> {
  static const _laoagCenter = LatLng(18.1960, 120.5989);
  static const _defaultLaoagZoom = 12.75;
  static const _cityLabelSourceId = 'konektizen-city-label-source';
  static const _cityLabelLayerId = 'konektizen-city-label';

  MapLibreMapController? _controller;
  bool _showLayersMenu = false;
  bool _isSearching = false;

  bool _showFlood = false;
  bool _showLandslide = false;
  bool _showStormSurge = false;
  bool _showTyphoon = false;
  bool _showQuakes = false;
  bool _showRainRadar = false;
  bool _showFaults = false;
  bool _showAqi = false;
  bool _showLocalFacilities = false;
  bool _showLocalHazards = false;
  bool _showBarangays = false;
  bool _showLegendsPanel = false;
  int _layerOpacityPercent = 85;
  List<int> _floodReturnPeriods = [5, 25, 100];
  List<int> _stormSurgeAdvisories = [1, 2, 3, 4];

  final Set<String> _addedSources = {};
  bool _isUpdatingLayers = false;
  bool _needsLayerUpdate = false;
  bool _isOpeningC3LocalFeature = false;
  String? _layerLoadingMessage;
  List<C3LocalOverlayMarker> _c3LocalMarkers = [];
  Timer? _layerOpacityDebounce;

  Future<void> _openC3LocalFeatureAt(math.Point point) async {
    if (!_showLocalFacilities && !_showLocalHazards) return;
    if (_isOpeningC3LocalFeature) return;
    _isOpeningC3LocalFeature = true;
    try {
      final feature = await queryC3LocalFeature(
        _controller,
        point,
        includeFacilities: _showLocalFacilities,
        includeHazards: _showLocalHazards,
      );
      if (feature != null && mounted) {
        showC3LocalFeatureDetails(context, feature);
      }
    } finally {
      _isOpeningC3LocalFeature = false;
    }
  }

  Future<void> _updateLayerVisibility({String? loadingMessage}) async {
    if (_controller == null) return;
    if (loadingMessage != null && mounted) {
      setState(() => _layerLoadingMessage = loadingMessage);
    }
    if (_isUpdatingLayers) {
      _needsLayerUpdate = true;
      return;
    }
    _isUpdatingLayers = true;

    try {
      do {
        _needsLayerUpdate = false;
        final layerManager = CitizenMapLayerManager(_controller, _addedSources);
        await layerManager.updateLayers(
          showFlood: _showFlood,
          floodReturnPeriods: _floodReturnPeriods,
          showLandslide: _showLandslide,
          showStormSurge: _showStormSurge,
          stormSurgeAdvisories: _stormSurgeAdvisories,
          showTyphoon: _showTyphoon,
          showQuakes: _showQuakes,
          showRainRadar: _showRainRadar,
          showFaults: _showFaults,
          showAqi: _showAqi,
          showLocalFacilities: _showLocalFacilities,
          showLocalHazards: _showLocalHazards,
          showBarangays: _showBarangays,
          layerOpacity: _layerOpacityPercent / 100,
        );
      } while (_needsLayerUpdate);
      await _refreshC3LocalMarkers();
    } finally {
      _isUpdatingLayers = false;
      if (mounted && _layerLoadingMessage != null) {
        setState(() => _layerLoadingMessage = null);
      }
    }
  }

  Future<void> _refreshC3LocalMarkers() async {
    if (!_showLocalFacilities && !_showLocalHazards) {
      if (_c3LocalMarkers.isNotEmpty && mounted) {
        setState(() {
          _c3LocalMarkers = [];
        });
      }
      return;
    }

    try {
      final geoJson = await C3LocalLayersService.fetchGeoJson();
      final markers = buildC3LocalOverlayMarkers(
        geoJson,
        includeFacilities: _showLocalFacilities,
        includeHazards: _showLocalHazards,
      );
      if (!mounted) return;
      setState(() => _c3LocalMarkers = markers);
      debugPrint('C3 local Flutter markers: ${markers.length}');
    } catch (error) {
      debugPrint('Failed to refresh C3 local Flutter markers: $error');
      if (mounted) {
        setState(() => _c3LocalMarkers = []);
      }
    }
  }

  Future<void> _focusLaoag() async {
    await _controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(
          target: _laoagCenter,
          zoom: _defaultLaoagZoom,
          tilt: 0,
        ),
      ),
    );
  }

  Future<void> _addCityLabel() async {
    if (_controller == null || _addedSources.contains(_cityLabelSourceId)) {
      return;
    }
    await _controller?.addGeoJsonSource(_cityLabelSourceId, {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [_laoagCenter.longitude, _laoagCenter.latitude],
          },
          'properties': {'name': 'Laoag City'},
        },
      ],
    });
    await _controller?.addSymbolLayer(
      _cityLabelSourceId,
      _cityLabelLayerId,
      const SymbolLayerProperties(
        textField: [Expressions.get, 'name'],
        textSize: 14,
        textColor: '#0f172a',
        textHaloColor: '#ffffff',
        textHaloWidth: 1.4,
      ),
      enableInteraction: false,
    );
    _addedSources.add(_cityLabelSourceId);
  }

  Future<void> _handleStyleLoaded() async {
    _addedSources.clear();
    CitizenMapLayerManager.resetRuntimeState();
    await _addCityLabel();
    await _updateLayerVisibility();
  }

  void _toggleLayers() {
    setState(() => _showLayersMenu = !_showLayersMenu);
  }

  void _openSearch() {
    setState(() => _isSearching = true);
  }

  void _closeSearch() {
    setState(() => _isSearching = false);
  }

  void _toggleFlood() {
    final next = !_showFlood;
    setState(() => _showFlood = next);
    _updateLayerVisibility(
      loadingMessage: next ? 'Flood hazard layer is loading...' : null,
    );
  }

  void _toggleLandslide() {
    final next = !_showLandslide;
    setState(() => _showLandslide = next);
    _updateLayerVisibility(
      loadingMessage: next ? 'Landslide hazard layer is loading...' : null,
    );
  }

  void _toggleStormSurge() {
    final next = !_showStormSurge;
    setState(() => _showStormSurge = next);
    _updateLayerVisibility(
      loadingMessage: next ? 'Storm surge layer is loading...' : null,
    );
  }

  void _toggleTyphoon() {
    final next = !_showTyphoon;
    setState(() => _showTyphoon = next);
    _updateLayerVisibility(
      loadingMessage: next ? 'Typhoon layer is loading...' : null,
    );
  }

  void _toggleQuakes() {
    final next = !_showQuakes;
    setState(() => _showQuakes = next);
    _updateLayerVisibility(
      loadingMessage: next ? 'Earthquake layer is loading...' : null,
    );
  }

  void _toggleRainRadar() {
    final next = !_showRainRadar;
    setState(() => _showRainRadar = next);
    _updateLayerVisibility(
      loadingMessage: next ? 'Heavy rainfall layer is loading...' : null,
    );
  }

  void _toggleFaults() {
    final next = !_showFaults;
    setState(() => _showFaults = next);
    _updateLayerVisibility(
      loadingMessage: next ? 'Active faults layer is loading...' : null,
    );
  }

  void _toggleAqi() {
    final next = !_showAqi;
    setState(() => _showAqi = next);
    _updateLayerVisibility(
      loadingMessage: next ? 'Air quality layer is loading...' : null,
    );
  }

  void _toggleLocalFacilities() {
    final next = !_showLocalFacilities;
    setState(() => _showLocalFacilities = next);
    _updateLayerVisibility(
      loadingMessage: next ? 'Facilities layer is loading...' : null,
    );
  }

  void _toggleLocalHazards() {
    final next = !_showLocalHazards;
    setState(() => _showLocalHazards = next);
    _updateLayerVisibility(
      loadingMessage: next ? 'Hazard areas layer is loading...' : null,
    );
  }

  void _toggleBarangays() {
    final next = !_showBarangays;
    setState(() => _showBarangays = next);
    _updateLayerVisibility(
      loadingMessage: next ? 'Barangay boundaries are loading...' : null,
    );
  }

  void _toggleLegendsPanel() {
    setState(() => _showLegendsPanel = !_showLegendsPanel);
  }

  void _toggleHazardFromMenu(VoidCallback toggle) {
    toggle();
    if (!mounted) return;
    setState(() {
      _showLayersMenu = false;
      _showLegendsPanel = true;
    });
  }

  void _toggleFloodReturnPeriod(int period) {
    final next = List<int>.from(_floodReturnPeriods);
    next.contains(period) ? next.remove(period) : next.add(period);
    next.sort();
    setState(() => _floodReturnPeriods = next);
    _updateLayerVisibility(
      loadingMessage: _showFlood ? 'Flood hazard layer is loading...' : null,
    );
  }

  void _toggleStormSurgeAdvisory(int advisory) {
    final next = List<int>.from(_stormSurgeAdvisories);
    next.contains(advisory) ? next.remove(advisory) : next.add(advisory);
    next.sort();
    setState(() => _stormSurgeAdvisories = next);
    _updateLayerVisibility(
      loadingMessage: _showStormSurge
          ? 'Storm surge layer is loading...'
          : null,
    );
  }

  void _setLayerOpacity(int value) {
    setState(() => _layerOpacityPercent = value.clamp(0, 100));
    _layerOpacityDebounce?.cancel();
    _layerOpacityDebounce = Timer(const Duration(milliseconds: 140), () {
      _updateLayerVisibility();
    });
  }

  void _showLayerSettingsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return CitizenMapLayerSettingsSheet(
          opacityPercent: _layerOpacityPercent,
          floodReturnPeriods: _floodReturnPeriods,
          stormSurgeAdvisories: _stormSurgeAdvisories,
          showFlood: _showFlood,
          showLandslide: _showLandslide,
          showStormSurge: _showStormSurge,
          showBarangays: _showBarangays,
          onOpacityChanged: _setLayerOpacity,
          onFloodReturnPeriodToggled: _toggleFloodReturnPeriod,
          onStormSurgeAdvisoryToggled: _toggleStormSurgeAdvisory,
          onToggleFlood: _toggleFlood,
          onToggleLandslide: _toggleLandslide,
          onToggleStormSurge: _toggleStormSurge,
          onToggleBarangays: _toggleBarangays,
        );
      },
    );
  }

  @override
  void dispose() {
    _layerOpacityDebounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          MapLibreMap(
            styleString: citizenMapStyle,
            initialCameraPosition: const CameraPosition(
              target: _laoagCenter,
              zoom: _defaultLaoagZoom,
              tilt: 0,
            ),
            cameraTargetBounds: CameraTargetBounds(
              LatLngBounds(
                southwest: const LatLng(18.10, 120.48),
                northeast: const LatLng(18.25, 120.65),
              ),
            ),
            minMaxZoomPreference: const MinMaxZoomPreference(11, 18),
            compassEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            annotationOrder: const [],
            annotationConsumeTapEvents: const [AnnotationType.symbol],
            trackCameraPosition: true,
            onMapCreated: (controller) {
              setState(() => _controller = controller);
              controller.onFeatureTapped.add((point, _, _, layerId, _) {
                if (layerId.startsWith('c3-local-')) {
                  _openC3LocalFeatureAt(point);
                }
              });
            },
            onMapClick: (point, latLng) async {
              await _openC3LocalFeatureAt(point);
            },
            onStyleLoadedCallback: () {
              _handleStyleLoaded();
            },
          ),
          Positioned.fill(
            child: C3LocalMarkerOverlay(
              controller: _controller,
              markers: _c3LocalMarkers,
              onTap: (marker) =>
                  showC3LocalFeatureDetails(context, marker.feature),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: CitizenMapSearchBar(onTap: _openSearch),
              ),
            ),
          ),
          if (_layerLoadingMessage != null)
            Positioned(
              top: 92,
              left: 20,
              right: 20,
              child: _LayerLoadingBanner(message: _layerLoadingMessage!),
            ),
          if (_showLegendsPanel)
            Positioned(
              bottom: 24,
              left: 16,
              child: CitizenMapLegends(
                showFlood: _showFlood,
                floodReturnPeriods: _floodReturnPeriods,
                showLandslide: _showLandslide,
                showStormSurge: _showStormSurge,
                stormSurgeAdvisories: _stormSurgeAdvisories,
                showTyphoon: _showTyphoon,
                showQuakes: _showQuakes,
                showRainRadar: _showRainRadar,
                showFaults: _showFaults,
                showAqi: _showAqi,
                showBarangays: _showBarangays,
                layerOpacityPercent: _layerOpacityPercent,
                onToggleFloodReturnPeriod: _toggleFloodReturnPeriod,
                onToggleStormSurgeAdvisory: _toggleStormSurgeAdvisory,
                onLayerOpacityChanged: _setLayerOpacity,
              ),
            ),
          if (_showLayersMenu)
            Positioned(
              right: 76,
              top: 110,
              child: CitizenMapLayersMenu(
                onClose: _toggleLayers,
                showFlood: _showFlood,
                showLandslide: _showLandslide,
                showStormSurge: _showStormSurge,
                showTyphoon: _showTyphoon,
                showQuakes: _showQuakes,
                showRainRadar: _showRainRadar,
                showFaults: _showFaults,
                showAqi: _showAqi,
                showLocalFacilities: _showLocalFacilities,
                showLocalHazards: _showLocalHazards,
                showBarangays: _showBarangays,
                onToggleFlood: () => _toggleHazardFromMenu(_toggleFlood),
                onToggleLandslide: () =>
                    _toggleHazardFromMenu(_toggleLandslide),
                onToggleStormSurge: () =>
                    _toggleHazardFromMenu(_toggleStormSurge),
                onToggleTyphoon: () => _toggleHazardFromMenu(_toggleTyphoon),
                onToggleQuakes: () => _toggleHazardFromMenu(_toggleQuakes),
                onToggleRainRadar: () =>
                    _toggleHazardFromMenu(_toggleRainRadar),
                onToggleFaults: _toggleFaults,
                onToggleAqi: () => _toggleHazardFromMenu(_toggleAqi),
                onToggleLocalFacilities: _toggleLocalFacilities,
                onToggleLocalHazards: _toggleLocalHazards,
                onToggleBarangays: _toggleBarangays,
                onToggleSettings: _showLayerSettingsBottomSheet,
              ),
            ),
          Positioned(
            right: 16,
            top: 110,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GlassMapButton(
                  icon: Icons.layers_outlined,
                  onPressed: _toggleLayers,
                ),
                const SizedBox(height: 12),
                GlassMapButton(
                  icon: Icons.explore_outlined,
                  onPressed: _focusLaoag,
                ),
                const SizedBox(height: 12),
                GlassMapButton(
                  icon: Icons.legend_toggle,
                  onPressed: _toggleLegendsPanel,
                ),
              ],
            ),
          ),
          if (_isSearching)
            Positioned.fill(
              child: CitizenMapSearchOverlay(
                onClose: _closeSearch,
                onSelect: (lat, lng, name) {
                  _closeSearch();
                  _controller?.animateCamera(
                    CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16.5),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _LayerLoadingBanner extends StatelessWidget {
  const _LayerLoadingBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: mapGlassDecoration(14),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xff0f172a),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
