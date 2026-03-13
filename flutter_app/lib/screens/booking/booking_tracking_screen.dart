import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/theme.dart';
import '../../models/booking_model.dart';
import '../../services/api_service.dart';
import 'user_payment_screen.dart';

class BookingTrackingScreen extends StatefulWidget {
  final int bookingId;

  const BookingTrackingScreen({super.key, required this.bookingId});

  @override
  State<BookingTrackingScreen> createState() => _BookingTrackingScreenState();
}

class _BookingTrackingScreenState extends State<BookingTrackingScreen> {
  BookingModel? _booking;
  bool _isLoading = true;
  bool _isRefreshing = false;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadBooking();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !_isRefreshing) _silentRefresh();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadBooking() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    await _fetchBooking();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _silentRefresh() async {
    _isRefreshing = true;
    await _fetchBooking();
    _isRefreshing = false;
  }

  Future<void> _fetchBooking() async {
    try {
      final result = await ApiService.getBookingDetail(widget.bookingId);
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() {
          _booking = BookingModel.fromMap(
              result['data'] as Map<String, dynamic>);
          _error = null;
        });
      } else {
        setState(() => _error = result['message'] ?? 'Failed to load booking.');
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Connection error. Retrying...');
    }
  }

  Future<void> _onRefresh() async {
    setState(() => _isRefreshing = true);
    await _fetchBooking();
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        title: Text('Booking #${widget.bookingId}'),
        backgroundColor: AppTheme.scaffoldBg,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isRefreshing ? null : _onRefresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _error != null && _booking == null
              ? _ErrorState(
                  message: _error!,
                  onRetry: _loadBooking,
                )
              : _booking == null
                  ? const Center(child: Text('No booking found.'))
                  : RefreshIndicator(
                      onRefresh: _onRefresh,
                      color: AppTheme.primaryColor,
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _StatusHeader(booking: _booking!)
                                .animate()
                                .fadeIn(duration: 400.ms),
                            const SizedBox(height: 24),
                            _TimelineStepper(booking: _booking!)
                                .animate()
                                .fadeIn(duration: 400.ms, delay: 100.ms),
                            const SizedBox(height: 20),
                            if (_booking!.agentName != null &&
                                _booking!.agentName!.isNotEmpty) ...[
                              _AgentCard(agentName: _booking!.agentName!)
                                  .animate()
                                  .fadeIn(duration: 400.ms, delay: 200.ms),
                              const SizedBox(height: 16),
                            ],
                            if (_booking!.hasChargeSheet &&
                                _booking!.chargeSheetTotal != null) ...[
                              _ChargeSheetCard(
                                booking: _booking!,
                                onPayNow: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => UserPaymentScreen(
                                        bookingId: _booking!.id),
                                  ),
                                ).then((_) => _loadBooking()),
                              )
                                  .animate()
                                  .fadeIn(duration: 400.ms, delay: 300.ms),
                              const SizedBox(height: 16),
                            ],
                            _BookingDetailsCard(booking: _booking!)
                                .animate()
                                .fadeIn(duration: 400.ms, delay: 400.ms),
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
                    ),
    );
  }
}

// ─── Status Header ────────────────────────────────────────────────────────────

