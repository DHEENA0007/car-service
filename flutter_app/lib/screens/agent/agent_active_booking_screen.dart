import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/booking_model.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';
import 'agent_charge_sheet_screen.dart';

class AgentActiveBookingScreen extends StatefulWidget {
  final BookingModel booking;

  const AgentActiveBookingScreen({super.key, required this.booking});

  @override
  State<AgentActiveBookingScreen> createState() =>
      _AgentActiveBookingScreenState();
}

class _AgentActiveBookingScreenState extends State<AgentActiveBookingScreen> {
  late BookingModel _booking;
  bool _isUpdatingStatus = false;
  bool _isRefreshing = false;
  ChargeSheetModel? _chargeSheet;
  bool _isLoadingChargeSheet = false;

  @override
  void initState() {
    super.initState();
    _booking = widget.booking;
    _loadChargeSheet();
  }

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    try {
      final res = await ApiService.getBookingDetail(_booking.id);
      if (res['success'] == true && mounted) {
        setState(() {
          _booking = BookingModel.fromMap(
              res['data'] as Map<String, dynamic>);
        });
        await _loadChargeSheet();
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  Future<void> _loadChargeSheet() async {
    setState(() => _isLoadingChargeSheet = true);
    try {
      final res = await ApiService.getChargeSheet(_booking.id);
      if (res['success'] == true && mounted) {
        setState(() {
          _chargeSheet = ChargeSheetModel.fromMap(
              res['data'] as Map<String, dynamic>);
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoadingChargeSheet = false);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    setState(() => _isUpdatingStatus = true);
    try {
      final res =
          await ApiService.updateBookingStatus(_booking.id, newStatus);
      if (!mounted) return;
      if (res['success'] == true) {
        setState(() {
          _booking = BookingModel.fromMap(
              res['data'] as Map<String, dynamic>);
        });
        _showSnackBar(
          newStatus == 'in_progress'
              ? 'Service started successfully!'
              : 'Booking marked as completed!',
          AppTheme.success,
        );
      } else {
        _showSnackBar(
            res['message'] ?? 'Failed to update status', AppTheme.error);
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('Network error. Please try again.', AppTheme.error);
      }
    } finally {
      if (mounted) setState(() => _isUpdatingStatus = false);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.outfit()),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _callPhone(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      _showSnackBar('Cannot launch phone dialer.', AppTheme.error);
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

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(_booking.status);

    return Scaffold(
      backgroundColor: AppTheme.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppTheme.scaffoldBg,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded,
              color: AppTheme.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Booking #${_booking.id}',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: true,
        actions: [
          _isRefreshing
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primaryColor),
                  ),
                )
              : IconButton(
                  icon: Icon(Icons.refresh_rounded,
                      color: AppTheme.primaryColor),
                  onPressed: _refresh,
                  tooltip: 'Refresh',
                ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.primaryColor,
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Booking summary card ──
              _buildSectionCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Booking #${_booking.id}',
                              style: GoogleFonts.outfit(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDate(_booking.createdAt),
                              style: GoogleFonts.outfit(
                                  fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(AppTheme.radiusMd),
                            border: Border.all(
                                color: statusColor.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _booking.statusLabel,
                                style: GoogleFonts.outfit(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 300.ms),

              const SizedBox(height: 12),

              // ── Customer info card ──
              _buildSectionCard(
                title: 'Customer Information',
                icon: Icons.person_rounded,
                iconColor: AppTheme.primaryColor,
                child: Column(
                  children: [
                    _DetailRow(
                      icon: Icons.person_outline_rounded,
                      label: 'Name',
                      value: _booking.contactName,
                    ),
                    const SizedBox(height: 10),
                    GestureDetector(
                      onTap: () => _callPhone(_booking.contactPhone),
                      child: Row(
                        children: [
                          Icon(Icons.phone_rounded,
                              size: 16, color: AppTheme.primaryColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Phone',
                                  style: GoogleFonts.outfit(
                                      fontSize: 11,
                                      color: AppTheme.textMuted),
                                ),
                                Text(
                                  _booking.contactPhone,
                                  style: GoogleFonts.outfit(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.primaryColor,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.call_rounded,
                              color: AppTheme.primaryColor, size: 20),
                        ],
                      ),
                    ),
                    if (_booking.contactAddress.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      _DetailRow(
                        icon: Icons.location_on_rounded,
                        label: 'Address',
                        value: _booking.contactAddress,
                        maxLines: 3,
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(delay: 80.ms, duration: 300.ms),

              const SizedBox(height: 12),

              // ── Issue / Vehicle card ──
              _buildSectionCard(
                title: 'Issue & Vehicle',
                icon: Icons.car_repair_rounded,
                iconColor: AppTheme.warning,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_booking.detectedIssue.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                          border: Border.all(
                              color: AppTheme.warning.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: AppTheme.warning, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _booking.detectedIssue,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    if (_booking.description.isNotEmpty) ...[
                      _DetailRow(
                        icon: Icons.description_outlined,
                        label: 'Description',
                        value: _booking.description,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 10),
                    ],
                    _DetailRow(
                      icon: Icons.directions_car_rounded,
                      label: 'Vehicle',
                      value:
                          '${_booking.vehicleMake} ${_booking.vehicleModelName}${_booking.vehicleYear != null ? ' (${_booking.vehicleYear})' : ''}',
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 160.ms, duration: 300.ms),

              const SizedBox(height: 12),

              // ── Service Center card ──
              if (_booking.serviceCenterName.isNotEmpty)
                _buildSectionCard(
                  title: 'Service Center',
                  icon: Icons.store_rounded,
                  iconColor: AppTheme.primaryColor,
                  child: Column(
                    children: [
                      _DetailRow(
                        icon: Icons.store_outlined,
                        label: 'Center Name',
                        value: _booking.serviceCenterName,
                      ),
                      if (_booking.serviceCenterAddress.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _DetailRow(
                          icon: Icons.location_on_rounded,
                          label: 'Address',
                          value: _booking.serviceCenterAddress,
                          maxLines: 3,
                        ),
                      ],
                      if (_booking.serviceCenterPhone.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: () =>
                              _callPhone(_booking.serviceCenterPhone),
                          child: Row(
                            children: [
                              Icon(Icons.phone_rounded,
                                  size: 16, color: AppTheme.primaryColor),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Center Phone',
                                      style: GoogleFonts.outfit(
                                          fontSize: 11,
                                          color: AppTheme.textMuted),
                                    ),
                                    Text(
                                      _booking.serviceCenterPhone,
                                      style: GoogleFonts.outfit(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.primaryColor,
                                        decoration:
                                            TextDecoration.underline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(Icons.call_rounded,
                                  color: AppTheme.primaryColor, size: 20),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ).animate().fadeIn(delay: 200.ms, duration: 300.ms),

              if (_booking.serviceCenterName.isNotEmpty)
                const SizedBox(height: 12),

              // ── Status action buttons ──
              if (_booking.status == 'accepted' ||
                  _booking.status == 'in_progress')
                _buildSectionCard(
                  title: 'Update Status',
                  icon: Icons.update_rounded,
                  iconColor: AppTheme.info,
                  child: _booking.status == 'accepted'
                      ? _buildActionButton(
                          label: 'Start Service',
                          icon: Icons.play_circle_rounded,
                          color: AppTheme.info,
                          onPressed: () => _updateStatus('in_progress'),
                          isLoading: _isUpdatingStatus,
                        )
                      : _buildActionButton(
                          label: 'Mark Complete',
                          icon: Icons.check_circle_rounded,
                          color: AppTheme.success,
                          onPressed: () => _updateStatus('completed'),
                          isLoading: _isUpdatingStatus,
                        ),
                ).animate().fadeIn(delay: 240.ms, duration: 300.ms),

              if (_booking.status == 'accepted' ||
                  _booking.status == 'in_progress')
                const SizedBox(height: 12),

              // ── Charge sheet section ──
              _buildSectionCard(
                title: 'Charge Sheet',
                icon: Icons.receipt_long_rounded,
                iconColor: AppTheme.success,
                child: _isLoadingChargeSheet
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: CircularProgressIndicator(
                              color: AppTheme.primaryColor, strokeWidth: 2),
                        ),
                      )
                    : _chargeSheet != null
                        ? _buildChargeSheetSummary()
                        : _buildNoChargeSheet(),
              ).animate().fadeIn(delay: 320.ms, duration: 300.ms),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoChargeSheet() {
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.receipt_outlined,
                color: AppTheme.textMuted, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No charge sheet yet',
                    style: GoogleFonts.outfit(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Text(
                    'Create a charge sheet to bill the customer.',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AgentChargeSheetScreen(
                      bookingId: _booking.id),
                ),
              );
              _refresh();
            },
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text('Create Charge Sheet',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.success,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildChargeSheetSummary() {
    final formatter =
        NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);
    final total = _chargeSheet?.totalAmount ??
        _booking.chargeSheetTotal ??
        0.0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Amount',
                    style: GoogleFonts.outfit(
                        fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatter.format(total),
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.success,
                    ),
                  ),
                ],
              ),
            ),
            if (_chargeSheet != null) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${_chargeSheet!.items.length} items',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Tax: ${formatter.format(_chargeSheet!.tax)}',
                    style: GoogleFonts.outfit(
                        fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AgentChargeSheetScreen(
                    bookingId: _booking.id,
                    existingSheet: _chargeSheet,
                  ),
                ),
              );
              _refresh();
            },
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: Text('View / Edit',
                style: GoogleFonts.outfit(fontWeight: FontWeight.w600)),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              side: BorderSide(color: AppTheme.primaryColor),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onPressed,
    required bool isLoading,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : Icon(icon, size: 20),
        label: Text(
          isLoading ? 'Updating...' : label,
          style:
              GoogleFonts.outfit(fontWeight: FontWeight.w600, fontSize: 15),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
        ),
      ),
    );
  }

  Widget _buildSectionCard({
    required Widget child,
    String? title,
    IconData? icon,
    Color? iconColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.cardShadow,
        border: Border.all(color: AppTheme.surfaceBg.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null && icon != null) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: (iconColor ?? AppTheme.primaryColor)
                        .withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Icon(icon,
                      size: 16,
                      color: iconColor ?? AppTheme.primaryColor),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Divider(color: AppTheme.surfaceBg, height: 1),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final int maxLines;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.maxLines = 2,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppTheme.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                    fontSize: 11, color: AppTheme.textMuted),
              ),
              Text(
                value.isNotEmpty ? value : '—',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
                maxLines: maxLines,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
