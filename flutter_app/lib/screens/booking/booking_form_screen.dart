import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/theme.dart';
import '../../services/api_service.dart';
import 'booking_tracking_screen.dart';

class BookingFormScreen extends StatefulWidget {
  final Map<String, dynamic>? scanData;
  final Map<String, dynamic>? centerData;

  const BookingFormScreen({super.key, this.scanData, this.centerData});

  @override
  State<BookingFormScreen> createState() => _BookingFormScreenState();
}

class _BookingFormScreenState extends State<BookingFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _contactNameCtrl = TextEditingController();
  final _contactPhoneCtrl = TextEditingController();
  final _contactAddressCtrl = TextEditingController();
  final _issueCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _vehicleYearCtrl = TextEditingController();

  List<String> _makes = [];
  List<String> _models = [];
  String? _selectedMake;
  String? _selectedModel;

  bool _isLoadingMakes = false;
  bool _isLoadingModels = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadMakes();
    if (widget.scanData != null) {
      _issueCtrl.text = widget.scanData!['detected_issue'] ?? '';
      _descriptionCtrl.text = widget.scanData!['description'] ?? '';
      _selectedMake = widget.scanData!['vehicle_make'] as String?;
      _selectedModel = widget.scanData!['vehicle_model_name'] as String?;
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
        if (_selectedModel != null && !_models.contains(_selectedModel)) {
          _models.add(_selectedModel!);
          _models.sort();
        }
      });
    }
  }

  @override
  void dispose() {
    _contactNameCtrl.dispose();
    _contactPhoneCtrl.dispose();
    _contactAddressCtrl.dispose();
    _issueCtrl.dispose();
    _descriptionCtrl.dispose();
    _vehicleYearCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitBooking() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final data = <String, dynamic>{
        'contact_name': _contactNameCtrl.text.trim(),
        'contact_phone': _contactPhoneCtrl.text.trim(),
        'contact_address': _contactAddressCtrl.text.trim(),
        'detected_issue': _issueCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'vehicle_make': _selectedMake ?? '',
        'vehicle_model_name': _selectedModel ?? '',
        'vehicle_year': _vehicleYearCtrl.text.trim().isNotEmpty
            ? int.tryParse(_vehicleYearCtrl.text.trim())
            : null,
        if (widget.scanData != null && widget.scanData!['id'] != null)
          'scan_id': widget.scanData!['id'],
        if (widget.centerData != null) ...{
          'service_center_name': widget.centerData!['name'] ?? '',
          'service_center_address': widget.centerData!['address'] ?? '',
          'service_center_phone': widget.centerData!['phone_number'] ?? '',
          if (widget.centerData!['latitude'] != null)
            'service_center_lat': widget.centerData!['latitude'],
          if (widget.centerData!['longitude'] != null)
            'service_center_lng': widget.centerData!['longitude'],
        },
      };

      final result = await ApiService.createBooking(data);

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (result['success'] == true) {
        final bookingId = result['data']['id'] as int;
        await _showSuccessDialog();
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BookingTrackingScreen(bookingId: bookingId),
          ),
        );
      } else {
        final msg = result['message'] ?? result['error'] ?? 'Failed to submit booking.';
        _showError(msg.toString());
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showError('Something went wrong. Please try again.');
    }
  }

  Future<void> _showSuccessDialog() async {
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
              'Booking Submitted!',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Agents will be notified and will accept your booking shortly.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Track Booking'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showError(String message) {
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

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppTheme.scaffoldBg,
          appBar: AppBar(
            title: const Text('Book Service'),
            backgroundColor: AppTheme.scaffoldBg,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.scanData != null) ...[
                    _AiDetectionBanner(
                      issue: widget.scanData!['detected_issue'] ?? '',
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.2),
                    const SizedBox(height: 12),
                  ],
                  if (widget.centerData != null) ...[
                    _ServiceCenterBanner(centerData: widget.centerData!)
                        .animate()
                        .fadeIn(duration: 400.ms, delay: 50.ms)
                        .slideY(begin: -0.1),
                    const SizedBox(height: 20),
                  ] else if (widget.scanData == null) ...[
                    const SizedBox(height: 0),
                  ] else ...[
                    const SizedBox(height: 8),
                  ],
                  _SectionHeader(title: 'Contact Details')
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 100.ms),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _contactNameCtrl,
                    label: 'Contact Name',
                    hint: 'Enter your full name',
                    icon: Icons.person_outline_rounded,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Contact name is required' : null,
                  ).animate().fadeIn(duration: 400.ms, delay: 150.ms),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _contactPhoneCtrl,
                    label: 'Contact Phone',
                    hint: 'Enter your phone number',
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Phone number is required' : null,
                  ).animate().fadeIn(duration: 400.ms, delay: 200.ms),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _contactAddressCtrl,
                    label: 'Address / Location',
                    hint: 'Enter your address or location',
                    icon: Icons.location_on_outlined,
                    maxLines: 3,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Address is required' : null,
                  ).animate().fadeIn(duration: 400.ms, delay: 250.ms),
                  const SizedBox(height: 24),
                  _SectionHeader(title: 'Issue Details')
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 300.ms),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _issueCtrl,
                    label: 'Issue',
                    hint: 'Describe the detected issue',
                    icon: Icons.build_circle_outlined,
                    validator: (v) =>
                        v == null || v.trim().isEmpty ? 'Issue description is required' : null,
                  ).animate().fadeIn(duration: 400.ms, delay: 350.ms),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _descriptionCtrl,
                    label: 'Additional Description',
                    hint: 'Any other details about the problem...',
                    icon: Icons.notes_rounded,
                    maxLines: 4,
                  ).animate().fadeIn(duration: 400.ms, delay: 400.ms),
                  const SizedBox(height: 24),
                  _SectionHeader(title: 'Vehicle Information (Optional)')
                      .animate()
                      .fadeIn(duration: 400.ms, delay: 450.ms),
                   const SizedBox(height: 12),
                  _buildDropdownField(
                    label: 'Vehicle Make',
                    hint: 'Select Make',
                    icon: Icons.directions_car_outlined,
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
                  ).animate().fadeIn(duration: 400.ms, delay: 500.ms),
                  const SizedBox(height: 14),
                  _buildDropdownField(
                    label: 'Vehicle Model',
                    hint: _selectedMake == null ? 'Select make first' : 'Select Model',
                    icon: Icons.car_repair_rounded,
                    value: _selectedModel,
                    items: _models,
                    isLoading: _isLoadingModels,
                    enabled: _selectedMake != null,
                    onChanged: (val) => setState(() => _selectedModel = val),
                  ).animate().fadeIn(duration: 400.ms, delay: 550.ms),
                  const SizedBox(height: 14),
                  _buildField(
                    controller: _vehicleYearCtrl,
                    label: 'Vehicle Year',
                    hint: 'e.g. 2020',
                    icon: Icons.calendar_today_outlined,
                    keyboardType: TextInputType.number,
                  ).animate().fadeIn(duration: 400.ms, delay: 600.ms),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitBooking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                      child: const Text(
                        'Submit Booking',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ).animate().fadeIn(duration: 400.ms, delay: 650.ms),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
        if (_isLoading) const _LoadingOverlay(),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String hint,
    required IconData icon,
    required String? value,
    required List<String> items,
    required void Function(String?) onChanged,
    bool isLoading = false,
    bool enabled = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            if (isLoading)
              const SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryColor),
              ),
          ],
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          value: value,
          onChanged: enabled && !isLoading ? onChanged : null,
          style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppTheme.textMuted, size: 20),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, overflow: TextOverflow.ellipsis))).toList(),
          isExpanded: true,
          menuMaxHeight: 300,
          dropdownColor: AppTheme.cardBg,
        ),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: validator,
          style: const TextStyle(
              fontSize: 15, color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon,
                color: AppTheme.textMuted, size: 20),
          ),
        ),
      ],
    );
  }
}

