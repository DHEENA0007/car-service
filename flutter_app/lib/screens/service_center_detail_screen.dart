import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/theme.dart';

class ServiceCenterDetailScreen extends StatelessWidget {
  final Map<String, dynamic> centerData;

  const ServiceCenterDetailScreen({super.key, required this.centerData});

  Future<void> _makeCall(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  Future<void> _openMaps() async {
    final lat = centerData['latitude'];
    final lng = centerData['longitude'];

    if (lat != null && lng != null) {
      final uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=${centerData['place_id'] ?? ''}');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rating = (centerData['rating'] ?? 0).toDouble();
    final reviews = centerData['total_reviews'] ?? 0;

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
                    // Rating
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ...List.generate(5, (i) {
                          return Icon(
                            i < rating.floor()
                                ? Icons.star
                                : (i < rating
                                    ? Icons.star_half
                                    : Icons.star_border),
                            color: const Color(0xFFFFB300),
                            size: 22,
                          );
                        }),
                        const SizedBox(width: 8),
                        Text(
                          rating.toStringAsFixed(1),
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$reviews reviews',
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 14),
                    ),
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
                      'Call Now',
                      AppTheme.success,
                      () => _makeCall(
                          centerData['phone_number'] ?? ''),
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
                centerData['phone_number'] ?? 'N/A',
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
                  onPressed: () =>
                      _makeCall(centerData['phone_number'] ?? ''),
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
                    'Open in Google Maps',
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

  Widget _buildActionButton(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
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
