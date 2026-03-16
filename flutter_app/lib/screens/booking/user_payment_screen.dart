import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../utils/theme.dart';
import '../../models/booking_model.dart';
import '../../services/api_service.dart';
import '../../services/razorpay_stub.dart'
    if (dart.library.js) '../../services/razorpay_web.dart';

const String _kRazorpayKeyId = 'rzp_test_SL5EZ7JYyCLRiq';

class UserPaymentScreen extends StatefulWidget {
  final int bookingId;

  const UserPaymentScreen({super.key, required this.bookingId});

  @override
  State<UserPaymentScreen> createState() => _UserPaymentScreenState();
}

class _UserPaymentScreenState extends State<UserPaymentScreen> {
  late Razorpay _razorpay;

  BookingModel? _booking;
  ChargeSheetModel? _chargeSheet;
  bool _isLoadingData = true;
  bool _isProcessingPayment = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _loadData();
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoadingData = true;
      _error = null;
    });

    BookingModel? booking;
    ChargeSheetModel? chargeSheet;

    // Load booking detail
    try {
      final bookingResult = await ApiService.getBookingDetail(widget.bookingId);
      if (bookingResult['success'] == true) {
        booking = BookingModel.fromMap(
            bookingResult['data'] as Map<String, dynamic>);
      }
    } catch (_) {}

    // Load charge sheet separately — may not exist yet
    try {
      final chargeResult = await ApiService.getChargeSheet(widget.bookingId);
      if (chargeResult['success'] == true) {
        chargeSheet = ChargeSheetModel.fromMap(
            chargeResult['data'] as Map<String, dynamic>);
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _booking = booking;
      _chargeSheet = chargeSheet;
      _isLoadingData = false;
      if (booking == null) {
        _error = 'Failed to load booking details. Check your connection.';
      }
    });
  }

  Future<void> _initiatePayment() async {
    if (_booking == null || _chargeSheet == null) return;
    if (_booking!.isPaid) {
      _showInfo('This booking has already been paid.');
      return;
    }

    setState(() => _isProcessingPayment = true);

    try {
      final result = await ApiService.createPaymentOrder(widget.bookingId);
      if (!mounted) return;

      if (result['success'] != true) {
        setState(() => _isProcessingPayment = false);
        _showError(result['message'] ?? 'Failed to create payment order.');
        return;
      }

      final data = result['data'] as Map<String, dynamic>;
      final orderId = data['razorpay_order_id'] as String? ?? '';
      final amountInPaise = ((_chargeSheet!.totalAmount * 100).round());

      final options = <String, dynamic>{
        'key': _kRazorpayKeyId,
        'amount': amountInPaise,
        'order_id': orderId,
        'name': 'AutoDiagno',
        'description': _booking!.detectedIssue.isNotEmpty
            ? _booking!.detectedIssue
            : 'Car Service – Booking #${widget.bookingId}',
        'prefill': {
          'contact': _booking!.contactPhone,
          'name': _booking!.contactName,
        },
        'theme': {'color': '#0061FF'},
      };

      if (kIsWeb) {
        openRazorpayWeb(
          options: options,
          onSuccess: (paymentId, ordId, signature) {
            _handleWebPaymentSuccess(paymentId, ordId, signature);
          },
          onError: (error) {
            if (mounted) {
              setState(() => _isProcessingPayment = false);
              _showError(error);
            }
          },
        );
      } else {
        _razorpay.open(options);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
        _showError('Failed to initiate payment. Please try again.');
      }
    }
  }

  void _handleWebPaymentSuccess(
      String paymentId, String orderId, String signature) async {
    if (!mounted) return;
    setState(() => _isProcessingPayment = true);
    try {
      final verifyResult = await ApiService.verifyPayment(
        bookingId: widget.bookingId,
        paymentId: paymentId,
        orderId: orderId,
        signature: signature,
      );
      if (!mounted) return;
      setState(() => _isProcessingPayment = false);
      if (verifyResult['success'] == true) {
        await _showPaymentSuccessDialog();
        if (mounted) Navigator.pop(context, true);
      } else {
        _showError(verifyResult['message'] ?? 'Payment verification failed.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
        _showError('Payment verification error. Please contact support.');
      }
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    if (!mounted) return;
    setState(() => _isProcessingPayment = true);

    try {
      final verifyResult = await ApiService.verifyPayment(
        bookingId: widget.bookingId,
        paymentId: response.paymentId ?? '',
        orderId: response.orderId ?? '',
        signature: response.signature ?? '',
      );

      if (!mounted) return;
      setState(() => _isProcessingPayment = false);

      if (verifyResult['success'] == true) {
        await _showPaymentSuccessDialog();
        if (mounted) Navigator.pop(context, true);
      } else {
        _showError(
            verifyResult['message'] ?? 'Payment verification failed.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
        _showError('Payment verification error. Please contact support.');
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() => _isProcessingPayment = false);
    final msg = response.message ?? 'Payment was cancelled or failed.';
    _showError(msg);
  }

  Future<void> _showPaymentSuccessDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppTheme.success.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppTheme.success, size: 40),
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Successful!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your payment of ₹${_chargeSheet?.totalAmount.toStringAsFixed(2)} has been confirmed.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
      ),
    );
  }

  void _showInfo(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.info,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppTheme.scaffoldBg,
          appBar: AppBar(
            title: Text('Pay – Booking #${widget.bookingId}'),
            backgroundColor: AppTheme.scaffoldBg,
          ),
          body: _isLoadingData
              ? const Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primaryColor))
              : _error != null && _booking == null
                  ? _ErrorState(
                      message: _error!,
                      onRetry: _loadData,
                    )
                  : _buildContent(),
        ),
        if (_isProcessingPayment) const _ProcessingOverlay(),
      ],
    );
  }

  Widget _buildContent() {
    if (_booking == null) {
      return const Center(child: Text('Booking not found.'));
    }

    final alreadyPaid = _booking!.isPaid;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (alreadyPaid)
            _AlreadyPaidBanner()
                .animate()
                .fadeIn(duration: 400.ms),
          _BookingSummaryCard(booking: _booking!)
              .animate()
              .fadeIn(duration: 400.ms, delay: alreadyPaid ? 100.ms : 0.ms),
          const SizedBox(height: 16),
          if (_chargeSheet != null) ...[
            _BillCard(chargeSheet: _chargeSheet!)
                .animate()
                .fadeIn(duration: 400.ms, delay: 150.ms),
            const SizedBox(height: 24),
          ],
          if (!alreadyPaid)
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isProcessingPayment ? null : _initiatePayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.payment_rounded,
                        size: 20, color: Colors.white),
                    const SizedBox(width: 10),
                    Text(
                      _chargeSheet != null
                          ? 'Pay ₹${_chargeSheet!.totalAmount.toStringAsFixed(2)}'
                          : 'Pay Now',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 250.ms),
          const SizedBox(height: 12),
          if (!alreadyPaid)
            Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_outline_rounded,
                      size: 14, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  const Text(
                    'Secured by Razorpay',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms, delay: 300.ms),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ─── Already Paid Banner ──────────────────────────────────────────────────────