class _AiDetectionBanner extends StatelessWidget {
  final String issue;
  const _AiDetectionBanner({required this.issue});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        boxShadow: AppTheme.glowShadow,
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI Detected Issue',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  issue.isNotEmpty ? issue : 'Pre-filled from scan',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServiceCenterBanner extends StatelessWidget {
  final Map<String, dynamic> centerData;
  const _ServiceCenterBanner({required this.centerData});

  @override
  Widget build(BuildContext context) {
    final name = centerData['name'] ?? 'Service Center';
    final address = centerData['address'] ?? '';
    final phone = centerData['phone_number'] ?? '';
    final distance = centerData['distance'] ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.store_rounded,
                color: AppTheme.primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selected Service Center',
                  style: TextStyle(
                    color: AppTheme.primaryColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    address,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (phone.isNotEmpty || distance.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (phone.isNotEmpty) ...[
                        const Icon(Icons.phone,
                            size: 12, color: AppTheme.textMuted),
                        const SizedBox(width: 4),
                        Text(phone,
                            style: const TextStyle(
                                color: AppTheme.textMuted, fontSize: 12)),
                        const SizedBox(width: 12),
                      ],
                      if (distance.isNotEmpty) ...[
                        const Icon(Icons.directions_car,
                            size: 12, color: AppTheme.accentColor),
                        const SizedBox(width: 4),
                        Text(distance,
                            style: const TextStyle(
                                color: AppTheme.accentColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppTheme.textPrimary,
      ),
    );
  }
}

class _LoadingOverlay extends StatelessWidget {
  const _LoadingOverlay();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.4),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(AppTheme.radiusLg),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: AppTheme.primaryColor,
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              const Text(
                'Submitting Booking...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
