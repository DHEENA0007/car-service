import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/theme.dart';

import '../services/api_service.dart';
import 'upload_screen.dart';
import 'scan_history_screen.dart';
import 'profile_screen.dart';
import 'garage_screen.dart';
import 'booking/user_bookings_screen.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _userData;
  List<dynamic> _recentScans = [];
  bool _isLoading = true;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final profileResult = await ApiService.getProfile();
      final historyResult = await ApiService.getScanHistory();

      if (mounted) {
        setState(() {
          if (profileResult['success'] == true) {
            _userData = profileResult['data'];
          }
          if (historyResult['success'] == true) {
            _recentScans = (historyResult['data'] as List).take(3).toList();
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _buildDashboard(),
      const ScanHistoryScreen(),
      const GarageScreen(),
      const UserBookingsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppTheme.lightGradient, // Switched to light gradient
        ),
        child: screens[_selectedIndex].animate().fadeIn(duration: 400.ms),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() => _selectedIndex = index);
            if (index == 0) _loadData();
          },
          backgroundColor: Colors.transparent,
          indicatorColor: AppTheme.primaryColor.withValues(alpha: 0.1),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined, color: AppTheme.textMuted),
              selectedIcon: Icon(Icons.dashboard, color: AppTheme.primaryColor),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.history_outlined, color: AppTheme.textMuted),
              selectedIcon: Icon(Icons.history, color: AppTheme.primaryColor),
              label: 'History',
            ),
            NavigationDestination(
              icon: Icon(Icons.garage_outlined, color: AppTheme.textMuted),
              selectedIcon: Icon(Icons.garage, color: AppTheme.primaryColor),
              label: 'Garage',
            ),
            NavigationDestination(
              icon: Icon(Icons.book_outlined, color: AppTheme.textMuted),
              selectedIcon: Icon(Icons.book, color: AppTheme.primaryColor),
              label: 'Bookings',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline, color: AppTheme.textMuted),
              selectedIcon: Icon(Icons.person, color: AppTheme.primaryColor),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }

  void _showQuickHelp() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceBg,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Quick Help',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tips for using AutoDiagno effectively',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ..._quickHelpItems().map((item) => _buildHelpItem(item)),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _quickHelpItems() => [
        {
          'icon': Icons.camera_alt,
          'color': AppTheme.primaryColor,
          'title': 'Take a Clear Photo',
          'desc':
              'Capture a well-lit, close-up image of the problem area. Avoid blurry or dark photos for best AI results.',
        },
        {
          'icon': Icons.description,
          'color': AppTheme.info,
          'title': 'Add a Description',
          'desc':
              'Describe the symptom in the text field (e.g., "Oil dripping from below engine"). This improves AI accuracy.',
        },
        {
          'icon': Icons.location_on,
          'color': AppTheme.accentColor,
          'title': 'Allow Location Access',
          'desc':
              'Grant location permission so we can find the nearest service centers using Mappls maps.',
        },
        {
          'icon': Icons.star,
          'color': const Color(0xFFFFB300),
          'title': 'Top-Rated Centers',
          'desc':
              'We show the top 5 nearby service centers sorted by distance and rating for your specific issue.',
        },
        {
          'icon': Icons.call,
          'color': AppTheme.success,
          'title': 'Call Directly',
          'desc':
              'Tap "Call Now" on any service center card to call them instantly without leaving the app.',
        },
        {
          'icon': Icons.history,
          'color': AppTheme.warning,
          'title': 'Scan History',
          'desc':
              'All your diagnoses are saved in History. Swipe left on a scan to delete it.',
        },
      ];

  Widget _buildHelpItem(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (item['color'] as Color).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(item['icon'] as IconData,
                color: item['color'] as Color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['title'] as String,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item['desc'] as String,
                  style: const TextStyle(
                      color: AppTheme.textMuted, fontSize: 13, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadData,
        color: AppTheme.primaryColor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader()
                  .animate()
                  .fadeIn(duration: 400.ms)
                  .slideY(begin: -0.1, end: 0),

              const SizedBox(height: 28),

              // Main Scan Button
              _buildScanCard()
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 500.ms)
                  .slideY(begin: 0.1, end: 0),

              const SizedBox(height: 24),

              // Quick Actions
              _buildQuickActions()
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 500.ms),

              const SizedBox(height: 28),

              // Recent Scans
              _buildRecentScans()
                  .animate()
                  .fadeIn(delay: 600.ms, duration: 500.ms),

              const SizedBox(height: 24),

              // Tips Section
              _buildTipsSection()
                  .animate()
                  .fadeIn(delay: 800.ms, duration: 500.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final name = _userData?['first_name'] ?? 'User';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hello, $name 👋',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 26,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'What can we help you fix today?',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.textMuted,
                  ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.surfaceBg),
          ),
          child: const Icon(
            Icons.notifications_outlined,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildScanCard() {
    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const UploadScreen()),
        );
        if (result == true) _loadData();
      },
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.glowShadow,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Scan Car Problem',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Take a photo or upload an image of your vehicle issue for AI diagnosis',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.85),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.camera_alt, color: Colors.white, size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Start Scan',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.document_scanner_rounded,
                size: 36,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                Icons.history,
                'Scan History',
                '${_userData?['total_scans'] ?? 0} scans',
                AppTheme.primaryColor,
                () => setState(() => _selectedIndex = 1),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                Icons.garage,
                'My Garage',
                'Vehicles',
                AppTheme.accentColor,
                () => setState(() => _selectedIndex = 2),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildActionCard(
                Icons.help_outline,
                'Quick Help',
                'Get tips',
                AppTheme.warning,
                _showQuickHelp,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(IconData icon, String title, String subtitle,
      Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.surfaceBg),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: AppTheme.textMuted,
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentScans() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Recent Scans',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                  ),
            ),
            if (_recentScans.isNotEmpty)
              TextButton(
                onPressed: () => setState(() => _selectedIndex = 1),
                child: const Text(
                  'View All',
                  style: TextStyle(color: AppTheme.primaryColor),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isLoading)
          const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
        else if (_recentScans.isEmpty)
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              border: Border.all(color: AppTheme.surfaceBg),
            ),
            child: Column(
              children: [
                Icon(Icons.document_scanner_outlined,
                    size: 48, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                const Text(
                  'No scans yet',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Upload a photo to diagnose your first issue',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ...List.generate(_recentScans.length, (index) {
            final scan = _recentScans[index];
            return _buildScanItem(scan, index);
          }),
      ],
    );
  }

  Widget _buildScanItem(Map<String, dynamic> scan, int index) {
    final urgency = scan['urgency_level'] ?? 'medium';
    final urgencyColor = AppTheme.getUrgencyColor(urgency);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.surfaceBg),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: urgencyColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              AppTheme.getUrgencyIcon(urgency),
              color: urgencyColor,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  scan['detected_issue'] ?? 'Pending Analysis',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  scan['created_at']?.toString().substring(0, 10) ?? '',
                  style:
                      const TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: urgencyColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              urgency.toUpperCase(),
              style: TextStyle(
                color: urgencyColor,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: (200 * index).ms).slideX(begin: 0.1, end: 0);
  }

  Widget _buildTipsSection() {
    final tips = [
      {
        'icon': Icons.camera_alt,
        'title': 'Clear Photos',
        'desc': 'Take well-lit, close-up photos for better analysis',
      },
      {
        'icon': Icons.description,
        'title': 'Add Description',
        'desc': 'Describe symptoms for more accurate diagnosis',
      },
      {
        'icon': Icons.star,
        'title': 'Top Centers',
        'desc': 'We recommend top-rated service centers near you',
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pro Tips',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 130,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: tips.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final tip = tips[index];
              return Container(
                width: 180,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppTheme.cardGradient,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  border: Border.all(color: AppTheme.surfaceBg),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(tip['icon'] as IconData,
                        color: AppTheme.accentColor, size: 24),
                    const SizedBox(height: 10),
                    Text(
                      tip['title'] as String,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tip['desc'] as String,
                      style: const TextStyle(
                        color: AppTheme.textMuted,
                        fontSize: 12,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
