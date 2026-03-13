import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/theme.dart';
import 'service_center_detail_screen.dart';
import 'map_navigation_screen.dart';
import 'booking/booking_form_screen.dart';

class ServiceCentersScreen extends StatelessWidget {
  final Map<String, dynamic> scanData;
  final List<Map<String, dynamic>> serviceCenters;

  const ServiceCentersScreen({
    super.key,
    required this.scanData,
    required this.serviceCenters,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nearby Service Centers'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.lightGradient),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Issue Summary Bar
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search, color: Colors.white, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Searching for',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        Text(
                          scanData['recommended_service_type'] ??
                              'Auto Service Centers',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Top ${serviceCenters.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.1, end: 0),

            const SizedBox(height: 8),

            // Service Centers List
            Expanded(
              child: serviceCenters.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.location_off,
                              size: 64,
                              color: AppTheme.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          const Text(
                            'No service centers found nearby',
                            style: TextStyle(
                              color: AppTheme.textMuted,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: serviceCenters.length,
                      itemBuilder: (context, index) {
                        final center = serviceCenters[index];
                        return _buildCenterCard(context, center, index);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCenterCard(
      BuildContext context, Map<String, dynamic> center, int index) {
    final hasPhone = (center['phone_number'] ?? '').toString().isNotEmpty;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ServiceCenterDetailScreen(centerData: center),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          border: Border.all(color: AppTheme.surfaceBg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: rank badge + name + Mappls verified chip
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '#${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        center['name'] ?? 'Service Center',
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Mappls verified badge
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: const Color(0xFF1565C0)
                                      .withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.verified,
                                    size: 11, color: Color(0xFF1565C0)),
                                SizedBox(width: 4),
                                Text(
                                  'Mappls Verified',
                                  style: TextStyle(
                                    color: Color(0xFF1565C0),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (hasPhone) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.success.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.phone,
                                      size: 11, color: AppTheme.success),
                                  SizedBox(width: 4),
                                  Text(
                                    'Has Contact',
                                    style: TextStyle(
                                      color: AppTheme.success,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Address
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on,
                    color: AppTheme.textMuted, size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    center['address'] ?? 'No address',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Distance row
            Row(
              children: [
                const Icon(Icons.directions_car,
                    color: AppTheme.accentColor, size: 16),
                const SizedBox(width: 6),
                Text(
                  center['distance'] ?? 'N/A',
                  style: const TextStyle(
                    color: AppTheme.accentColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Action buttons: Navigate | Book | Details
            Row(
              children: [
                // Navigate button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MapNavigationScreen(centerData: center),
                        ),
                      );
                    },
                    icon: const Icon(Icons.navigation, size: 16),
                    label: const Text('Navigate'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: const BorderSide(color: AppTheme.primaryColor),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Book button
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BookingFormScreen(
                            scanData: scanData,
                            centerData: center,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.build_circle, size: 16, color: Colors.white),
                    label: const Text('Book', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.success,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(delay: (150 * index).ms, duration: 400.ms)
        .slideY(begin: 0.1, end: 0);
  }
}
