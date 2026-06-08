import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

class C3LocalOverlayMarker {
  const C3LocalOverlayMarker({
    required this.id,
    required this.coordinate,
    required this.feature,
    required this.kind,
    required this.type,
    required this.severity,
  });

  final String id;
  final LatLng coordinate;
  final Map<String, dynamic> feature;
  final String kind;
  final String type;
  final String severity;

  bool get isFacility => kind == 'facility';
}

List<C3LocalOverlayMarker> buildC3LocalOverlayMarkers(
  Map<String, dynamic> geoJson, {
  required bool includeFacilities,
  required bool includeHazards,
}) {
  final markers = <C3LocalOverlayMarker>[];
  final seen = <String>{};

  for (final feature in (geoJson['features'] as List<dynamic>? ?? [])) {
    if (feature is! Map) continue;
    final normalized = _stringKeyedMap(feature);
    final properties = Map<String, dynamic>.from(
      normalized['properties'] as Map? ?? {},
    );
    final kind = properties['kind']?.toString() ?? '';
    if (kind == 'facility' && !includeFacilities) continue;
    if (kind == 'hazard' && !includeHazards) continue;
    if (kind != 'facility' && kind != 'hazard') continue;

    final coordinate = _featureCoordinate(normalized);
    if (coordinate == null) continue;

    final id = _featureId(normalized, properties, coordinate);
    if (!seen.add(id)) continue;

    markers.add(
      C3LocalOverlayMarker(
        id: id,
        coordinate: coordinate,
        feature: normalized,
        kind: kind,
        type: properties['type']?.toString() ?? '',
        severity: properties['severity']?.toString() ?? '',
      ),
    );
  }

  return markers;
}

class C3LocalMarkerOverlay extends StatefulWidget {
  const C3LocalMarkerOverlay({
    super.key,
    required this.controller,
    required this.markers,
    required this.onTap,
  });

  final MapLibreMapController? controller;
  final List<C3LocalOverlayMarker> markers;
  final ValueChanged<C3LocalOverlayMarker> onTap;

  @override
  State<C3LocalMarkerOverlay> createState() => _C3LocalMarkerOverlayState();
}

class _C3LocalMarkerOverlayState extends State<C3LocalMarkerOverlay> {
  static const _cameraMoveUpdateInterval = Duration(milliseconds: 96);
  static const _positionChangeThreshold = 0.75;

