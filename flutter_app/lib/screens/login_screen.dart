import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/theme.dart';
import '../services/api_service.dart';
import 'register_screen.dart';
import 'home_screen.dart';
import 'agent/agent_home_screen.dart';
import 'admin/admin_home_screen.dart';
import 'forgot_password_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.login(
        username: _usernameController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final role = result['data']?['user']?['role'] ?? 'user';
        Widget destination;
        if (role == 'admin') {
          destination = const AdminHomeScreen();
        } else if (role == 'agent') {
          destination = const AgentHomeScreen();
        } else {
          destination = const HomeScreen();
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => destination),
        );
      } else {
        _showError(result['message'] ?? 'Login failed');
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
        decoration: const BoxDecoration(gradient: AppTheme.lightGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),

                  // Logo
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppTheme.primaryGradient,
                      boxShadow: AppTheme.glowShadow,
                    ),
                    child: const Icon(
                      Icons.directions_car_rounded,
                      size: 45,
                      color: Colors.white,
                    ),
                  )
                      .animate()
                      .scale(
                        begin: const Offset(0.5, 0.5),
                        end: const Offset(1.0, 1.0),
                        duration: 600.ms,
                        curve: Curves.elasticOut,
                      ),

                  const SizedBox(height: 24),

                  Text(
                    'Welcome Back',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontSize: 32,
                        ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 8),

                  Text(
                    'Sign in to diagnose vehicle issues',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 400.ms),

                  const SizedBox(height: 48),

                  // Username Field
                  _buildInputLabel('Email or Username'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _usernameController,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Enter your email or username',
                      prefixIcon: const Icon(Icons.person_outline, color: AppTheme.textMuted),
                      filled: true,
                      fillColor: AppTheme.lSurfaceBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Please enter username' : null,
                  ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.1, end: 0),

                  const SizedBox(height: 20),

                  // Password Field
                  _buildInputLabel('Password'),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    style: const TextStyle(color: AppTheme.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock_outline, color: AppTheme.textMuted),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.visibility_off : Icons.visibility,
                          color: AppTheme.textMuted,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      filled: true,
                      fillColor: AppTheme.lSurfaceBg,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTheme.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    validator: (val) =>
                        val == null || val.isEmpty ? 'Please enter password' : null,
                  ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.1, end: 0),

                  const SizedBox(height: 12),

                  // Forgot password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(color: AppTheme.primaryColor),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Login Button
                  SizedBox(
                    height: 54,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
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
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Sign In',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2, end: 0),

                  const SizedBox(height: 32),

                  // Register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "Don't have an account? ",
                        style: TextStyle(color: AppTheme.textMuted),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const RegisterScreen()),
                          );
                        },
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(
                            color: AppTheme.accentColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 1000.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontWeight: FontWeight.w500,
        fontSize: 14,
      ),
    );
  }
}
