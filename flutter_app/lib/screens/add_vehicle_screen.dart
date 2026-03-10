import 'package:flutter/material.dart';
import '../utils/theme.dart';
import '../services/api_service.dart';

class AddVehicleScreen extends StatefulWidget {
  final Map<String, dynamic>? vehicle; // non-null = edit mode

  const AddVehicleScreen({super.key, this.vehicle});

  @override
  State<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends State<AddVehicleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _makeCtrl = TextEditingController();
  final _modelCtrl = TextEditingController();
  final _yearCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _vinCtrl = TextEditingController();
  bool _isSaving = false;

  bool get _isEdit => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      final v = widget.vehicle!;
      _makeCtrl.text = v['make'] ?? '';
      _modelCtrl.text = v['model'] ?? '';
      _yearCtrl.text = v['year']?.toString() ?? '';
      _colorCtrl.text = v['color'] ?? '';
      _plateCtrl.text = v['license_plate'] ?? '';
      _vinCtrl.text = v['vin'] ?? '';
    }
  }

  @override
  void dispose() {
    _makeCtrl.dispose();
    _modelCtrl.dispose();
    _yearCtrl.dispose();
    _colorCtrl.dispose();
    _plateCtrl.dispose();
    _vinCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final data = {
      'make': _makeCtrl.text.trim(),
      'model': _modelCtrl.text.trim(),
      'year': int.parse(_yearCtrl.text.trim()),
      if (_colorCtrl.text.trim().isNotEmpty) 'color': _colorCtrl.text.trim(),
      if (_plateCtrl.text.trim().isNotEmpty) 'license_plate': _plateCtrl.text.trim(),
      if (_vinCtrl.text.trim().isNotEmpty) 'vin': _vinCtrl.text.trim(),
    };

    try {
      final result = _isEdit
          ? await ApiService.updateVehicle(widget.vehicle!['id'] as int, data)
          : await ApiService.addVehicle(data);

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
      appBar: AppBar(title: Text(_isEdit ? 'Edit Vehicle' : 'Add Vehicle')),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.lightGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Icon header
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.directions_car, size: 48, color: AppTheme.primaryColor),
                  ),
                ),
                const SizedBox(height: 28),

                _buildField('Make *', 'e.g. Toyota, Honda', _makeCtrl,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Make is required' : null),
                const SizedBox(height: 16),

                _buildField('Model *', 'e.g. Camry, Civic', _modelCtrl,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Model is required' : null),
                const SizedBox(height: 16),

                _buildField('Year *', 'e.g. 2020', _yearCtrl,
                    keyboardType: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Year is required';
                      final y = int.tryParse(v.trim());
                      if (y == null || y < 1900 || y > DateTime.now().year + 1) return 'Enter a valid year';
                      return null;
                    }),
                const SizedBox(height: 16),

                _buildField('Color', 'e.g. White, Red', _colorCtrl),
                const SizedBox(height: 16),

                _buildField('License Plate', 'e.g. TN 01 AB 1234', _plateCtrl),
                const SizedBox(height: 16),

                _buildField('VIN (optional)', 'Vehicle Identification Number', _vinCtrl),
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
                            _isEdit ? 'Save Changes' : 'Add Vehicle',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    String label,
    String hint,
    TextEditingController ctrl, {
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboardType,
          style: const TextStyle(color: AppTheme.textPrimary),
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
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
