import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../models/booking_model.dart';
import '../../services/api_service.dart';
import '../../utils/theme.dart';

class _ChargeItemEntry {
  final TextEditingController nameCtrl;
  final TextEditingController amountCtrl;

  _ChargeItemEntry({String name = '', String amount = ''})
      : nameCtrl = TextEditingController(text: name),
        amountCtrl = TextEditingController(text: amount);

  void dispose() {
    nameCtrl.dispose();
    amountCtrl.dispose();
  }
}

class AgentChargeSheetScreen extends StatefulWidget {
  final int bookingId;
  final ChargeSheetModel? existingSheet;

  const AgentChargeSheetScreen({
    super.key,
    required this.bookingId,
    this.existingSheet,
  });

  @override
  State<AgentChargeSheetScreen> createState() =>
      _AgentChargeSheetScreenState();
}

class _AgentChargeSheetScreenState extends State<AgentChargeSheetScreen> {
  final _formKey = GlobalKey<FormState>();
  final _taxCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final List<_ChargeItemEntry> _items = [];
  bool _isSaving = false;

  final NumberFormat _currencyFmt =
      NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    final sheet = widget.existingSheet;
    if (sheet != null) {
      for (final item in sheet.items) {
        _items.add(_ChargeItemEntry(
          name: item.name,
          amount: item.amount.toString(),
        ));
      }
      _taxCtrl.text = sheet.tax > 0 ? sheet.tax.toString() : '';
      _notesCtrl.text = sheet.notes;
    }
    if (_items.isEmpty) {
      _items.add(_ChargeItemEntry());
    }

    // Listen for changes to recalculate
    _taxCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    _taxCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _subtotal {
    double sum = 0.0;
    for (final item in _items) {
      sum += double.tryParse(item.amountCtrl.text.trim()) ?? 0.0;
    }
    return sum;
  }

  double get _tax => double.tryParse(_taxCtrl.text.trim()) ?? 0.0;

  double get _total => _subtotal + _tax;

  void _addItem() {
    setState(() => _items.add(_ChargeItemEntry()));
  }

