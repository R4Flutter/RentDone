import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/core/constants/user_role.dart';
import 'package:rentdone/features/auth/presentation/providers/auth_notifier.dart';
import 'package:rentdone/features/auth/presentation/providers/auth_provider.dart';
import 'package:rentdone/features/auth/presentation/providers/auth_state.dart';
import 'package:rentdone/features/auth/presentation/widgets/forgot_password_dialog.dart';
import 'package:rentdone/shared/design/glassmorphism.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({
    super.key,
    required this.selectedRole,
    required this.phoneNumber,
  });

  final UserRole selectedRole;
  final String phoneNumber;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final AnimationController _bgController;

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(authProvider.notifier);
      notifier.setSelectedRole(widget.selectedRole);
      notifier.setMode(registerMode: false);
    });
  }

  @override
  void dispose() {
    _bgController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final brandColor = OwnerDashboardColors.brandPrimary(context);
    final textPrimary = OwnerDashboardColors.textPrimary(context);
    final textSecondary = OwnerDashboardColors.textSecondary(context);

    return Scaffold(
      backgroundColor: OwnerDashboardColors.pageBackground(context),
      extendBodyBehindAppBar: true,
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, _) {
          final shift = _bgController.value;
          return Stack(
            children: [
              // 1. Dynamic Background
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [const Color(0xFF0F172A), const Color(0xFF1E293B)]
                          : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
                    ),
                  ),
                ),
              ),

              // 2. Animated Blobs
              _blob(
                top: -100,
                left: -50,
                size: 300,
                color: brandColor.withValues(alpha: 0.15),
                travel: 20 * shift,
              ),
              _blob(
                bottom: -150,
                right: -80,
                size: 350,
                color: AppTheme.liquidPrimaryEnd.withValues(alpha: 0.12),
                travel: -25 * shift,
              ),

              // 3. Main Content
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 480),
                      child: Column(
                        children: [
                          _buildBrandHeader(isDark, brandColor),
                          const SizedBox(height: 32),
                          
                          GlassContainer(
                            blurAmount: 20,
                            opacity: isDark ? 0.1 : 0.7,
                            borderRadius: 32,
                            padding: const EdgeInsets.all(28),
                            child: Form(
                              key: _formKey,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Welcome Back',
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                      color: textPrimary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Secure access for ${widget.selectedRole.name}',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  
                                  // Verified Phone Badge
                                  _buildVerifiedBadge(theme),
                                  
                                  const SizedBox(height: 24),

                                  // Email Field
                                  _buildInput(
                                    controller: _emailController,
                                    label: 'Email Address',
                                    icon: Icons.email_outlined,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: _validateEmail,
                                    isDark: isDark,
                                  ),
                                  const SizedBox(height: 20),

                                  // Password Field
                                  _buildInput(
                                    controller: _passwordController,
                                    label: 'Password',
                                    icon: Icons.lock_outline,
                                    obscureText: _obscurePassword,
                                    validator: _validatePassword,
                                    isDark: isDark,
                                    suffix: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                                        size: 20,
                                        color: textSecondary,
                                      ),
                                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                    ),
                                  ),
                                  
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: authState.isLoading ? null : () => _onForgotPassword(context),
                                      child: Text(
                                        'Forgot Password?',
                                        style: TextStyle(
                                          color: brandColor,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                  
                                  if (authState.errorMessage != null) ...[
                                    _errorCard(authState.errorMessage!),
                                    const SizedBox(height: 16),
                                  ],

                                  // Sign In Button
                                  GlassButton(
                                    onPressed: _onEmailPressed,
                                    label: 'Sign In',
                                    isPrimary: true,
                                    isLoading: authState.isLoading,
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                  ),
                                  
                                  const SizedBox(height: 24),
                                  _buildDivider(context, textSecondary),
                                  const SizedBox(height: 24),

                                  // Google Sign In
                                  GlassButton(
                                    onPressed: _onGooglePressed,
                                    label: 'Continue with Google',
                                    icon: Icons.g_mobiledata_rounded,
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 32),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                "Don't have an account? ",
                                style: TextStyle(color: textSecondary),
                              ),
                              GestureDetector(
                                onTap: () => context.go('/signup?role=${widget.selectedRole.name}&phone=${widget.phoneNumber}'),
                                child: Text(
                                  'Sign Up',
                                  style: TextStyle(
                                    color: brandColor,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBrandHeader(bool isDark, Color brand) {
    return Column(
      children: [
        Hero(
          tag: 'app_logo',
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: brand.withValues(alpha: 0.1),
            ),
            child: Image.asset(
              'assets/images/rentdone_logo.png',
              width: 80,
              height: 80,
              errorBuilder: (_, __, ___) => Icon(Icons.apartment_rounded, size: 60, color: brand),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'RentDone',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildVerifiedBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.infoBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.infoBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_rounded, size: 16, color: AppTheme.infoBlue),
          const SizedBox(width: 8),
          Text(
            'Number: +91 ${widget.phoneNumber}',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppTheme.infoBlue,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType? keyboardType,
    required FormFieldValidator<String> validator,
    required bool isDark,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20, color: OwnerDashboardColors.textSecondary(context)),
        suffixIcon: suffix,
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: OwnerDashboardColors.brandPrimary(context), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildDivider(BuildContext context, Color textSecondary) {
    final color = textSecondary.withValues(alpha: 0.2);
    return Row(
      children: [
        Expanded(child: Divider(color: color)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textSecondary.withValues(alpha: 0.5)),
          ),
        ),
        Expanded(child: Divider(color: color)),
      ],
    );
  }

  Widget _errorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
      ),
      child: Text(
        message,
        style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _blob({
    double? top,
    double? left,
    double? right,
    double? bottom,
    required double size,
    required Color color,
    required double travel,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Transform.translate(
        offset: Offset(travel, -travel * 0.5),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [BoxShadow(color: color, blurRadius: 100, spreadRadius: 20)],
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? input) {
    final value = (input ?? '').trim();
    if (value.isEmpty) return 'Email is required';
    if (!value.contains('@')) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? input) {
    if (input == null || input.isEmpty) return 'Password is required';
    if (input.length < 6) return 'At least 6 characters';
    return null;
  }

  void _onForgotPassword(BuildContext context) {
    showForgotPasswordDialog(
      context: context,
      ref: ref,
      initialEmail: _emailController.text,
      onEmailSynced: (email) => _emailController.text = email,
    );
  }

  Future<void> _onGooglePressed() async {
    final notifier = ref.read(authProvider.notifier);
    try {
      final user = await notifier.continueWithGoogle(phone: widget.phoneNumber);
      if (!mounted) return;
      _navigateByRole(UserRoleX.tryParse(user.role) ?? widget.selectedRole);
    } catch (_) {}
  }

  Future<void> _onEmailPressed() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(authProvider.notifier);
    try {
      final user = await notifier.continueWithEmail(
        phone: widget.phoneNumber,
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      _navigateByRole(UserRoleX.tryParse(user.role) ?? widget.selectedRole);
    } catch (_) {}
  }

  void _navigateByRole(UserRole role) {
    if (role == UserRole.owner) {
      context.goNamed('ownerDashboard');
    } else {
      context.goNamed('tenantDashboard');
    }
  }
}
