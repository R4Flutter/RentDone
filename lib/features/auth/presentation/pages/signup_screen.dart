import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/core/constants/user_role.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/features/auth/presentation/providers/auth_provider.dart';
import 'package:rentdone/shared/design/glassmorphism.dart';

class SignupPage extends ConsumerStatefulWidget {
  const SignupPage({
    super.key,
    required this.selectedRole,
    required this.phoneNumber,
  });

  final UserRole selectedRole;
  final String phoneNumber;

  @override
  ConsumerState<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends ConsumerState<SignupPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final AnimationController _bgController;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 25),
    )..repeat();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(authProvider.notifier);
      notifier.setSelectedRole(widget.selectedRole);
      notifier.setMode(registerMode: true);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _bgController.dispose();
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
      body: Stack(
        children: [
          // 1. Cinematic Animated Background
          _buildCinematicBackground(isDark, brandColor),

          // 2. Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 40,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Column(
                    children: [
                      _buildBrandHeader(isDark, brandColor)
                          .animate()
                          .fadeIn(duration: 800.ms)
                          .slideY(
                            begin: -0.2,
                            end: 0,
                            curve: Curves.easeOutBack,
                          ),

                      const SizedBox(height: 32),

                      GlassContainer(
                            blurAmount: 25,
                            opacity: isDark ? 0.12 : 0.65,
                            borderRadius: 32,
                            padding: const EdgeInsets.all(32),
                            borderColor: brandColor.withValues(
                              alpha: isDark ? 0.2 : 0.1,
                            ),
                            child: Form(
                              key: _formKey,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                        'CREATE ACCOUNT',
                                        style: theme.textTheme.labelLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 3.0,
                                              color: brandColor,
                                            ),
                                        textAlign: TextAlign.center,
                                      )
                                      .animate()
                                      .fadeIn(delay: 200.ms)
                                      .moveY(begin: 10, end: 0),

                                  const SizedBox(height: 8),

                                  Text(
                                        'Join RentDone',
                                        style: theme.textTheme.headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w900,
                                              color: textPrimary,
                                              letterSpacing: -0.5,
                                            ),
                                        textAlign: TextAlign.center,
                                      )
                                      .animate()
                                      .fadeIn(delay: 300.ms)
                                      .moveY(begin: 10, end: 0),

                                  const SizedBox(height: 12),

                                  _buildVerifiedBadge(theme)
                                      .animate()
                                      .fadeIn(delay: 400.ms)
                                      .scale(begin: const Offset(0.9, 0.9)),

                                  const SizedBox(height: 32),

                                  // Email Field
                                  _buildInput(
                                        controller: _emailController,
                                        label: 'Email Address',
                                        icon: Icons.alternate_email_rounded,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        validator: _validateEmail,
                                        isDark: isDark,
                                      )
                                      .animate()
                                      .fadeIn(delay: 500.ms)
                                      .slideX(begin: -0.1),

                                  const SizedBox(height: 16),

                                  // Password Field
                                  _buildInput(
                                        controller: _passwordController,
                                        label: 'Password',
                                        icon: Icons.lock_outline_rounded,
                                        obscureText: _obscurePassword,
                                        validator: _validatePassword,
                                        isDark: isDark,
                                        suffix: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            size: 20,
                                            color: textSecondary,
                                          ),
                                          onPressed: () => setState(
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          ),
                                        ),
                                      )
                                      .animate()
                                      .fadeIn(delay: 600.ms)
                                      .slideX(begin: 0.1),

                                  const SizedBox(height: 16),

                                  // Confirm Password Field
                                  _buildInput(
                                        controller: _confirmPasswordController,
                                        label: 'Confirm Password',
                                        icon: Icons.shield_outlined,
                                        obscureText: _obscureConfirmPassword,
                                        validator: _validateConfirmPassword,
                                        isDark: isDark,
                                        suffix: IconButton(
                                          icon: Icon(
                                            _obscureConfirmPassword
                                                ? Icons.visibility_off_rounded
                                                : Icons.visibility_rounded,
                                            size: 20,
                                            color: textSecondary,
                                          ),
                                          onPressed: () => setState(
                                            () => _obscureConfirmPassword =
                                                !_obscureConfirmPassword,
                                          ),
                                        ),
                                      )
                                      .animate()
                                      .fadeIn(delay: 700.ms)
                                      .slideX(begin: -0.1),

                                  const SizedBox(height: 32),

                                  if (authState.errorMessage != null) ...[
                                    _errorCard(
                                      authState.errorMessage!,
                                    ).animate().shake(duration: 400.ms),
                                    const SizedBox(height: 16),
                                  ],

                                  // Sign Up Button
                                  _buildPrimaryButton(
                                        authState.isLoading,
                                        brandColor,
                                      )
                                      .animate()
                                      .fadeIn(delay: 800.ms)
                                      .scale(begin: const Offset(0.95, 0.95)),
                                ],
                              ),
                            ),
                          )
                          .animate()
                          .fadeIn(delay: 100.ms)
                          .scale(
                            begin: const Offset(0.98, 0.98),
                            curve: Curves.easeOutCubic,
                            duration: 600.ms,
                          ),

                      const SizedBox(height: 40),

                      _buildFooter(
                        textSecondary,
                        brandColor,
                      ).animate().fadeIn(delay: 1000.ms),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCinematicBackground(bool isDark, Color brandColor) {
    return AnimatedBuilder(
      animation: _bgController,
      builder: (context, _) {
        return Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [const Color(0xFF020617), const Color(0xFF0F172A)]
                        : [const Color(0xFFF8FAFC), const Color(0xFFE2E8F0)],
                  ),
                ),
              ),
            ),

            _blob(
              top: -100,
              left: -50,
              size: 400,
              color: brandColor.withValues(alpha: 0.15),
              controller: _bgController,
              offset: 0,
            ),
            _blob(
              bottom: -150,
              right: -80,
              size: 450,
              color: AppTheme.liquidPrimaryEnd.withValues(alpha: 0.12),
              controller: _bgController,
              offset: 0.5,
            ),
            _blob(
              top: 200,
              right: -100,
              size: 300,
              color: AppTheme.tenantTeal.withValues(alpha: 0.08),
              controller: _bgController,
              offset: 0.25,
            ),
          ],
        );
      },
    );
  }

  Widget _buildBrandHeader(bool isDark, Color brand) {
    return Column(
      children: [
        Hero(
          tag: 'app_logo',
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  brand.withValues(alpha: 0.2),
                  brand.withValues(alpha: 0.0),
                ],
              ),
            ),
            child: Image.asset(
              'assets/images/rentdone_logo.png',
              width: 80,
              height: 80,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.person_add_rounded, size: 60, color: brand),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'RENTDONE',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: 3.0,
          ),
        ),
      ],
    );
  }

  Widget _buildVerifiedBadge(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.infoBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.infoBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.verified_user_rounded,
            size: 18,
            color: AppTheme.infoBlue,
          ),
          const SizedBox(width: 10),
          Text(
            '+91 ${widget.phoneNumber}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppTheme.infoBlue,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
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
      style: const TextStyle(fontWeight: FontWeight.w500),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: OwnerDashboardColors.textSecondary(
            context,
          ).withValues(alpha: 0.7),
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Icon(
          icon,
          size: 22,
          color: OwnerDashboardColors.brandPrimary(context),
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: OwnerDashboardColors.brandPrimary(context),
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(bool isLoading, Color brandColor) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: brandColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: GlassButton(
        onPressed: _onSignupPressed,
        label: 'CREATE ACCOUNT',
        isPrimary: true,
        isLoading: isLoading,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 20),
        textStyle: const TextStyle(
          letterSpacing: 1.5,
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildFooter(Color textSecondary, Color brandColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(color: textSecondary, fontWeight: FontWeight.w500),
        ),
        GestureDetector(
          onTap: () => context.go(
            '/login?role=${widget.selectedRole.name}&phone=${widget.phoneNumber}',
          ),
          child: Text(
            'Sign In',
            style: TextStyle(
              color: brandColor,
              fontWeight: FontWeight.w900,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _errorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Colors.redAccent,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.redAccent,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
    required AnimationController controller,
    required double offset,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final t = (controller.value + offset) % 1.0;
          final dx = 30 * (1.0 + 0.5 * (1.0 - t));
          final dy = 20 * (1.0 + 0.3 * t);

          return Transform.translate(
            offset: Offset(
              dx * (1.0 - (t * 2 - 1.0).abs()),
              dy * (t * 2 - 1.0),
            ),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [color, color.withValues(alpha: 0)],
                ),
              ),
            ),
          );
        },
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

  String? _validateConfirmPassword(String? input) {
    if (input == null || input.isEmpty) return 'Confirm password is required';
    if (input != _passwordController.text) return 'Passwords do not match';
    return null;
  }

  Future<void> _onSignupPressed() async {
    if (!_formKey.currentState!.validate()) return;
    final notifier = ref.read(authProvider.notifier);
    try {
      final user = await notifier.continueWithEmail(
        phone: widget.phoneNumber,
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      if (UserRoleX.tryParse(user.role) == UserRole.owner) {
        context.goNamed('ownerDashboard');
      } else {
        context.goNamed('tenantDashboard');
      }
    } catch (_) {}
  }
}
