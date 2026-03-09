import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/theme.dart';
import '../services/api_service.dart';
import 'home_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.register(
        username: _usernameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        firstName: _firstNameCtrl.text.trim(),
        lastName: _lastNameCtrl.text.trim(),
        phoneNumber: _phoneCtrl.text.trim(),
        password: _passwordCtrl.text,
        confirmPassword: _confirmPasswordCtrl.text,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Account created successfully!'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        String errorMsg = result['message'] ?? 'Registration failed';
        if (result['errors'] != null) {
          final errors = result['errors'] as Map<String, dynamic>;
          errorMsg = errors.values
              .map((e) => e is List ? e.first : e.toString())
              .join('\n');
        }
        _showError(errorMsg);
      }
    } catch (e) {
      if (mounted) _showError('Connection error. Please check your server.');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Back button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.cardBg,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Create Account',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 32,
                        ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 8),

                  Text(
                    'Register to start diagnosing vehicle issues',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 32),

                  // Name row
                  Row(
                    children: [
                      Expanded(
                        child: _buildField(
                          'First Name',
                          _firstNameCtrl,
                          Icons.person_outline,
                          'First name',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildField(
                          'Last Name',
                          _lastNameCtrl,
                          Icons.person_outline,
                          'Last name',
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1, end: 0),

                  const SizedBox(height: 16),

                  _buildField('Username', _usernameCtrl, Icons.alternate_email,
                          'Choose a username')
                      .animate()
                      .fadeIn(delay: 400.ms)
                      .slideX(begin: -0.1, end: 0),

                  const SizedBox(height: 16),

                  _buildField('Email', _emailCtrl, Icons.email_outlined,
                          'Enter your email',
                          keyboard: TextInputType.emailAddress)
                      .animate()
                      .fadeIn(delay: 500.ms)
                      .slideX(begin: -0.1, end: 0),

                  const SizedBox(height: 16),

                  _buildField('Phone Number', _phoneCtrl, Icons.phone_outlined,
                          'Enter phone number',
                          keyboard: TextInputType.phone)
                      .animate()
                      .fadeIn(delay: 600.ms)
                      .slideX(begin: -0.1, end: 0),

                  const SizedBox(height: 16),

                  _buildPasswordField('Password', _passwordCtrl, _obscurePassword,
                          () => setState(() => _obscurePassword = !_obscurePassword))
                      .animate()
                      .fadeIn(delay: 700.ms)
                      .slideX(begin: -0.1, end: 0),

                  const SizedBox(height: 16),

                  _buildPasswordField(
                          'Confirm Password',
                          _confirmPasswordCtrl,
                          _obscureConfirm,
                          () => setState(
                              () => _obscureConfirm = !_obscureConfirm))
                      .animate()
                      .fadeIn(delay: 800.ms)
                      .slideX(begin: -0.1, end: 0),

                  const SizedBox(height: 32),

                  // Register Button
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _register,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Already have an account? ',
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 1000.ms),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl,
      IconData icon, String hint,
      {TextInputType keyboard = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          keyboardType: keyboard,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: AppTheme.textMuted),
          ),
          validator: (val) =>
              val == null || val.isEmpty ? 'Required' : null,
        ),
      ],
    );
  }

  Widget _buildPasswordField(String label, TextEditingController ctrl,
      bool obscure, VoidCallback toggle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          style: const TextStyle(color: AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter password',
            prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textMuted),
            suffixIcon: IconButton(
              icon: Icon(
                obscure ? Icons.visibility_off : Icons.visibility,
                color: AppTheme.textMuted,
              ),
              onPressed: toggle,
            ),
          ),
          validator: (val) {
            if (val == null || val.isEmpty) return 'Required';
            if (val.length < 6) return 'Min 6 characters';
            return null;
          },
        ),
      ],
    );
  }
}