class _AlreadyPaidBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(
            color: AppTheme.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded,
              color: AppTheme.success, size: 24),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'This booking has already been paid successfully.',
              style: TextStyle(
                color: AppTheme.success,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Booking Summary Card ─────────────────────────────────────────────────────

class _BookingSummaryCard extends StatelessWidget {
  final BookingModel booking;
  const _BookingSummaryCard({required this.booking});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.glowShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.receipt_long_rounded,
                    color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Booking #${booking.id}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    booking.dateString,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (booking.detectedIssue.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: Colors.white24),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.build_circle_outlined,
                    color: Colors.white70, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    booking.detectedIssue,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (booking.chargeSheetTotal != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Amount',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    '₹${booking.chargeSheetTotal!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Bill Card ────────────────────────────────────────────────────────────────

class _BillCard extends StatelessWidget {
  final ChargeSheetModel chargeSheet;
  const _BillCard({required this.chargeSheet});

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
            'Bill Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          // Items
          ...chargeSheet.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                  Text(
                    '₹${item.amount.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 24),
          // Subtotal
          _BillRow(
            label: 'Subtotal',
            value: '₹${chargeSheet.subtotal.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 8),
          // Tax
          _BillRow(
            label: 'Tax',
            value: '₹${chargeSheet.tax.toStringAsFixed(2)}',
            valueColor: AppTheme.textSecondary,
          ),
          const Divider(height: 20),
          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              Text(
                '₹${chargeSheet.totalAmount.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primaryColor,
                ),
              ),
            ],
          ),
          if (chargeSheet.notes.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBg,
                borderRadius:
                    BorderRadius.circular(AppTheme.radiusMd),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.notes_rounded,
                      size: 16, color: AppTheme.textMuted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chargeSheet.notes,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BillRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _BillRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: valueColor ?? AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

// ─── Processing Overlay ───────────────────────────────────────────────────────

class _ProcessingOverlay extends StatelessWidget {
  const _ProcessingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 28),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: AppTheme.cardShadow,
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                color: AppTheme.primaryColor,
                strokeWidth: 3,
              ),
              SizedBox(height: 16),
              Text(
                'Processing Payment...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Please do not close this screen',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
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
            const Icon(Icons.error_outline_rounded,
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
