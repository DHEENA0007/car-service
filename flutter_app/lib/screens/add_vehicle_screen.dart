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
  final _yearCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _plateCtrl = TextEditingController();
  final _vinCtrl = TextEditingController();
  
  List<String> _makes = [];
  List<String> _models = [];
  String? _selectedMake;
  String? _selectedModel;
  
  bool _isLoadingMakes = false;
  bool _isLoadingModels = false;
  bool _isSaving = false;

  bool get _isEdit => widget.vehicle != null;

  @override
  void initState() {
    super.initState();
    _loadMakes();
    if (_isEdit) {
      final v = widget.vehicle!;
      _selectedMake = v['make'] as String?;
      _selectedModel = v['model'] as String?;
      _yearCtrl.text = v['year']?.toString() ?? '';
      _colorCtrl.text = v['color'] ?? '';
      _plateCtrl.text = v['license_plate'] ?? '';
      _vinCtrl.text = v['vin'] ?? '';
      
      if (_selectedMake != null && _selectedMake!.isNotEmpty) {
        _loadModels(_selectedMake!);
      }
    }
  }

  Future<void> _loadMakes() async {
    setState(() => _isLoadingMakes = true);
    final makes = await ApiService.getCarMakes();
    if (mounted) {
      setState(() {
        _makes = makes;
        _isLoadingMakes = false;
        // Ensure selected make is in the list if in edit mode
        if (_selectedMake != null && !_makes.contains(_selectedMake)) {
           _makes.add(_selectedMake!);
           _makes.sort();
        }
      });
    }
  }

  Future<void> _loadModels(String make) async {
    setState(() {
      _isLoadingModels = true;
      _models = [];
    });
    final models = await ApiService.getCarModels(make);
    if (mounted) {
      setState(() {
        _models = models;
        _isLoadingModels = false;
        // Ensure selected model is in the list if in edit mode
        if (_selectedModel != null && !_models.contains(_selectedModel)) {
          _models.add(_selectedModel!);
          _models.sort();
        }
      });
    }
  }

  @override
  void dispose() {
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
      'make': _selectedMake,
      'model': _selectedModel,
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

                _buildDropdownField(
                  label: 'Make *',
                  hint: 'Select Make',
                  value: _selectedMake,
                  items: _makes,
                  isLoading: _isLoadingMakes,
                  onChanged: (val) {
                    setState(() {
                      _selectedMake = val;
                      _selectedModel = null;
                    });
                    if (val != null) _loadModels(val);
                  },
                  validator: (v) => v == null ? 'Make is required' : null,
                ),
                const SizedBox(height: 16),

                _buildDropdownField(
                  label: 'Model *',
                  hint: _selectedMake == null ? 'Select make first' : 'Select Model',
                  value: _selectedModel,
                  items: _models,
                  isLoading: _isLoadingModels,
                  enabled: _selectedMake != null,
                  onChanged: (val) => setState(() => _selectedModel = val),
                  validator: (v) => v == null ? 'Model is required' : null,
                ),
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

  Widget _buildDropdownField({
    required String label,
    required String hint,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    bool isLoading = false,
    bool enabled = true,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w600, fontSize: 14)),
            if (isLoading)
              const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
              ),
          ],
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: enabled && !isLoading ? onChanged : null,
          validator: validator,
          style: const TextStyle(color: AppTheme.textPrimary, fontSize: 15),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: enabled ? AppTheme.inputBg : AppTheme.inputBg.withValues(alpha: 0.5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
          isExpanded: true,
          menuMaxHeight: 300,
          dropdownColor: AppTheme.cardBg,
        ),
      ],
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