  MapLibreMapController? _controller;
  Map<String, math.Point<num>> _positions = {};
  bool _isUpdatingPositions = false;
  bool _needsPositionUpdate = false;
  int _positionRequest = 0;
  DateTime _lastPositionUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _attachController(widget.controller);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _updatePositions(force: true);
    });
  }

  @override
  void didUpdateWidget(covariant C3LocalMarkerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _attachController(widget.controller);
    }
    if (oldWidget.markers != widget.markers) {
      _prunePositions();
      _updatePositions(force: true);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _attachController(MapLibreMapController? controller) {
    if (_controller == controller) return;
    _controller?.removeListener(_handleControllerChanged);
    _controller = controller;
    _controller?.addListener(_handleControllerChanged);
  }

  void _handleControllerChanged() {
    final controller = _controller;
    if (controller == null) return;
    _updatePositions(force: !controller.isCameraMoving);
  }

  void _prunePositions() {
    final ids = widget.markers.map((marker) => marker.id).toSet();
    final next = Map<String, math.Point<num>>.from(_positions)
      ..removeWhere((id, _) => !ids.contains(id));
    if (next.length == _positions.length) return;
    setState(() => _positions = next);
  }

  Future<void> _updatePositions({bool force = false}) async {
    final controller = _controller;
    if (controller == null || widget.markers.isEmpty) {
      if (_positions.isNotEmpty && mounted) setState(() => _positions = {});
      return;
    }
    if (_isUpdatingPositions) {
      _needsPositionUpdate = true;
      return;
    }

    final now = DateTime.now();
    if (!force &&
        now.difference(_lastPositionUpdate) < _cameraMoveUpdateInterval) {
      return;
    }
    _lastPositionUpdate = now;
    _isUpdatingPositions = true;
    final request = ++_positionRequest;

    try {
      final markers = List<C3LocalOverlayMarker>.from(widget.markers);
      final points = await controller.toScreenLocationBatch(
        markers.map((marker) => marker.coordinate),
      );
      if (!mounted ||
          request != _positionRequest ||
          points.length != markers.length) {
        return;
      }

      final next = <String, math.Point<num>>{};
      for (var i = 0; i < markers.length; i++) {
        next[markers[i].id] = points[i];
      }
      if (_positionsAreClose(_positions, next)) return;
      setState(() => _positions = next);
    } catch (error) {
      debugPrint('Failed to update C3 local marker positions: $error');
    } finally {
      _isUpdatingPositions = false;
      if (_needsPositionUpdate && mounted) {
        _needsPositionUpdate = false;
        _updatePositions(force: true);
      }
    }
  }

  bool _positionsAreClose(
    Map<String, math.Point<num>> current,
    Map<String, math.Point<num>> next,
  ) {
    if (current.length != next.length) return false;
    for (final entry in next.entries) {
      final previous = current[entry.key];
      if (previous == null) return false;
      final dx = (previous.x - entry.value.x).abs();
      final dy = (previous.y - entry.value.y).abs();
      if (dx > _positionChangeThreshold || dy > _positionChangeThreshold) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.markers.isEmpty || _positions.isEmpty) {
      return const SizedBox.shrink();
    }

    final ratio = _screenCoordinateRatio(context);
    final viewportSize = MediaQuery.sizeOf(context);
    return SizedBox.expand(
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (final marker in widget.markers)
            if (_positions[marker.id] != null)
              _PositionedMarker(
                marker: marker,
                position: _positions[marker.id]!,
                ratio: ratio,
                viewportSize: viewportSize,
                onTap: widget.onTap,
              ),
        ],
      ),
    );
  }
}

class _PositionedMarker extends StatelessWidget {
  const _PositionedMarker({
    required this.marker,
    required this.position,
    required this.ratio,
    required this.viewportSize,
    required this.onTap,
  });

  static const _hitSize = 72.0;
  static const _visualSize = 38.0;
  final C3LocalOverlayMarker marker;
  final math.Point<num> position;
  final double ratio;
  final Size viewportSize;
  final ValueChanged<C3LocalOverlayMarker> onTap;

