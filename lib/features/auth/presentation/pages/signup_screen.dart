import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/core/constants/user_role.dart';
import 'package:rentdone/features/auth/presentation/providers/auth_provider.dart';

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
  bool _isLoading = false;
  String? _authError;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    )..repeat(reverse: true);

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
    final theme = Theme.of(context);
    final isDark = OwnerDashboardColors.isDark(context);

    return Scaffold(
      backgroundColor: OwnerDashboardColors.pageBackground(context),
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, _) {
          final shift = _bgController.value;
          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: OwnerDashboardColors.ownerPageBackgroundGradient(
                      context,
                    ),
                  ),
                ),
              ),
              _blob(
                top: -100,
                left: -50,
                size: 230,
                color: OwnerDashboardColors.ownerTopBlobColor(context),
                travel: 16 * shift,
              ),
              _blob(
                bottom: -120,
                right: -70,
                size: 280,
                color: OwnerDashboardColors.ownerBottomBlobColor(context),
                travel: -20 * shift,
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    22,
                    22,
                    22,
                    24 + MediaQuery.of(context).viewInsets.bottom,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: _isLoading
                                    ? null
                                    : () => context.goNamed('roleSelection'),
                                icon: Icon(
                                  Icons.arrow_back_rounded,
                                  color: OwnerDashboardColors.textPrimary(
                                    context,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Create Account',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: OwnerDashboardColors.textPrimary(
                                      context,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _brandBlock(theme, isDark),
                          const SizedBox(height: 18),
                          _formCard(theme, isDark),
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

  Widget _brandBlock(ThemeData theme, bool isDark) {
    return Column(
      children: [
        Image.asset(
          'assets/images/rentdone_logo.png',
          width: 92,
          height: 92,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => Icon(
            Icons.apartment_rounded,
            size: 44,
            color: OwnerDashboardColors.brandPrimary(context),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'RentDone',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: OwnerDashboardColors.textPrimary(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Professional onboarding for secure property operations',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: OwnerDashboardColors.textSecondary(context),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: OwnerDashboardColors.brandPrimary(
              context,
            ).withValues(alpha: isDark ? 0.22 : 0.12),
            border: Border.all(
              color: OwnerDashboardColors.brandPrimary(
                context,
              ).withValues(alpha: isDark ? 0.40 : 0.24),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.verified_rounded,
                size: 16,
                color: OwnerDashboardColors.brandPrimary(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Verified number: +91 ${widget.phoneNumber}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: OwnerDashboardColors.brandPrimary(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _formCard(ThemeData theme, bool isDark) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [
                      Colors.white.withValues(alpha: 0.12),
                      OwnerDashboardColors.brandPrimary(
                        context,
                      ).withValues(alpha: 0.14),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.94),
                      OwnerDashboardColors.brandPrimary(
                        context,
                      ).withValues(alpha: 0.12),
                    ],
            ),
            border: Border.all(
              color: OwnerDashboardColors.brandPrimary(
                context,
              ).withValues(alpha: isDark ? 0.34 : 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: isDark ? 0.30 : 0.12),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Set Your Credentials',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: OwnerDashboardColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 14),
                _liquidInput(
                  controller: _emailController,
                  label: 'Email Address',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                ),
                const SizedBox(height: 12),
                _liquidInput(
                  controller: _passwordController,
                  label: 'Password',
                  icon: Icons.lock_outline_rounded,
                  textInputAction: TextInputAction.next,
                  obscureText: _obscurePassword,
                  validator: _validatePassword,
                  suffix: IconButton(
                    onPressed: () {
                      setState(() => _obscurePassword = !_obscurePassword);
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _liquidInput(
                  controller: _confirmPasswordController,
                  label: 'Confirm Password',
                  icon: Icons.shield_rounded,
                  textInputAction: TextInputAction.done,
                  obscureText: _obscureConfirmPassword,
                  validator: _validateConfirmPassword,
                  onFieldSubmitted: (_) {
                    if (!_isLoading) _onSignupPressed();
                  },
                  suffix: IconButton(
                    onPressed: () {
                      setState(
                        () =>
                            _obscureConfirmPassword = !_obscureConfirmPassword,
                      );
                    },
                    icon: Icon(
                      _obscureConfirmPassword
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                    ),
                  ),
                ),
                if (_authError != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    _authError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.errorRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: OwnerDashboardColors.brandPrimary(
                        context,
                      ),
                      foregroundColor: isDark
                          ? AppColors.white
                          : AppColors.cFF0F172A,
                    ),
                    onPressed: _isLoading ? null : _onSignupPressed,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.person_add_alt_1_rounded),
                    label: Text(
                      _isLoading ? 'Creating Account...' : 'Create Account',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Center(
                  child: TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => context.go(
                            '/login?role=${widget.selectedRole.name}&phone=${widget.phoneNumber}',
                          ),
                    child: const Text('Already have an account? Sign In'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _liquidInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    FormFieldValidator<String>? validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    ValueChanged<String>? onFieldSubmitted,
    bool obscureText = false,
    Widget? suffix,
  }) {
    final isDark = OwnerDashboardColors.isDark(context);

    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onFieldSubmitted: onFieldSubmitted,
      obscureText: obscureText,
      style: TextStyle(color: OwnerDashboardColors.textPrimary(context)),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: OwnerDashboardColors.textSecondary(context),
        ),
        prefixIcon: Icon(
          icon,
          color: OwnerDashboardColors.brandPrimary(context),
        ),
        suffixIcon: suffix,
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.white.withValues(alpha: 0.78),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: OwnerDashboardColors.border(context)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: OwnerDashboardColors.border(context)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: OwnerDashboardColors.brandPrimary(context),
            width: 1.2,
          ),
        ),
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
        offset: Offset(travel, -travel * 0.45),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [BoxShadow(color: color, blurRadius: 70)],
          ),
        ),
      ),
    );
  }

  String? _validateEmail(String? input) {
    final value = (input ?? '').trim();
    if (value.isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!emailRegex.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? input) {
    final value = input ?? '';
    if (value.isEmpty) return 'Password is required';
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateConfirmPassword(String? input) {
    final value = input ?? '';
    if (value.isEmpty) return 'Confirm password is required';
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _onSignupPressed() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _authError = null;
    });

    try {
      final notifier = ref.read(authProvider.notifier);
      await notifier.continueWithEmail(
        phone: widget.phoneNumber,
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account created. Verification link sent. Check inbox/spam and verify your email to continue.',
          ),
        ),
      );

      final verifyUri = Uri(
        path: '/verify-email-code',
        queryParameters: {
          'role': widget.selectedRole.name,
          'phone': widget.phoneNumber,
          'email': _emailController.text.trim().toLowerCase(),
        },
      );
      context.go(verifyUri.toString());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _authError = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    final raw = error.toString().replaceFirst('Exception: ', '').trim();
    if (raw.isEmpty) {
      return 'Could not create account. Please try again.';
    }
    return raw;
  }
}
