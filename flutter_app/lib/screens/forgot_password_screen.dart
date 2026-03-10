import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/theme.dart';
import '../services/api_service.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _isLoading = false;
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendResetLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.forgotPassword(_emailCtrl.text.trim());
      if (mounted) {
        if (result['success'] == true) {
          setState(() => _sent = true);
        } else {
          _showSnack(result['message'] ?? 'Failed to send reset link', AppTheme.error);
        }
      }
    } catch (_) {
      if (mounted) {
        _showSnack('Connection error. Please check your server.', AppTheme.error);
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Forgot Password'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.darkGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: _sent ? _buildSuccessView() : _buildFormView(),
          ),
        ),
      ),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),

          // Icon
          Container(
            width: 80,
            height: 80,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.lock_reset,
              size: 40,
              color: AppTheme.primaryColor,
            ),
          )
              .animate()
              .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), duration: 500.ms)
              .fadeIn(),

          Text(
            'Reset Password',
            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontSize: 28,
                ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),

          const SizedBox(height: 10),

          Text(
            'Enter your registered email address and we will send you a password reset link.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                ),
            textAlign: TextAlign.center,
          ).animate().fadeIn(delay: 300.ms),

          const SizedBox(height: 48),

          const Text(
            'Email Address',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ).animate().fadeIn(delay: 400.ms),

          const SizedBox(height: 8),

          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: AppTheme.textPrimary),
            decoration: const InputDecoration(
              hintText: 'Enter your email',
              prefixIcon: Icon(Icons.email_outlined, color: AppTheme.textMuted),
            ),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Please enter your email';
              if (!val.contains('@')) return 'Enter a valid email';
              return null;
            },
          ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.1, end: 0),

          const SizedBox(height: 32),

          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _sendResetLink,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
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
                      'Send Reset Link',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600),
                    ),
            ),
          ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0),

          const SizedBox(height: 24),

          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Back to Login',
              style: TextStyle(color: AppTheme.textMuted),
            ),
          ).animate().fadeIn(delay: 700.ms),
        ],
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 80),

        Container(
          width: 100,
          height: 100,
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            color: AppTheme.success.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.mark_email_read_outlined,
            size: 50,
            color: AppTheme.success,
          ),
        )
            .animate()
            .scale(begin: const Offset(0.5, 0.5), end: const Offset(1, 1), duration: 500.ms,
                curve: Curves.elasticOut)
            .fadeIn(),

        Text(
          'Check Your Email',
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 28,
              ),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 300.ms),

        const SizedBox(height: 12),

        Text(
          'A password reset link has been sent to\n${_emailCtrl.text}',
          style: const TextStyle(color: AppTheme.textMuted, fontSize: 15, height: 1.5),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 500.ms),

        const SizedBox(height: 48),

        SizedBox(
          height: 54,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.radiusMd),
              ),
            ),
            child: const Text(
              'Back to Login',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
          ),
        ).animate().fadeIn(delay: 700.ms),
      ],
    );
  }
}
