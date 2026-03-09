import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/theme.dart';
import '../utils/constants.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userData;
  bool _isLoading = true;
  bool _isEditing = false;

  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.getProfile();
      if (mounted && result['success'] == true) {
        setState(() {
          _userData = result['data'];
          _firstNameCtrl.text = _userData?['first_name'] ?? '';
          _lastNameCtrl.text = _userData?['last_name'] ?? '';
          _phoneCtrl.text = _userData?['phone_number'] ?? '';
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _updateProfile() async {
    try {
      final result = await ApiService.updateProfile({
        'first_name': _firstNameCtrl.text.trim(),
        'last_name': _lastNameCtrl.text.trim(),
        'phone_number': _phoneCtrl.text.trim(),
      });

      if (mounted) {
        if (result['success'] == true) {
          setState(() {
            _userData = result['data'];
            _isEditing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Profile updated successfully'),
              backgroundColor: AppTheme.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update profile'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Logout',
            style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('Are you sure you want to logout?',
            style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ApiService.logout();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
            ),
            child: const Text('Logout',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const SizedBox(
                height: 400,
                child: Center(
                  child: CircularProgressIndicator(
                      color: AppTheme.primaryColor),
                ),
              )
            : Column(
                children: [
                  // Profile Header
                  _buildProfileHeader()
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: -0.1, end: 0),

                  const SizedBox(height: 24),

                  // Stats Row
                  _buildStatsRow()
                      .animate()
                      .fadeIn(delay: 200.ms, duration: 400.ms),

                  const SizedBox(height: 24),

                  // Profile Info / Edit
                  _isEditing
                      ? _buildEditForm()
                          .animate()
                          .fadeIn(duration: 300.ms)
                      : _buildInfoCards()
                          .animate()
                          .fadeIn(delay: 400.ms, duration: 400.ms),

                  const SizedBox(height: 24),

                  // Actions
                  _buildActions()
                      .animate()
                      .fadeIn(delay: 600.ms, duration: 400.ms),
                ],
              ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final name =
        '${_userData?['first_name'] ?? ''} ${_userData?['last_name'] ?? ''}'
            .trim();

    return Column(
      children: [
        Text(
          'My Profile',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 24),
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: AppTheme.primaryGradient,
            shape: BoxShape.circle,
            boxShadow: AppTheme.glowShadow,
          ),
          child: Center(
            child: Text(
              (name.isNotEmpty ? name[0] : 'U').toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          name.isNotEmpty ? name : 'User',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          _userData?['email'] ?? '',
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLg),
        border: Border.all(color: AppTheme.surfaceBg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(
            Icons.document_scanner,
            '${_userData?['total_scans'] ?? 0}',
            'Total Scans',
            AppTheme.primaryColor,
          ),
          Container(
            width: 1,
            height: 40,
            color: AppTheme.surfaceBg,
          ),
          _buildStatItem(
            Icons.calendar_today,
            _userData?['date_joined']?.toString().substring(0, 10) ?? 'N/A',
            'Member Since',
            AppTheme.accentColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
      IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildInfoCards() {
    return Column(
      children: [
        _buildInfoTile(Icons.person, 'Username',
            _userData?['username'] ?? 'N/A', AppTheme.primaryColor),
        const SizedBox(height: 10),
        _buildInfoTile(Icons.email, 'Email', _userData?['email'] ?? 'N/A',
            AppTheme.info),
        const SizedBox(height: 10),
        _buildInfoTile(Icons.phone, 'Phone',
            _userData?['phone_number'] ?? 'Not set', AppTheme.success),
        const SizedBox(height: 10),
        _buildInfoTile(
            Icons.badge,
            'Full Name',
            '${_userData?['first_name'] ?? ''} ${_userData?['last_name'] ?? ''}'
                .trim(),
            AppTheme.warning),
      ],
    );
  }

  Widget _buildInfoTile(
      IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
        border: Border.all(color: AppTheme.surfaceBg),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                    color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 2),
              Text(
                value.isNotEmpty ? value : 'Not set',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    return Column(
      children: [
        _buildEditField('First Name', _firstNameCtrl, Icons.person),
        const SizedBox(height: 12),
        _buildEditField('Last Name', _lastNameCtrl, Icons.person_outline),
        const SizedBox(height: 12),
        _buildEditField('Phone Number', _phoneCtrl, Icons.phone,
            keyboard: TextInputType.phone),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => setState(() => _isEditing = false),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppTheme.textMuted),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
                child: const Text('Cancel',
                    style: TextStyle(color: AppTheme.textMuted)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _updateProfile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: AppTheme.success,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                  ),
                ),
                child: const Text('Save Changes',
                    style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEditField(
      String label, TextEditingController ctrl, IconData icon,
      {TextInputType keyboard = TextInputType.text}) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboard,
      style: const TextStyle(color: AppTheme.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppTheme.textMuted),
        prefixIcon: Icon(icon, color: AppTheme.textMuted),
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        // Edit Profile
        _buildActionTile(
          Icons.edit,
          'Edit Profile',
          'Update your personal information',
          AppTheme.primaryColor,
          () => setState(() => _isEditing = !_isEditing),
        ),
        const SizedBox(height: 10),
        // App Info
        _buildActionTile(
          Icons.info_outline,
          'About ${AppConstants.appName}',
          'Version ${AppConstants.appVersion}',
          AppTheme.info,
          () {},
        ),
        const SizedBox(height: 10),
        // Logout
        _buildActionTile(
          Icons.logout,
          'Logout',
          'Sign out of your account',
          AppTheme.error,
          _logout,
        ),
      ],
    );
  }

  Widget _buildActionTile(IconData icon, String title, String subtitle,
      Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
          border: Border.all(color: AppTheme.surfaceBg),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }
}
