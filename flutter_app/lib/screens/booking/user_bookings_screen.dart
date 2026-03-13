import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:shimmer/shimmer.dart';
import 'package:intl/intl.dart';
import '../../utils/theme.dart';
import '../../models/booking_model.dart';
import '../../services/api_service.dart';
import 'booking_tracking_screen.dart';
import 'user_payment_screen.dart';

class UserBookingsScreen extends StatefulWidget {
  const UserBookingsScreen({super.key});

  @override
  State<UserBookingsScreen> createState() => _UserBookingsScreenState();
}

class _UserBookingsScreenState extends State<UserBookingsScreen> {
  List<BookingModel> _bookings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await ApiService.getMyBookings();
      if (!mounted) return;
      if (result['success'] == true) {
        final raw = result['data'] as List? ?? [];
        setState(() {
          _bookings = raw
              .map((e) => BookingModel.fromMap(e as Map<String, dynamic>))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = result['message'] ?? 'Failed to load bookings.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Connection error. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _onRefresh() => _loadBookings();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: const Text('My Bookings'),
        backgroundColor: AppTheme.scaffoldBg,
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppTheme.primaryColor,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return _ShimmerList();
    if (_error != null) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off_rounded,
                        size: 56, color: AppTheme.textMuted),
                    const SizedBox(height: 16),
                    Text(_error!,
                        textAlign: TextAlign.center,
                        style:
                            const TextStyle(color: AppTheme.textSecondary)),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _loadBookings,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    }
    if (_bookings.isEmpty) {
      return ListView(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.65,
            child: Center(
              child: _EmptyState(onBookNow: () => Navigator.pop(context)),
            ),
          ),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _bookings.length,
      itemBuilder: (ctx, i) {
        return _BookingCard(
          booking: _bookings[i],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  BookingTrackingScreen(bookingId: _bookings[i].id),
            ),
          ).then((_) => _loadBookings()),
          onPayNow: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  UserPaymentScreen(bookingId: _bookings[i].id),
            ),
          ).then((_) => _loadBookings()),
        ).animate().fadeIn(duration: 400.ms, delay: (i * 60).ms).slideY(
              begin: 0.1,
              duration: 400.ms,
              delay: (i * 60).ms,
            );
      },
    );
  }
}

// ─── Booking Card ─────────────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback onTap;
  final VoidCallback onPayNow;

  const _BookingCard({
    required this.booking,
    required this.onTap,
    required this.onPayNow,
  });

  Color get _statusColor {
    switch (booking.status) {
      case 'pending':
        return AppTheme.warning;
      case 'accepted':
        return AppTheme.info;
      case 'in_progress':
        return const Color(0xFF8B5CF6);
      case 'completed':
        return AppTheme.success;
      case 'cancelled':
        return AppTheme.textMuted;
      default:
        return AppTheme.info;
    }
  }

  String get _statusLabel => booking.statusLabel;

  @override
  Widget build(BuildContext context) {
    String? formattedDate;
    try {
      final dt = DateTime.parse(booking.createdAt).toLocal();
      formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      formattedDate = booking.createdAt;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          boxShadow: AppTheme.cardShadow,
          border: Border.all(
            color: _statusColor.withValues(alpha: 0.15),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            // Header row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Booking #${booking.id}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          formattedDate ?? booking.dateString,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: _statusColor.withValues(alpha: 0.12),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusRound),
                    ),
                    child: Text(
                      _statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Issue
            if (booking.detectedIssue.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.build_circle_outlined,
                        size: 16, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        booking.detectedIssue,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            // Agent row (if assigned)
            if (booking.agentName != null &&
                booking.agentName!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.engineering_rounded,
                        size: 15, color: AppTheme.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      'Agent: ${booking.agentName}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            // Bill row (if has charge sheet)
            if (booking.hasChargeSheet &&
                booking.chargeSheetTotal != null) ...[
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long_rounded,
                        size: 15, color: AppTheme.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      'Bill: ₹${booking.chargeSheetTotal!.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const Spacer(),
                    if (booking.isPaid)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(
                              AppTheme.radiusRound),
                        ),
                        child: const Text(
                          'Paid',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.success,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            // Pay Now button
            if (booking.hasChargeSheet && !booking.isPaid) ...[
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: onPayNow,
                    icon: const Icon(Icons.payment_rounded, size: 16),
                    label: Text(
                      'Pay ₹${booking.chargeSheetTotal?.toStringAsFixed(2) ?? ''}',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMd),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}

// ─── Shimmer Loading ──────────────────────────────────────────────────────────

class _ShimmerList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: AppTheme.surfaceBg,
        highlightColor: Colors.white,
        child: Container(
          height: 130,
          margin: const EdgeInsets.only(bottom: 14),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
          ),
        ),
      ),
    );
  }
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onBookNow;
  const _EmptyState({required this.onBookNow});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.car_repair_rounded,
                size: 48, color: AppTheme.primaryColor),
          ),
          const SizedBox(height: 20),
          const Text(
            'No Bookings Yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Book a service and track your request here in real-time.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onBookNow,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Book a Service'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