  void _removeItem(int index) {
    if (_items.length == 1) {
      _showSnackBar('At least one item is required.', AppTheme.warning);
      return;
    }
    final entry = _items.removeAt(index);
    entry.dispose();
    setState(() {});
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate all items
    for (int i = 0; i < _items.length; i++) {
      final name = _items[i].nameCtrl.text.trim();
      final amount = _items[i].amountCtrl.text.trim();
      if (name.isEmpty) {
        _showSnackBar('Item ${i + 1}: name is required.', AppTheme.error);
        return;
      }
      if (amount.isEmpty) {
        _showSnackBar(
            'Item ${i + 1}: amount is required.', AppTheme.error);
        return;
      }
      if (double.tryParse(amount) == null) {
        _showSnackBar(
            'Item ${i + 1}: amount must be a valid number.', AppTheme.error);
        return;
      }
    }

    setState(() => _isSaving = true);

    try {
      final itemsPayload = _items
          .map((e) => {
                'name': e.nameCtrl.text.trim(),
                'amount': double.parse(e.amountCtrl.text.trim()),
              })
          .toList();

      final res = await ApiService.createChargeSheet({
        'booking_id': widget.bookingId,
        'items': itemsPayload,
        'tax': _tax,
        'notes': _notesCtrl.text.trim(),
      });

      if (!mounted) return;

      if (res['success'] == true) {
        _showSnackBar('Charge sheet saved successfully!', AppTheme.success);
        await Future.delayed(const Duration(milliseconds: 600));
        if (mounted) Navigator.pop(context);
      } else {
        _showSnackBar(
            res['message'] ?? 'Failed to save charge sheet', AppTheme.error);
      }
    } catch (_) {
      if (mounted) {
        _showSnackBar('Network error. Please try again.', AppTheme.error);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existingSheet != null;

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
          isEditing ? 'Edit Charge Sheet' : 'Create Charge Sheet',
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            // Scrollable content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Booking ID badge ──
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusMd),
                      ),
                      child: Text(
                        'Booking #${widget.bookingId}',
                        style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Charge Items section ──
                    _SectionHeader(
                      icon: Icons.receipt_long_rounded,
                      iconColor: AppTheme.primaryColor,
                      title: 'Charge Items',
                      trailing: TextButton.icon(
                        onPressed: _addItem,
                        icon: Icon(Icons.add_circle_rounded,
                            size: 16, color: AppTheme.primaryColor),
                        label: Text('Add Item',
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primaryColor,
                            )),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Item rows
                    ...List.generate(_items.length, (i) {
                      return _ItemRow(
                        index: i,
                        entry: _items[i],
                        onRemove: () => _removeItem(i),
                        onChanged: () => setState(() {}),
                      ).animate().fadeIn(
                            delay: Duration(milliseconds: i * 50),
                            duration: 250.ms,
                          );
                    }),

                    const SizedBox(height: 20),

                    // ── Tax field ──
                    _SectionHeader(
                      icon: Icons.percent_rounded,
                      iconColor: AppTheme.warning,
                      title: 'Tax (flat amount)',
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _taxCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d*\.?\d*')),
                      ],
                      decoration: InputDecoration(
                        hintText: '0.00',
                        prefixIcon: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Text('₹',
                              style: GoogleFonts.outfit(
                                  fontSize: 16,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w600)),
                        ),
                        prefixIconConstraints:
                            const BoxConstraints(minWidth: 44),
                        suffixText: 'INR',
                        suffixStyle: GoogleFonts.outfit(
                            fontSize: 12, color: AppTheme.textMuted),
                      ),
                      validator: (v) {
                        if (v != null &&
                            v.trim().isNotEmpty &&
                            double.tryParse(v.trim()) == null) {
                          return 'Enter a valid number';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 20),

                    // ── Notes field ──
                    _SectionHeader(
                      icon: Icons.notes_rounded,
                      iconColor: AppTheme.info,
                      title: 'Notes',
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _notesCtrl,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        hintText:
                            'Any additional notes for this charge sheet...',
                        alignLabelWithHint: true,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ── Totals summary ──
                    _buildTotalsSummary(),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Save button (sticky bottom) ──
            _buildSaveBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalsSummary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.lightGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.surfaceBg),
      ),
      child: Column(
        children: [
          _TotalRow(
            label: 'Subtotal',
            value: _currencyFmt.format(_subtotal),
            isBold: false,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          _TotalRow(
            label: 'Tax',
            value: _currencyFmt.format(_tax),
            isBold: false,
            valueColor: AppTheme.warning,
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1),
          ),
          _TotalRow(
            label: 'Total',
            value: _currencyFmt.format(_total),
            isBold: true,
            valueColor: AppTheme.success,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }

  Widget _buildSaveBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total to charge:',
                    style: GoogleFonts.outfit(
                        fontSize: 13, color: AppTheme.textSecondary)),
                Text(
                  _currencyFmt.format(_total),
                  style: GoogleFonts.outfit(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save_rounded, size: 20),
                label: Text(
                  _isSaving ? 'Saving...' : 'Save Charge Sheet',
                  style: GoogleFonts.outfit(
                      fontWeight: FontWeight.w600, fontSize: 15),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMd)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Item Row Widget
// ─────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  final int index;
  final _ChargeItemEntry entry;
  final VoidCallback onRemove;
  final VoidCallback onChanged;

  const _ItemRow({
    required this.index,
    required this.entry,
    required this.onRemove,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.surfaceBg),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Item ${index + 1}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryColor,
                ),
              ),
              GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.1),
                    borderRadius:
                        BorderRadius.circular(AppTheme.radiusMd),
                  ),
                  child: Icon(Icons.delete_outline_rounded,
                      color: AppTheme.error, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name field
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: entry.nameCtrl,
                  onChanged: (_) => onChanged(),
                  decoration: InputDecoration(
                    hintText: 'Item name',
                    hintStyle: GoogleFonts.outfit(
                        fontSize: 13, color: AppTheme.textMuted),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    isDense: true,
                  ),
                  style:
                      GoogleFonts.outfit(fontSize: 13, color: AppTheme.textPrimary),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ),
              const SizedBox(width: 8),
              // Amount field
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: entry.amountCtrl,
                  onChanged: (_) => onChanged(),
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d*')),
                  ],
                  decoration: InputDecoration(
                    hintText: '0.00',
                    hintStyle: GoogleFonts.outfit(
                        fontSize: 13, color: AppTheme.textMuted),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 12),
                      child: Text('₹',
                          style: GoogleFonts.outfit(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w600)),
                    ),
                    prefixIconConstraints:
                        const BoxConstraints(minWidth: 32),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 12),
                    isDense: true,
                  ),
                  style:
                      GoogleFonts.outfit(fontSize: 13, color: AppTheme.textPrimary),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    if (double.tryParse(v.trim()) == null) {
                      return 'Invalid';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Widget? trailing;

  const _SectionHeader({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        const Spacer(),
        if (trailing != null) trailing!,
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Total Row
// ─────────────────────────────────────────────

class _TotalRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isBold;
  final Color? valueColor;

  const _TotalRow({
    required this.label,
    required this.value,
    this.isBold = false,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w400,
            color: isBold ? AppTheme.textPrimary : AppTheme.textSecondary,
          ),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: isBold ? 18 : 14,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: valueColor ??
                (isBold ? AppTheme.textPrimary : AppTheme.textSecondary),
          ),
        ),
      ],
    );
  }
}