class _StatusHeader extends StatelessWidget {
  final BookingModel booking;
  const _StatusHeader({required this.booking});

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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.glowShadow,
      ),
      child: Column(
        children: [
          Text(
            booking.statusEmoji,
            style: const TextStyle(fontSize: 52),
          ),
          const SizedBox(height: 12),
          Text(
            booking.statusLabel,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius:
                  BorderRadius.circular(AppTheme.radiusRound),
            ),
            child: Text(
              'Booking #${booking.id}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Timeline Stepper ─────────────────────────────────────────────────────────

class _TimelineStepper extends StatelessWidget {
  final BookingModel booking;
  const _TimelineStepper({required this.booking});

  bool get _agentAssigned => booking.status != 'pending';
  bool get _inProgress =>
      booking.status == 'in_progress' || booking.status == 'completed';
  bool get _completed => booking.status == 'completed';
  bool get _paid => booking.isPaid;

  @override
  Widget build(BuildContext context) {
    final steps = [
      _StepData(
        title: 'Booking Submitted',
        subtitle: 'Your request has been received',
        isDone: true,
        icon: Icons.check_circle_rounded,
      ),
      _StepData(
        title: 'Agent Assigned',
        subtitle: _agentAssigned
            ? (booking.agentName != null
                ? '${booking.agentName} is on the way'
                : 'Agent accepted your booking')
            : 'Waiting for an available agent',
        isDone: _agentAssigned,
        icon: Icons.person_pin_circle_rounded,
      ),
      _StepData(
        title: 'Service in Progress',
        subtitle: _inProgress
            ? 'Your vehicle is being serviced'
            : 'Service has not started yet',
        isDone: _inProgress,
        icon: Icons.build_rounded,
      ),
      _StepData(
        title: 'Service Completed',
        subtitle: _completed
            ? 'Service done on ${booking.dateString}'
            : 'Pending completion',
        isDone: _completed,
        icon: Icons.task_alt_rounded,
      ),
      _StepData(
        title: 'Payment',
        subtitle: _paid
            ? 'Payment confirmed'
            : booking.hasChargeSheet
                ? 'Bill ready - tap Pay Now'
                : 'Awaiting bill',
        isDone: _paid,
        icon: Icons.payment_rounded,
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          ...steps.asMap().entries.map((entry) {
            final i = entry.key;
            final step = entry.value;
            return _StepTile(
              step: step,
              isLast: i == steps.length - 1,
            );
          }),
        ],
      ),
    );
  }
}

class _StepData {
  final String title;
  final String subtitle;
  final bool isDone;
  final IconData icon;

  _StepData({
    required this.title,
    required this.subtitle,
    required this.isDone,
    required this.icon,
  });
}

class _StepTile extends StatelessWidget {
  final _StepData step;
  final bool isLast;
  const _StepTile({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final color = step.isDone ? AppTheme.primaryColor : AppTheme.textMuted;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: step.isDone
                    ? AppTheme.primaryColor
                    : AppTheme.surfaceBg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                step.icon,
                size: 18,
                color: step.isDone ? Colors.white : AppTheme.textMuted,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: step.isDone
                    ? AppTheme.primaryColor.withValues(alpha: 0.3)
                    : AppTheme.surfaceBg,
              ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: step.isDone
                        ? AppTheme.textPrimary
                        : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  step.subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Agent Card ───────────────────────────────────────────────────────────────

class _AgentCard extends StatelessWidget {
  final String agentName;
  const _AgentCard({required this.agentName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.engineering_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Agent',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  agentName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusRound),
            ),
            child: const Text(
              'Assigned',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.success,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Charge Sheet Card ────────────────────────────────────────────────────────

class _ChargeSheetCard extends StatelessWidget {
  final BookingModel booking;
  final VoidCallback onPayNow;
  const _ChargeSheetCard({required this.booking, required this.onPayNow});

  @override
  Widget build(BuildContext context) {
    final total = booking.chargeSheetTotal ?? 0.0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
          color: booking.isPaid
              ? AppTheme.success.withValues(alpha: 0.3)
              : AppTheme.warning.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: booking.isPaid
                  ? AppTheme.success.withValues(alpha: 0.1)
                  : AppTheme.warning.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              booking.isPaid
                  ? Icons.check_circle_rounded
                  : Icons.receipt_long_rounded,
              color: booking.isPaid ? AppTheme.success : AppTheme.warning,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.isPaid ? 'Payment Done' : 'Bill Ready',
                  style: TextStyle(
                    fontSize: 12,
                    color: booking.isPaid
                        ? AppTheme.success
                        : AppTheme.warning,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '₹${total.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (!booking.isPaid)
            ElevatedButton(
              onPressed: onPayNow,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMd),
                ),
              ),
              child: const Text(
                'Pay Now',
                style:
                    TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Booking Details Card ─────────────────────────────────────────────────────

class _BookingDetailsCard extends StatelessWidget {
  final BookingModel booking;
  const _BookingDetailsCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Booking Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          _DetailRow(
              icon: Icons.report_problem_outlined,
              label: 'Issue',
              value: booking.detectedIssue.isNotEmpty
                  ? booking.detectedIssue
                  : 'N/A'),
          if (booking.description.isNotEmpty)
            _DetailRow(
                icon: Icons.notes_rounded,
                label: 'Description',
                value: booking.description),
          _DetailRow(
              icon: Icons.person_outline_rounded,
              label: 'Contact',
              value: booking.contactName),
          _DetailRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: booking.contactPhone),
          _DetailRow(
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: booking.contactAddress.isNotEmpty
                  ? booking.contactAddress
                  : 'N/A'),
          if (booking.vehicleMake.isNotEmpty)
            _DetailRow(
                icon: Icons.directions_car_outlined,
                label: 'Vehicle',
                value:
                    '${booking.vehicleMake} ${booking.vehicleModelName}'
                        .trim()),
          if (booking.serviceCenterName.isNotEmpty)
            _DetailRow(
                icon: Icons.store_rounded,
                label: 'Center',
                value: booking.serviceCenterName),
          _DetailRow(
              icon: Icons.calendar_today_outlined,
              label: 'Submitted',
              value: booking.dateString),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _DetailRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.textMuted),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error State ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 56, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
