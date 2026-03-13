import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/booking_model.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';
import 'agent_active_booking_screen.dart';

class AgentHomeScreen extends StatefulWidget {
  const AgentHomeScreen({super.key});

  @override
  State<AgentHomeScreen> createState() => _AgentHomeScreenState();
}

class _AgentHomeScreenState extends State<AgentHomeScreen> {
  int _selectedIndex = 0;
  final _myJobsKey = GlobalKey<_MyJobsTabState>();
  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      _AvailableTab(onBookingAccepted: _refreshMyJobs),
      _MyJobsTab(key: _myJobsKey),
      const _ProfileTab(),
    ];
  }

  void _refreshMyJobs() {
    _myJobsKey.currentState?._load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text(
          'Agent Portal',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        backgroundColor: AppTheme.scaffoldBg,
        elevation: 0,
        centerTitle: true,
        leading: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: const Icon(Icons.car_repair, color: Colors.white, size: 20),
        ),
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.list_alt_rounded,
                  label: 'Available',
                  isSelected: _selectedIndex == 0,
                  onTap: () => setState(() => _selectedIndex = 0),
                ),
                _NavItem(
                  icon: Icons.work_rounded,
                  label: 'My Jobs',
                  isSelected: _selectedIndex == 1,
                  onTap: () {
                    setState(() => _selectedIndex = 1);
                    _refreshMyJobs();
                  },
                ),
                _NavItem(
                  icon: Icons.person_rounded,
                  label: 'Profile',
                  isSelected: _selectedIndex == 2,
                  onTap: () => setState(() => _selectedIndex = 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.primaryColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight:
                    isSelected ? FontWeight.w600 : FontWeight.w400,
                color:
                    isSelected ? AppTheme.primaryColor : AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tab 1: Available Bookings
// ─────────────────────────────────────────────

class _AvailableTab extends StatefulWidget {
  final VoidCallback? onBookingAccepted;

  const _AvailableTab({this.onBookingAccepted});

  @override
  State<_AvailableTab> createState() => _AvailableTabState();
}

class _AvailableTabState extends State<_AvailableTab> {
  List<BookingModel> _bookings = [];
  bool _isLoading = true;
  String? _error;
  final Set<int> _acceptingIds = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await ApiService.getAvailableBookings();
      if (res['success'] == true) {
        final raw = res['data'] as List? ?? [];
        setState(() {
          _bookings = raw
              .map((e) => BookingModel.fromMap(e as Map<String, dynamic>))
              .toList();
        });
      } else {
        setState(() => _error = res['message'] ?? 'Failed to load bookings');
      }
    } catch (e) {
      setState(() => _error = 'Network error. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _acceptBooking(int id) async {
    setState(() => _acceptingIds.add(id));
    try {
      final res = await ApiService.acceptBooking(id);
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() => _bookings.removeWhere((b) => b.id == id));
        widget.onBookingAccepted?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking #$id accepted successfully!',
                style: GoogleFonts.outfit()),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Failed to accept booking',
                style: GoogleFonts.outfit()),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Network error. Please try again.', style: GoogleFonts.outfit()),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        ),
      );
    } finally {
      setState(() => _acceptingIds.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: _load,
      child: _isLoading
          ? _buildShimmer()
          : _error != null
              ? _buildError()
              : _bookings.isEmpty
                  ? _buildEmpty(
                      'No Available Bookings',
                      'New bookings will appear here when customers request service.',
                      Icons.inbox_rounded,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _bookings.length,
                      itemBuilder: (context, i) {
                        return _AvailableBookingCard(
                          booking: _bookings[i],
                          isAccepting: _acceptingIds.contains(_bookings[i].id),
                          onAccept: () => _acceptBooking(_bookings[i].id),
                        ).animate().fadeIn(
                              delay: Duration(milliseconds: i * 80),
                              duration: 400.ms,
                            );
                      },
                    ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: AppTheme.surfaceBg,
        highlightColor: Colors.white,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 140,
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                color: AppTheme.error, size: 48),
            const SizedBox(height: 16),
            Text(_error!,
                style: GoogleFonts.outfit(
                    color: AppTheme.textSecondary, fontSize: 15),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('Retry', style: GoogleFonts.outfit()),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _buildEmpty(String title, String subtitle, IconData icon) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surfaceBg,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppTheme.textMuted, size: 48),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.outfit(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

class _AvailableBookingCard extends StatelessWidget {
  final BookingModel booking;
  final bool isAccepting;
  final VoidCallback onAccept;

  const _AvailableBookingCard({
    required this.booking,
    required this.isAccepting,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(
          color: AppTheme.surfaceBg.withValues(alpha: 0.8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Text(
                    'Booking #${booking.id}',
                    style: GoogleFonts.outfit(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  booking.dateString,
                  style: GoogleFonts.outfit(
                      fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Issue
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Icon(Icons.warning_amber_rounded,
                      color: AppTheme.warning, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        booking.detectedIssue.isNotEmpty
                            ? booking.detectedIssue
                            : 'Unknown Issue',
                        style: GoogleFonts.outfit(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Details grid
            _InfoRow(
                icon: Icons.person_outline_rounded,
                text: booking.contactName),
            const SizedBox(height: 6),
            _InfoRow(
              icon: Icons.directions_car_rounded,
              text:
                  '${booking.vehicleMake} ${booking.vehicleModelName}${booking.vehicleYear != null ? ' (${booking.vehicleYear})' : ''}',
            ),
            const SizedBox(height: 6),
            _InfoRow(
                icon: Icons.location_on_outlined,
                text: booking.contactAddress.isNotEmpty
                    ? booking.contactAddress
                    : 'Address not provided'),
            const SizedBox(height: 16),

            // Accept button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isAccepting ? null : onAccept,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.success,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
                child: isAccepting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_outline_rounded,
                              size: 18),
                          const SizedBox(width: 8),
                          Text('Accept',
                              style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w600, fontSize: 14)),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppTheme.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.outfit(
                fontSize: 13, color: AppTheme.textSecondary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Tab 2: My Jobs
// ─────────────────────────────────────────────

class _MyJobsTab extends StatefulWidget {
  const _MyJobsTab({super.key});

  @override
  State<_MyJobsTab> createState() => _MyJobsTabState();
}

class _MyJobsTabState extends State<_MyJobsTab> {
  List<BookingModel> _bookings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await ApiService.getMyBookings();
      if (res['success'] == true) {
        final raw = res['data'] as List? ?? [];
        setState(() {
          _bookings = raw
              .map((e) => BookingModel.fromMap(e as Map<String, dynamic>))
              .toList();
        });
      } else {
        setState(() => _error = res['message'] ?? 'Failed to load jobs');
      }
    } catch (e) {
      setState(() => _error = 'Network error. Please try again.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return AppTheme.info;
      case 'in_progress':
        return AppTheme.warning;
      case 'completed':
        return AppTheme.success;
      case 'cancelled':
        return AppTheme.error;
      default:
        return AppTheme.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: _load,
      child: _isLoading
          ? _buildShimmer()
          : _error != null
              ? _buildError()
              : _bookings.isEmpty
                  ? _buildEmpty(
                      'No Jobs Yet',
                      'Your accepted and completed jobs will appear here.',
                      Icons.work_outline_rounded,
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _bookings.length,
                      itemBuilder: (context, i) {
                        final b = _bookings[i];
                        return _MyJobCard(
                          booking: b,
                          statusColor: _statusColor(b.status),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    AgentActiveBookingScreen(booking: b),
                              ),
                            );
                            _load();
                          },
                        ).animate().fadeIn(
                              delay: Duration(milliseconds: i * 80),
                              duration: 400.ms,
                            );
                      },
                    ),
    );
  }

  Widget _buildShimmer() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: AppTheme.surfaceBg,
        highlightColor: Colors.white,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          height: 110,
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
        ),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded,
                color: AppTheme.error, size: 48),
            const SizedBox(height: 16),
            Text(_error!,
                style: GoogleFonts.outfit(
                    color: AppTheme.textSecondary, fontSize: 15),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
              label: Text('Retry', style: GoogleFonts.outfit()),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyJobCard extends StatelessWidget {
  final BookingModel booking;
  final Color statusColor;
  final VoidCallback onTap;

  const _MyJobCard({
    required this.booking,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(
            color: AppTheme.surfaceBg.withValues(alpha: 0.8),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Booking #${booking.id}',
                    style: GoogleFonts.outfit(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                          color: statusColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      booking.statusLabel,
                      style: GoogleFonts.outfit(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                booking.detectedIssue.isNotEmpty
                    ? booking.detectedIssue
                    : 'Unknown Issue',
                style: GoogleFonts.outfit(
                    fontSize: 13, color: AppTheme.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.person_outline_rounded,
                      size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 4),
                  Text(
                    booking.contactName,
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const Spacer(),
                  Text(
                    booking.dateString,
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded,
                      size: 16, color: AppTheme.textMuted),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tab 3: Profile
// ─────────────────────────────────────────────

class _ProfileTab extends StatefulWidget {
  const _ProfileTab();

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  int _completedJobs = 0;
  bool _isLoggingOut = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final cached = await ApiService.getCachedUserData();
      final res = await ApiService.getMyBookings();
      int completed = 0;
      if (res['success'] == true) {
        final raw = res['data'] as List? ?? [];
        completed = raw
            .where((e) => (e as Map<String, dynamic>)['status'] == 'completed')
            .length;
      }
      if (mounted) {
        setState(() {
          _userData = cached;
          _completedJobs = completed;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusLg)),
        title: Text('Logout',
            style: GoogleFonts.outfit(
                fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
        content: Text('Are you sure you want to logout?',
            style:
                GoogleFonts.outfit(fontSize: 14, color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: GoogleFonts.outfit(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            ),
            child: Text('Logout',
                style: GoogleFonts.outfit(
                    color: Colors.white, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _isLoggingOut = true);
    try {
      await ApiService.logout();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    } catch (_) {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: AppTheme.primaryColor),
      );
    }

    final firstName = _userData?['first_name'] as String? ?? '';
    final lastName = _userData?['last_name'] as String? ?? '';
    final fullName =
        '${firstName.trim()} ${lastName.trim()}'.trim().isEmpty
            ? (_userData?['username'] as String? ?? 'Agent')
            : '${firstName.trim()} ${lastName.trim()}';
    final email = _userData?['email'] as String? ?? '';
    final username = _userData?['username'] as String? ?? '';

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Avatar & name
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                boxShadow: AppTheme.glowShadow,
              ),
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        fullName.isNotEmpty
                            ? fullName[0].toUpperCase()
                            : 'A',
                        style: GoogleFonts.outfit(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    fullName,
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  if (email.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8)),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Text(
                      '@$username',
                      style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.white.withValues(alpha: 0.9)),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms),

            const SizedBox(height: 20),

            // Stats
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(AppTheme.radiusLg),
                boxShadow: AppTheme.cardShadow,
                border: Border.all(
                    color: AppTheme.surfaceBg.withValues(alpha: 0.8)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _StatItem(
                      icon: Icons.check_circle_rounded,
                      value: _completedJobs.toString(),
                      label: 'Completed\nJobs',
                      color: AppTheme.success,
                    ),
                  ),
                  Container(
                    height: 50,
                    width: 1,
                    color: AppTheme.surfaceBg,
                  ),
                  Expanded(
                    child: _StatItem(
                      icon: Icons.star_rounded,
                      value: 'Agent',
                      label: 'Role',
                      color: AppTheme.warning,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

            const SizedBox(height: 20),

            // Logout button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isLoggingOut ? null : _logout,
                icon: _isLoggingOut
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.logout_rounded, size: 18),
                label: Text(
                  _isLoggingOut ? 'Logging out...' : 'Logout',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.error,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMd)),
                ),
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),
          ],
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.outfit(
              fontSize: 11, color: AppTheme.textSecondary),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
