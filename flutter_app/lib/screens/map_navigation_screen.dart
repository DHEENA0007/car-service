import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/theme.dart';
import '../services/api_service.dart';

class MapNavigationScreen extends StatefulWidget {
  final Map<String, dynamic> centerData;
  const MapNavigationScreen({super.key, required this.centerData});

  @override
  State<MapNavigationScreen> createState() => _MapNavigationScreenState();
}

class _MapNavigationScreenState extends State<MapNavigationScreen> {
  final MapController _mapController = MapController();

  Map<String, dynamic> _route = {};
  List<LatLng> _routePoints = [];
  bool _loadingRoute = true;
  String? _error;

  double? _userLat;
  double? _userLng;
  bool _showSteps = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    setState(() { _loadingRoute = true; _error = null; });

    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      _userLat = pos.latitude;
      _userLng = pos.longitude;
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) { _userLat = last.latitude; _userLng = last.longitude; }
    }

    if (_userLat == null) {
      if (mounted) setState(() { _loadingRoute = false; _error = 'GPS unavailable.'; });
      return;
    }

    final eloc   = widget.centerData['place_id'] ?? '';
    final dstLat = (widget.centerData['latitude']  as num?)?.toDouble();
    final dstLng = (widget.centerData['longitude'] as num?)?.toDouble();

    final result = await ApiService.getRoute(
      originLat: _userLat!,
      originLng: _userLng!,
      eloc: eloc.isNotEmpty ? eloc : null,
      destLat: dstLat,
      destLng: dstLng,
    );

    if (mounted) {
      final polyline = result['overview_polyline'] as String? ?? '';
      setState(() {
        _route = result;
        _routePoints = polyline.isNotEmpty ? _decodePolyline(polyline) : [];
        _loadingRoute = false;
        if (result.isEmpty) _error = 'Could not calculate route.';
      });
      if (result.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          Future.delayed(const Duration(milliseconds: 300), _fitBounds);
        });
      }
    }
  }

  void _fitBounds() {
    // Use all route points for a tight fit; fall back to user + destination
    final points = _routePoints.isNotEmpty
        ? _routePoints
        : [
            if (_userLat != null) LatLng(_userLat!, _userLng!),
            if (widget.centerData['latitude'] != null)
              LatLng(
                (widget.centerData['latitude'] as num).toDouble(),
                (widget.centerData['longitude'] as num).toDouble(),
              ),
          ];

    if (points.length < 2) return;

    final lats = points.map((p) => p.latitude);
    final lngs = points.map((p) => p.longitude);
    final minLat = lats.reduce((a, b) => a < b ? a : b);
    final maxLat = lats.reduce((a, b) => a > b ? a : b);
    final minLng = lngs.reduce((a, b) => a < b ? a : b);
    final maxLng = lngs.reduce((a, b) => a > b ? a : b);

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: LatLngBounds(
          LatLng(minLat - 0.002, minLng - 0.002),
          LatLng(maxLat + 0.002, maxLng + 0.002),
        ),
        padding: const EdgeInsets.fromLTRB(32, 60, 32, 220),
      ),
    );
  }

  // ── Navigation control ──────────────────────────────────────────────────────

  Future<void> _startNavigation() async {
    final lat = (_route['destination_lat'] ?? widget.centerData['latitude']) as num?;
    final lng = (_route['destination_lng'] ?? widget.centerData['longitude']) as num?;
    if (lat == null || lng == null) return;

    // Try Google Maps app first, then web fallback
    final googleMapsApp = Uri.parse(
        'google.navigation:q=$lat,$lng&mode=d');
    final googleMapsWeb = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');

    if (await canLaunchUrl(googleMapsApp)) {
      await launchUrl(googleMapsApp, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(googleMapsWeb, mode: LaunchMode.externalApplication);
    }
  }


  // ── Polyline decoder ────────────────────────────────────────────────────────

  List<LatLng> _decodePolyline(String encoded) {
    final result = <LatLng>[];
    int index = 0, lat = 0, lng = 0;
    while (index < encoded.length) {
      int b, shift = 0, result_ = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result_ |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lat += (result_ & 1) != 0 ? ~(result_ >> 1) : result_ >> 1;

      shift = 0; result_ = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result_ |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      lng += (result_ & 1) != 0 ? ~(result_ >> 1) : result_ >> 1;

      result.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return result;
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final name     = widget.centerData['name'] ?? 'Service Center';
    final distText = _route['distance_text'] as String? ?? '';
    final durText  = _route['duration_text']  as String? ?? '';
    final steps    = (_route['steps'] as List<dynamic>? ?? []).cast<Map<String, dynamic>>();

    final destLat = (_route['destination_lat'] ?? widget.centerData['latitude']) as num?;
    final destLng = (_route['destination_lng'] ?? widget.centerData['longitude']) as num?;

    final initLat = destLat?.toDouble() ?? _userLat ?? 20.5937;
    final initLng = destLng?.toDouble() ?? _userLng ?? 78.9629;

    final markers = _buildMarkers(destLat, destLng, name);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.cardBg,
        elevation: 0,
        title: Text(name,
            style: const TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 16),
            overflow: TextOverflow.ellipsis),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_loadingRoute)
            IconButton(
              icon: const Icon(Icons.refresh, color: AppTheme.textMuted),
              onPressed: _init,
            ),
        ],
      ),
      body: Stack(
        children: [
          // ── Map ──────────────────────────────────────────────────────────────
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: LatLng(initLat, initLng),
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.carservice.car_service_app',
              ),
              if (_routePoints.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(
                    points: _routePoints,
                    color: const Color(0xFF8B5CF6), // Violet polyline
                    strokeWidth: 5.0,
                  ),
                ]),
              if (markers.isNotEmpty) MarkerLayer(markers: markers),
            ],
          ),

          // ── Loading overlay ──────────────────────────────────────────────────
          if (_loadingRoute)
            Container(
              color: Colors.black.withValues(alpha: 0.45),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: AppTheme.primaryColor),
                    SizedBox(height: 14),
                    Text('Calculating route...',
                        style: TextStyle(color: Colors.white, fontSize: 14)),
                  ],
                ),
              ),
            ),

          // ── Error banner ─────────────────────────────────────────────────────
          if (_error != null && !_loadingRoute)
            Positioned(
              top: 12, left: 16, right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_error!,
                      style: const TextStyle(color: Colors.white, fontSize: 13))),
                ]),
              ).animate().fadeIn(),
            ),

          // ── Route summary panel ───────────────────────────────────────────────
          if (!_loadingRoute && _route.isNotEmpty)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _buildBottomPanel(distText, durText, steps),
            ),
        ],
      ),
    );
  }

  List<Marker> _buildMarkers(num? destLat, num? destLng, String name) {
    final markers = <Marker>[];
    if (destLat != null && destLng != null) {
      markers.add(Marker(
        point: LatLng(destLat.toDouble(), destLng.toDouble()),
        width: 120, height: 56,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.location_on, color: AppTheme.accentColor, size: 32),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: Colors.black87, borderRadius: BorderRadius.circular(6)),
              child: Text(name,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                  overflow: TextOverflow.ellipsis, maxLines: 1),
            ),
          ],
        ),
      ));
    }
    if (_userLat != null && _userLng != null) {
      markers.add(Marker(
        point: LatLng(_userLat!, _userLng!),
        width: 40, height: 40,
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: const Icon(Icons.navigation, color: Colors.white, size: 20),
        ),
      ));
    }
    return markers;
  }

  // ── Bottom route summary panel ──────────────────────────────────────────────

  Widget _buildBottomPanel(String distText, String durText, List<Map<String, dynamic>> steps) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16, offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textMuted.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Summary row
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Row(children: [
              Expanded(
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.directions_car, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(distText,
                        style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700, fontSize: 20)),
                    Text(durText,
                        style: const TextStyle(color: AppTheme.textMuted, fontSize: 13)),
                  ]),
                ]),
              ),
              GestureDetector(
                onTap: () => setState(() => _showSteps = !_showSteps),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                      _showSteps ? 'Hide' : '${steps.length} steps',
                      style: const TextStyle(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _showSteps ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                      color: AppTheme.primaryColor, size: 18,
                    ),
                  ]),
                ),
              ),
            ]),
          ),

          // Steps
          if (_showSteps)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.3),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                shrinkWrap: true,
                itemCount: steps.length,
                itemBuilder: (_, i) {
                  final step = steps[i];
                  return _buildStepTile(
                    step, i, i == 0, i == steps.length - 1,
                    step['maneuver_type'] as String? ?? '',
                    step['maneuver_modifier'] as String? ?? '',
                  ).animate().fadeIn(delay: (30 * i).ms, duration: 200.ms);
                },
              ),
            ),

          // Start Navigation button
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + MediaQuery.of(context).padding.bottom),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _startNavigation,
                icon: const Icon(Icons.navigation, color: Colors.white, size: 22),
                label: const Text('Start Navigation',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepTile(Map<String, dynamic> step, int idx,
      bool isFirst, bool isLast, String mtype, String mmod) {
    final instruction = step['instruction'] as String? ?? 'Continue';
    final distText    = step['distance_text'] as String? ?? '';
    final color = isFirst
        ? AppTheme.primaryColor
        : isLast ? AppTheme.success : AppTheme.accentColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isLast ? AppTheme.success.withValues(alpha: 0.3) : Colors.transparent),
      ),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
          child: Icon(_maneuverIcon(mtype, mmod), color: color, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(instruction,
              style: TextStyle(
                color: isLast ? AppTheme.success : AppTheme.textPrimary,
                fontWeight: isFirst || isLast ? FontWeight.w600 : FontWeight.w400,
                fontSize: 13,
              )),
        ),
        if (distText.isNotEmpty && distText != '0 m')
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Text(distText,
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w600, fontSize: 11)),
          ),
      ]),
    );
  }

  IconData _maneuverIcon(String type, String modifier) {
    if (type == 'depart')   return Icons.my_location;
    if (type == 'arrive')   return Icons.flag_rounded;
    if (type == 'merge')    return Icons.merge;
    if (type == 'on ramp')  return Icons.call_made;
    if (type == 'off ramp') return Icons.call_received;
    if (type == 'rotary' || type == 'roundabout') return Icons.roundabout_left;
    if (type == 'fork' || type == 'end of road') {
      return modifier.contains('left') ? Icons.fork_left : Icons.fork_right;
    }
    if (type == 'turn' || type == 'new name') {
      if (modifier == 'uturn')        return Icons.u_turn_left;
      if (modifier == 'slight left')  return Icons.turn_slight_left;
      if (modifier == 'slight right') return Icons.turn_slight_right;
      if (modifier == 'sharp left')   return Icons.turn_sharp_left;
      if (modifier == 'sharp right')  return Icons.turn_sharp_right;
      if (modifier == 'left')         return Icons.turn_left;
      if (modifier == 'right')        return Icons.turn_right;
    }
    return Icons.straight;
  }
}
