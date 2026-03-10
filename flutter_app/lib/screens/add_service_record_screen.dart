import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../utils/theme.dart';
import '../services/api_service.dart';

class AddServiceRecordScreen extends StatefulWidget {
  final int vehicleId;
  final Map<String, dynamic>? record; // non-null = edit mode

  const AddServiceRecordScreen({super.key, required this.vehicleId, this.record});

  @override
  State<AddServiceRecordScreen> createState() => _AddServiceRecordScreenState();
}

class _AddServiceRecordScreenState extends State<AddServiceRecordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _serviceNameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _mileageCtrl = TextEditingController();
  final _centerCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _serviceDate;
  File? _billImage;
  bool _isSaving = false;

  bool get _isEdit => widget.record != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final r = widget.record!;
      _serviceNameCtrl.text = r['service_name'] ?? '';
      _descCtrl.text = r['description'] ?? '';
      _costCtrl.text = r['cost']?.toString() ?? '';
      _mileageCtrl.text = r['mileage']?.toString() ?? '';
      _centerCtrl.text = r['service_center_name'] ?? '';
      _notesCtrl.text = r['notes'] ?? '';
      if (r['service_date'] != null) {
        _serviceDate = DateTime.tryParse(r['service_date'] as String);
      }
    }
  }

  @override
  void dispose() {
    _serviceNameCtrl.dispose();
    _descCtrl.dispose();
    _costCtrl.dispose();
    _mileageCtrl.dispose();
    _centerCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _serviceDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppTheme.primaryColor,
            surface: AppTheme.cardBg,
            onSurface: AppTheme.textPrimary,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _serviceDate = picked);
  }

  Future<void> _pickBillImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4,
                decoration: BoxDecoration(color: AppTheme.surfaceBg, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: AppTheme.primaryColor),
              title: const Text('Camera', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: AppTheme.accentColor),
              title: const Text('Gallery', style: TextStyle(color: AppTheme.textPrimary)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await picker.pickImage(source: source, imageQuality: 80);
    if (file != null) setState(() => _billImage = File(file.path));
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_serviceDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a service date'), backgroundColor: AppTheme.warning),
      );
      return;
    }

    setState(() => _isSaving = true);

    final data = <String, dynamic>{
      'service_name': _serviceNameCtrl.text.trim(),
      'service_date': _serviceDate!.toIso8601String().substring(0, 10),
      if (_descCtrl.text.trim().isNotEmpty) 'description': _descCtrl.text.trim(),
      if (_costCtrl.text.trim().isNotEmpty) 'cost': _costCtrl.text.trim(),
      if (_mileageCtrl.text.trim().isNotEmpty) 'mileage': _mileageCtrl.text.trim(),
      if (_centerCtrl.text.trim().isNotEmpty) 'service_center_name': _centerCtrl.text.trim(),
      if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
    };

    try {
      Map<String, dynamic> result;
      if (_isEdit) {
        result = await ApiService.updateServiceRecord(
          vehicleId: widget.vehicleId,
          recordId: widget.record!['id'] as int,
          data: data,
          billImage: _billImage,
        );
      } else {
        result = await ApiService.addServiceRecord(
          vehicleId: widget.vehicleId,
          data: data,
          billImage: _billImage,
        );
      }

      if (!mounted) return;
      if (result['success'] == true) {
        Navigator.pop(context, true);
      } else {
        _showError(result['message'] ?? result['errors']?.toString() ?? 'Save failed');
      }
    } catch (_) {
      _showError('Connection error. Please try again.');
    }
    if (mounted) setState(() => _isSaving = false);
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.error, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Service Record' : 'Add Service Record')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.lightGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _sectionLabel('Service Details'),
                const SizedBox(height: 12),

                _buildField('Service Name *', 'e.g. Oil Change, Brake Repair', _serviceNameCtrl,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Service name is required' : null),
                const SizedBox(height: 16),

                // Date picker
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.inputBg,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today, color: AppTheme.primaryColor, size: 18),
                        const SizedBox(width: 12),
                        Text(
                          _serviceDate == null
                              ? 'Select Service Date *'
                              : 'Date: ${_serviceDate!.toIso8601String().substring(0, 10)}',
                          style: TextStyle(
                            color: _serviceDate == null ? AppTheme.textMuted : AppTheme.textPrimary,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _buildField('Description', 'What was done?', _descCtrl, maxLines: 3),
                const SizedBox(height: 24),

                _sectionLabel('Cost & Mileage'),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildField('Cost (₹)', '0.00', _costCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          prefix: const Text('₹ ', style: TextStyle(color: AppTheme.textMuted))),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildField('Mileage (km)', 'e.g. 45000', _mileageCtrl,
                          keyboardType: TextInputType.number),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                _sectionLabel('Service Center'),
                const SizedBox(height: 12),

                _buildField('Service Center Name', 'Where was the service done?', _centerCtrl),
                const SizedBox(height: 24),

                _sectionLabel('Additional Notes'),
                const SizedBox(height: 12),

                _buildField('Notes', 'Any extra details...', _notesCtrl, maxLines: 3),
                const SizedBox(height: 24),

                _sectionLabel('Bill / Invoice Image'),
                const SizedBox(height: 12),

                // Bill image picker
                GestureDetector(
                  onTap: _pickBillImage,
                  child: Container(
                    height: _billImage != null ? 180 : 80,
                    decoration: BoxDecoration(
                      color: AppTheme.inputBg,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                      border: Border.all(
                        color: _billImage != null ? AppTheme.accentColor : AppTheme.surfaceBg,
                        width: _billImage != null ? 2 : 1,
                      ),
                    ),
                    child: _billImage != null
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMd - 1),
                                child: Image.file(_billImage!, fit: BoxFit.cover),
                              ),
                              Positioned(
                                top: 8, right: 8,
                                child: GestureDetector(
                                  onTap: () => setState(() => _billImage = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.close, color: Colors.white, size: 16),
                                  ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.upload_file,
                                  color: AppTheme.textMuted.withValues(alpha: 0.6), size: 24),
                              const SizedBox(width: 10),
                              Text(
                                _isEdit && widget.record!['bill_image'] != null
                                    ? 'Replace bill image'
                                    : 'Upload bill image (optional)',
                                style: TextStyle(
                                    color: AppTheme.textMuted.withValues(alpha: 0.7), fontSize: 14),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 32),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusMd)),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            width: 22, height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            _isEdit ? 'Save Changes' : 'Save Record',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
          color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15),
    );
  }

  Widget _buildField(
    String label,
    String hint,
    TextEditingController ctrl, {
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
    Widget? prefix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(color: AppTheme.textPrimary),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            prefix: prefix,
            filled: true,
            fillColor: AppTheme.inputBg,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide.none,
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: const BorderSide(color: AppTheme.error),
            ),
          ),
        ),
      ],
    );
  }
}
