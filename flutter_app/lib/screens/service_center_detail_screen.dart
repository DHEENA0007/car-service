import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/theme.dart';
import '../services/api_service.dart';
import 'map_navigation_screen.dart';

class ServiceCenterDetailScreen extends StatefulWidget {
  final Map<String, dynamic> centerData;

  const ServiceCenterDetailScreen({super.key, required this.centerData});

  @override
  State<ServiceCenterDetailScreen> createState() =>
      _ServiceCenterDetailScreenState();
}

class _ServiceCenterDetailScreenState
    extends State<ServiceCenterDetailScreen> {
  String _phone = '';
  bool _loadingPhone = false;

  @override
  void initState() {
    super.initState();
    _phone = widget.centerData['phone_number'] ?? '';
    if (_phone.isEmpty) {
      final eloc = widget.centerData['place_id'] ?? '';
      if (eloc.isNotEmpty) _fetchPlaceDetail(eloc);
    }
  }

  Future<void> _fetchPlaceDetail(String eloc) async {
    setState(() => _loadingPhone = true);
    try {
      final result = await ApiService.getPlaceDetail(eloc);
      final detail = result['data'] as Map<String, dynamic>? ?? {};
      setState(() {
        _phone = detail['phone_number'] ?? '';
      });
    } catch (_) {}
    setState(() => _loadingPhone = false);
  }

  Future<void> _makeCall() async {
    if (_phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: _phone);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _openMaps() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapNavigationScreen(centerData: widget.centerData),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final centerData = widget.centerData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Service Center'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Card
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppTheme.cardGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: AppTheme.surfaceBg),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppTheme.glowShadow,
                      ),
                      child: const Icon(
                        Icons.car_repair,
                        size: 40,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      centerData['name'] ?? 'Service Center',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    // Mappls verified + distance row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1565C0).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: const Color(0xFF1565C0)
                                    .withValues(alpha: 0.3)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.verified,
                                  size: 13, color: Color(0xFF1565C0)),
                              SizedBox(width: 5),
                              Text(
                                'Verified Location',
                                style: TextStyle(
                                  color: Color(0xFF1565C0),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if ((centerData['distance'] ?? '').isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.directions_car,
                              size: 15, color: AppTheme.accentColor),
                          const SizedBox(width: 5),
                          Text(
                            centerData['distance'] as String,
                            style: const TextStyle(
                              color: AppTheme.accentColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .slideY(begin: -0.1, end: 0),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      Icons.call,
                      _loadingPhone ? 'Loading...' : (_phone.isEmpty ? 'No Phone' : 'Call Now'),
                      AppTheme.success,
                      _phone.isEmpty ? null : _makeCall,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildActionButton(
                      Icons.navigation,
                      'Navigate',
                      AppTheme.primaryColor,
                      _openMaps,
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 20),

              // Mappls Static Map
              if (centerData['latitude'] != null && centerData['longitude'] != null)
                _buildStaticMap(
                  centerData['latitude'] as num,
                  centerData['longitude'] as num,
                ).animate().fadeIn(delay: 250.ms),

              if (centerData['latitude'] != null && centerData['longitude'] != null)
                const SizedBox(height: 20),

              // Details
              _buildDetailSection(
                Icons.location_on,
                'Address',
                centerData['address'] ?? 'N/A',
                AppTheme.error,
              ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.1, end: 0),

              const SizedBox(height: 12),

              _buildDetailSection(
                Icons.phone,
                'Phone Number',
                _loadingPhone
                    ? 'Fetching...'
                    : (_phone.isEmpty ? 'Not available' : _phone),
                AppTheme.success,
              ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1, end: 0),

              const SizedBox(height: 12),

              _buildDetailSection(
                Icons.near_me,
                'Distance',
                centerData['distance'] ?? 'N/A',
                AppTheme.accentColor,
              ).animate().fadeIn(delay: 500.ms).slideX(begin: 0.1, end: 0),

              const SizedBox(height: 12),

              _buildDetailSection(
                Icons.access_time,
                'Opening Hours',
                centerData['opening_hours'] ?? 'N/A',
                AppTheme.warning,
              ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.1, end: 0),

              const SizedBox(height: 12),

              _buildDetailSection(
                Icons.build,
                'Services Offered',
                centerData['services_offered'] ?? 'N/A',
                AppTheme.primaryColor,
              ).animate().fadeIn(delay: 700.ms).slideX(begin: 0.1, end: 0),

              const SizedBox(height: 28),

              // Call CTA
              SizedBox(
                height: 56,
                child: ElevatedButton.icon(
                  onPressed: _phone.isEmpty ? null : _makeCall,
                  icon: const Icon(Icons.call, color: Colors.white),
                  label: const Text(
                    'Call Service Center',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.1, end: 0),

              const SizedBox(height: 12),

              // Navigate Button
              SizedBox(
                height: 56,
                child: OutlinedButton.icon(
                  onPressed: _openMaps,
                  icon: const Icon(Icons.navigation, color: AppTheme.primaryColor),
                  label: const Text(
                    'Open in Maps',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 1000.ms),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStaticMap(num lat, num lng) {
    return GestureDetector(
      onTap: _openMaps,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        child: SizedBox(
          height: 180,
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(lat.toDouble(), lng.toDouble()),
                  initialZoom: 15,
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.none,
                  ),
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.carservice.car_service_app',
                  ),
                  MarkerLayer(markers: [
                    Marker(
                      point: LatLng(lat.toDouble(), lng.toDouble()),
                      child: const Icon(Icons.location_on,
                          color: Color(0xFFE53935), size: 36),
                    ),
                  ]),
                ],
              ),
              Positioned(
                bottom: 10,
                right: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.navigation, color: Colors.white, size: 14),
                      SizedBox(width: 4),
                      Text('Open Maps',
                          style: TextStyle(color: Colors.white, fontSize: 12)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton(
      IconData icon, String label, Color color, VoidCallback? onTap) {
    final active = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: active ? 0.15 : 0.05),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: color.withValues(alpha: active ? 0.3 : 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? color : AppTheme.textMuted, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: active ? color : AppTheme.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailSection(
      IconData icon, String title, String content, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.surfaceBg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    height: 1.4,
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