  @override
  Widget build(BuildContext context) {
    final left = position.x.toDouble() / ratio - (_hitSize / 2);
    final top = position.y.toDouble() / ratio - (_hitSize / 2);
    if (left < -_hitSize ||
        top < -_hitSize ||
        left > viewportSize.width + _hitSize ||
        top > viewportSize.height + _hitSize) {
      return const SizedBox.shrink();
    }

    final color = marker.isFacility
        ? const Color(0xff2f80ed)
        : _hazardColor(marker.severity);
    return Positioned(
      left: left,
      top: top,
      width: _hitSize,
      height: _hitSize,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerUp: (_) => onTap(marker),
        child: Center(
          child: RepaintBoundary(
            child: SizedBox(
              width: _visualSize,
              height: _visualSize,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xff0f172a),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color,
                    ),
                    child: Icon(
                      _markerIcon(marker),
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

IconData _markerIcon(C3LocalOverlayMarker marker) {
  final type = marker.type.toLowerCase();
  if (marker.isFacility) {
    if (type.contains('hospital') ||
        type.contains('health') ||
        type.contains('medical')) {
      return Icons.local_hospital;
    }
    if (type.contains('fire')) return Icons.local_fire_department;
    if (type.contains('police')) return Icons.security;
    if (type.contains('evac') || type.contains('shelter')) return Icons.home;
    if (type.contains('command') ||
        type.contains('operations') ||
        type.contains('municipal') ||
        type.contains('city hall')) {
      return Icons.account_balance;
    }
    if (type.contains('warehouse') || type.contains('storage')) {
      return Icons.store;
    }
    if (type.contains('water')) return Icons.opacity;
    return Icons.location_city;
  }

  if (type.contains('flood') || type.contains('storm')) return Icons.opacity;
  if (type.contains('dengue') || type.contains('mosquito')) {
    return Icons.bug_report;
  }
  if (type.contains('landslide')) return Icons.terrain;
  if (type.contains('fire')) return Icons.local_fire_department;
  if (type.contains('earthquake') || type.contains('quake')) {
    return Icons.vibration;
  }
  if (type.contains('road') || type.contains('closure')) return Icons.block;
  return Icons.warning_amber;
}

Color _hazardColor(String severity) {
  final normalized = severity.toLowerCase().trim();
  if (normalized == 'danger' ||
      normalized == 'high' ||
      normalized == 'very high' ||
      normalized == 'critical') {
    return const Color(0xffef4444);
  }
  return const Color(0xfff59e0b);
}

LatLng? _featureCoordinate(Map<String, dynamic> feature) {
  final properties = Map<String, dynamic>.from(
    feature['properties'] as Map? ?? {},
  );
  final lat =
      _toDouble(properties['centerLat']) ??
      _toDouble(properties['latitude']) ??
      _toDouble(properties['lat']);
  final lng =
      _toDouble(properties['centerLng']) ??
      _toDouble(properties['longitude']) ??
      _toDouble(properties['lng']);
  if (lat != null && lng != null) return LatLng(lat, lng);

  final geometry = feature['geometry'];
  if (geometry is! Map) return null;
  final type = geometry['type']?.toString();
  final coordinates = geometry['coordinates'];
  if (type == 'Point' && coordinates is List && coordinates.length >= 2) {
    final pointLng = _toDouble(coordinates[0]);
    final pointLat = _toDouble(coordinates[1]);
    if (pointLat != null && pointLng != null) return LatLng(pointLat, pointLng);
  }

  final bounds = _coordinateBounds(coordinates);
  if (bounds == null) return null;
  return LatLng(
    (bounds.minLat + bounds.maxLat) / 2,
    (bounds.minLng + bounds.maxLng) / 2,
  );
}

({double minLng, double minLat, double maxLng, double maxLat})?
_coordinateBounds(dynamic coordinates) {
  final pairs = <(double, double)>[];
  void collect(dynamic value) {
    if (value is! List || value.isEmpty) return;
    if (value.length >= 2 && value[0] is num && value[1] is num) {
      pairs.add(((value[0] as num).toDouble(), (value[1] as num).toDouble()));
      return;
    }
    for (final child in value) {
      collect(child);
    }
  }

  collect(coordinates);
  if (pairs.isEmpty) return null;
  var minLng = pairs.first.$1;
  var maxLng = pairs.first.$1;
  var minLat = pairs.first.$2;
  var maxLat = pairs.first.$2;
  for (final pair in pairs.skip(1)) {
    if (pair.$1 < minLng) minLng = pair.$1;
    if (pair.$1 > maxLng) maxLng = pair.$1;
    if (pair.$2 < minLat) minLat = pair.$2;
    if (pair.$2 > maxLat) maxLat = pair.$2;
  }
  return (minLng: minLng, minLat: minLat, maxLng: maxLng, maxLat: maxLat);
}

String _featureId(
  Map<String, dynamic> feature,
  Map<String, dynamic> properties,
  LatLng coordinate,
) {
  final id = properties['id']?.toString().trim();
  if (id != null && id.isNotEmpty) return '${properties['kind']}:$id';
  return [
    properties['kind'],
    properties['type'],
    properties['name'],
    coordinate.latitude.toStringAsFixed(6),
    coordinate.longitude.toStringAsFixed(6),
    feature['geometry'],
  ].join('|');
}

Map<String, dynamic> _stringKeyedMap(Map source) {
  return source.map((key, value) {
    if (value is Map) return MapEntry(key.toString(), _stringKeyedMap(value));
    if (value is List) {
      return MapEntry(
        key.toString(),
        value
            .map((item) => item is Map ? _stringKeyedMap(item) : item)
            .toList(),
      );
    }
    return MapEntry(key.toString(), value);
  });
}

double _screenCoordinateRatio(BuildContext context) {
  if (kIsWeb || defaultTargetPlatform == TargetPlatform.iOS) return 1;
  return MediaQuery.of(context).devicePixelRatio;
}

double? _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value == null) return null;
  return double.tryParse(value.toString());
}
