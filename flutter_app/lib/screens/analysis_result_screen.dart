import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/theme.dart';
import '../utils/constants.dart';
import 'service_centers_screen.dart';
import 'booking/booking_form_screen.dart';

class AnalysisResultScreen extends StatelessWidget {
  final Map<String, dynamic> scanData;

  const AnalysisResultScreen({super.key, required this.scanData});

  @override
  Widget build(BuildContext context) {
    final urgency = scanData['urgency_level'] ?? 'medium';
    final urgencyColor = AppTheme.getUrgencyColor(urgency);
    final confidence = (scanData['confidence_score'] ?? 0).toDouble();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnosis Result'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context, true),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.lightGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Uploaded image preview
              if (scanData['image'] != null)
                _buildImagePreview(scanData['image'] as String)
                    .animate()
                    .fadeIn(duration: 400.ms)
                    .slideY(begin: -0.1, end: 0),

              if (scanData['image'] != null) const SizedBox(height: 16),

              // Success Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      urgencyColor.withValues(alpha: 0.15),
                      urgencyColor.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                  border: Border.all(color: urgencyColor.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: urgencyColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        AppTheme.getUrgencyIcon(urgency),
                        color: urgencyColor,
                        size: 36,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      scanData['detected_issue'] ?? 'Issue Detected',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: urgencyColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        AppTheme.getUrgencyText(urgency),
                        style: TextStyle(
                          color: urgencyColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(duration: 500.ms)
                  .scale(begin: const Offset(0.9, 0.9), end: const Offset(1, 1)),

              const SizedBox(height: 20),

              // Confidence Score
              _buildInfoCard(
                context,
                icon: Icons.analytics,
                title: 'Confidence Score',
                color: AppTheme.primaryColor,
                child: Column(
                  children: [
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: confidence / 100,
                              backgroundColor: AppTheme.surfaceBg,
                              valueColor: AlwaysStoppedAnimation(
                                confidence > 70
                                    ? AppTheme.success
                                    : confidence > 40
                                        ? AppTheme.warning
                                        : AppTheme.error,
                              ),
                              minHeight: 10,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${confidence.toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: confidence > 70
                                ? AppTheme.success
                                : confidence > 40
                                    ? AppTheme.warning
                                    : AppTheme.error,
                            fontWeight: FontWeight.w700,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 200.ms).slideX(begin: 0.1, end: 0),

              const SizedBox(height: 16),

              // Problem Explanation
              _buildInfoCard(
                context,
                icon: Icons.description,
                title: 'Problem Explanation',
                color: AppTheme.info,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    scanData['problem_explanation'] ?? 'No explanation available.',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms).slideX(begin: 0.1, end: 0),

              const SizedBox(height: 16),

              // Possible Causes
              _buildInfoCard(
                context,
                icon: Icons.search,
                title: 'Possible Causes',
                color: AppTheme.warning,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: _buildCausesList(
                        scanData['possible_causes'] ?? 'Unknown'),
                  ),
                ),
              ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.1, end: 0),

              const SizedBox(height: 16),

              // Recommended Service
              _buildInfoCard(
                context,
                icon: Icons.build,
                title: 'Recommended Service',
                color: AppTheme.accentColor,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    scanData['recommended_service_type'] ??
                        'General Auto Service',
                    style: const TextStyle(
                      color: AppTheme.accentColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ).animate().fadeIn(delay: 800.ms).slideX(begin: 0.1, end: 0),

              const SizedBox(height: 28),

              // Find Service Centers Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ServiceCentersScreen(
                          scanData: scanData,
                          serviceCenters: List<Map<String, dynamic>>.from(
                              scanData['service_centers'] ?? []),
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accentColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.location_on, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'Find Nearby Service Centers',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 1000.ms, duration: 500.ms)
                  .slideY(begin: 0.2, end: 0),

              const SizedBox(height: 12),

              // Book Service Button
              SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingFormScreen(scanData: scanData),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.build_circle_outlined, color: Colors.white),
                      SizedBox(width: 10),
                      Text(
                        'Book Service Now',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 1100.ms, duration: 500.ms)
                  .slideY(begin: 0.2, end: 0),

              const SizedBox(height: 16),

              // Back to Home
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Back to Home',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 16,
                  ),
                ),
              ).animate().fadeIn(delay: 1200.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImagePreview(String imageUrl) {
    // imageUrl is already an absolute URL from the backend (request context added)
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radiusLg),
      child: Image.network(
        imageUrl,
        height: 200,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          height: 200,
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
          child: const Icon(Icons.broken_image_outlined,
              size: 48, color: AppTheme.textMuted),
        ),
        loadingBuilder: (_, child, progress) {
          if (progress == null) return child;
          return Container(
            height: 200,
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            ),
            child: const Center(
                child: CircularProgressIndicator(color: AppTheme.primaryColor)),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard(BuildContext context,
      {required IconData icon,
      required String title,
      required Color color,
      required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.surfaceBg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          child,
        ],
      ),
    );
  }

  List<Widget> _buildCausesList(String causes) {
    final items = causes.split(';').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    return items
        .map((cause) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 6, color: AppTheme.warning),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      cause,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ))
        .toList();
  }
}
