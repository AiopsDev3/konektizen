import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:konektizen/core/services/location_service.dart';
import 'package:konektizen/features/map/citizen_map_controls.dart';
import 'package:konektizen/features/map/citizen_map_glass.dart';
import 'package:konektizen/features/map/citizen_map_style.dart';
import 'package:konektizen/theme/app_theme.dart';
import 'package:konektizen/features/map/citizen_map_layer_manager.dart';
import 'package:konektizen/features/map/citizen_map_search.dart';

class CitizenMapScreen extends StatefulWidget {
  const CitizenMapScreen({super.key});

  @override
  State<CitizenMapScreen> createState() => _CitizenMapScreenState();
}

class _CitizenMapScreenState extends State<CitizenMapScreen> {
  static const _laoagCenter = LatLng(18.1960, 120.5989);

  final _locationService = LocationService();
  MapLibreMapController? _controller;
  bool _locating = false;
  bool _showLayersMenu = false;
  bool _isSearching = false;

  bool _showFlood = false;
  bool _showLandslide = false;
  bool _showQuakes = false;
  bool _showFire = false;
  bool _showRainRadar = false;
  bool _showBarangayRain = false;
  bool _showFaults = false;
  bool _showVolcanoes = false;
  bool _showAqi = false;
  bool _showSevereWeather = false;
  bool _showLegendsPanel = false;

  final Set<String> _addedSources = {};
  bool _isUpdatingLayers = false;
  bool _needsLayerUpdate = false;

  Future<void> _updateLayerVisibility() async {
    if (_controller == null) return;
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
          showLandslide: _showLandslide,
          showQuakes: _showQuakes,
          showFire: _showFire,
          showRainRadar: _showRainRadar,
          showBarangayRain: _showBarangayRain,
          showFaults: _showFaults,
          showVolcanoes: _showVolcanoes,
          showAqi: _showAqi,
          showSevereWeather: _showSevereWeather,
        );
      } while (_needsLayerUpdate);
    } finally {
      _isUpdatingLayers = false;
    }
  }

  Future<void> _goToMyLocation() async {
    if (_locating) return;
    setState(() => _locating = true);
    try {
      final position = await _locationService.getCurrentLocation();
      final target = position == null
          ? _laoagCenter
          : LatLng(position.latitude, position.longitude);
      await _controller?.animateCamera(
        CameraUpdate.newLatLngZoom(target, position == null ? 13.6 : 16.5),
      );
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _focusLaoag() async {
    await _controller?.animateCamera(
      CameraUpdate.newCameraPosition(
        const CameraPosition(target: _laoagCenter, zoom: 13.6, tilt: 0),
      ),
    );
  }

  Future<void> _addCityLabel() async {
    await _controller?.addSymbol(
      const SymbolOptions(
        geometry: _laoagCenter,
        textField: 'Laoag City',
        textSize: 14,
      ),
    );
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
    setState(() => _showFlood = !_showFlood);
    _updateLayerVisibility();
  }

  void _toggleLandslide() {
    setState(() => _showLandslide = !_showLandslide);
    _updateLayerVisibility();
  }

  void _toggleQuakes() {
    setState(() => _showQuakes = !_showQuakes);
    _updateLayerVisibility();
  }

  void _toggleFire() {
    setState(() => _showFire = !_showFire);
    _updateLayerVisibility();
  }

  void _toggleRainRadar() {
    setState(() => _showRainRadar = !_showRainRadar);
    _updateLayerVisibility();
  }

  void _toggleBarangayRain() {
    setState(() => _showBarangayRain = !_showBarangayRain);
    _updateLayerVisibility();
  }

  void _toggleFaults() {
    setState(() => _showFaults = !_showFaults);
    _updateLayerVisibility();
  }

  void _toggleVolcanoes() {
    setState(() => _showVolcanoes = !_showVolcanoes);
    _updateLayerVisibility();
  }

  void _toggleAqi() {
    setState(() => _showAqi = !_showAqi);
    _updateLayerVisibility();
  }

  void _toggleSevereWeather() {
    setState(() => _showSevereWeather = !_showSevereWeather);
    _updateLayerVisibility();
  }

  void _toggleLegendsPanel() {
    setState(() => _showLegendsPanel = !_showLegendsPanel);
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
              zoom: 13.4,
              tilt: 0,
            ),
            cameraTargetBounds: CameraTargetBounds(
              LatLngBounds(
                southwest: const LatLng(18.10, 120.48),
                northeast: const LatLng(18.25, 120.65),
              ),
            ),
            minMaxZoomPreference: const MinMaxZoomPreference(11, 18),
            myLocationEnabled: true,
            myLocationRenderMode: MyLocationRenderMode.normal,
            compassEnabled: false,
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,
            trackCameraPosition: false,
            onMapCreated: (controller) {
              _controller = controller;
            },
            onStyleLoadedCallback: () {
              _addedSources.clear();
              _addCityLabel();
              _updateLayerVisibility();
            },
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
          Positioned(
            bottom: 24,
            left: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_showLegendsPanel)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12.0),
                    child: CitizenMapLegends(
                      showFlood: _showFlood,
                      showLandslide: _showLandslide,
                      showQuakes: _showQuakes,
                      showFire: _showFire,
                      showRainRadar: _showRainRadar,
                      showBarangayRain: _showBarangayRain,
                      showFaults: _showFaults,
                      showVolcanoes: _showVolcanoes,
                      showAqi: _showAqi,
                      showSevereWeather: _showSevereWeather,
                    ),
                  ),
                FloatingActionButton(
                  heroTag: 'legendToggleBtn',
                  mini: true,
                  onPressed: _toggleLegendsPanel,
                  backgroundColor: AppTheme.primary,
                  child: Icon(
                    _showLegendsPanel
                        ? Icons.keyboard_arrow_down
                        : Icons.legend_toggle,
                    color: Colors.white,
                  ),
                ),
              ],
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
                showQuakes: _showQuakes,
                showFire: _showFire,
                showRainRadar: _showRainRadar,
                showBarangayRain: _showBarangayRain,
                showFaults: _showFaults,
                showVolcanoes: _showVolcanoes,
                showAqi: _showAqi,
                showSevereWeather: _showSevereWeather,
                onToggleFlood: _toggleFlood,
                onToggleLandslide: _toggleLandslide,
                onToggleQuakes: _toggleQuakes,
                onToggleFire: _toggleFire,
                onToggleRainRadar: _toggleRainRadar,
                onToggleBarangayRain: _toggleBarangayRain,
                onToggleFaults: _toggleFaults,
                onToggleVolcanoes: _toggleVolcanoes,
                onToggleAqi: _toggleAqi,
                onToggleSevereWeather: _toggleSevereWeather,
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
                  icon: Icons.my_location,
                  loading: _locating,
                  onPressed: _goToMyLocation,
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
