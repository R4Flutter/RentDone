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
import 'package:rentdone/shared/widgets/app_loading_indicator.dart';

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
      duration: const Duration(seconds: 18),
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
    final authNotifier = ref.read(authProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isOwner = widget.selectedRole == UserRole.owner;

    return Scaffold(
      backgroundColor: OwnerDashboardColors.pageBackground(context),
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, _) {
          final shift = _bgController.value;
          final begin = Alignment(-1 + (shift * 0.4), -1 + (shift * 0.15));
          final end = Alignment(1 - (shift * 0.25), 1 - (shift * 0.1));

          final bgColors = isDark
              ? const [Color(0xFF0C1224), Color(0xFF111B33), Color(0xFF141F3B)]
              : const [Color(0xFFEEF3FF), Color(0xFFE8F0FF), Color(0xFFF8FAFF)];

          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: begin,
                      end: end,
                      colors: bgColors,
                    ),
                  ),
                ),
              ),
              _liquidBlob(
                top: -110,
                left: -70,
                size: 290,
                color: isDark
                    ? const Color(0x404F7CFF)
                    : const Color(0x664F7CFF),
                travel: 18 * shift,
              ),
              _liquidBlob(
                top: 180,
                right: -100,
                size: 240,
                color: isDark
                    ? const Color(0x336FA8FF)
                    : const Color(0x556FA8FF),
                travel: -14 * shift,
              ),
              _liquidBlob(
                bottom: -120,
                left: 30,
                size: 320,
                color: isDark
                    ? const Color(0x2E5A90FF)
                    : const Color(0x405A90FF),
                travel: 22 * shift,
              ),
              SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildTopBrandSection(
                            context,
                            theme,
                            isOwner,
                            isDark,
                          ),
                          const SizedBox(height: 24),
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                            builder: (context, value, child) {
                              return Opacity(
                                opacity: value,
                                child: Transform.translate(
                                  offset: Offset(0, (1 - value) * 18),
                                  child: child,
                                ),
                              );
                            },
                            child: _buildLoginCard(
                              context,
                              authState,
                              authNotifier,
                            ),
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

  Widget _buildTopBrandSection(
    BuildContext context,
    ThemeData theme,
    bool isOwner,
    bool isDark,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: 0.68,
            child: Image.asset(
              'assets/images/rentdone_logo.png',
              width: 152,
              height: 152,
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => Icon(
                isOwner ? Icons.business_outlined : Icons.home_work_outlined,
                size: 50,
                color: AppTheme.liquidPrimaryEnd,
              ),
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -10),
          child: Text(
            'RentDone',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 29,
              fontWeight: FontWeight.w800,
              color: isDark ? AppTheme.pureWhite : AppColors.black,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Property Management Simplified',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: OwnerDashboardColors.managePropertiesHeaderSecondary(
              context,
            ),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(
    BuildContext context,
    AuthState authState,
    AuthNotifier authNotifier,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [Colors.white.withAlpha(20), Colors.white.withAlpha(10)]
                  : [Colors.white.withAlpha(192), Colors.white.withAlpha(152)],
            ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppTheme.liquidPrimaryStart.withAlpha(isDark ? 96 : 70),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.liquidShadow.withAlpha(isDark ? 70 : 40),
                blurRadius: 24,
                offset: const Offset(0, 8),
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
                  'Sign In',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppTheme.pureWhite : AppColors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Secure owner and tenant access powered by Firebase',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: OwnerDashboardColors.managePropertiesHeaderSecondary(
                      context,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppTheme.infoBlue.withValues(alpha: 0.12),
                    border: Border.all(
                      color: AppTheme.infoBlue.withValues(alpha: 0.26),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_rounded,
                        size: 16,
                        color: AppTheme.infoBlue,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Verified number: +91 ${widget.phoneNumber}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: AppTheme.infoBlue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _buildInput(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) => authNotifier.clearError(),
                  validator: _validateEmail,
                  label: 'Email Address',
                  icon: Icons.alternate_email_rounded,
                ),
                const SizedBox(height: 14),
                _buildInput(
                  controller: _passwordController,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  obscureText: _obscurePassword,
                  onChanged: (_) => authNotifier.clearError(),
                  validator: _validatePassword,
                  onFieldSubmitted: (_) {
                    if (!authState.isLoading) {
                      _onEmailPressed();
                    }
                  },
                  label: 'Password',
                  icon: Icons.lock_rounded,
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
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: authState.isLoading
                        ? null
                        : () => showForgotPasswordDialog(
                            context: context,
                            ref: ref,
                            initialEmail: _emailController.text,
                            onEmailSynced: (email) {
                              _emailController.text = email;
                            },
                          ),
                    style: TextButton.styleFrom(
                      foregroundColor: isDark
                          ? AppTheme.pureWhite
                          : AppTheme.liquidPrimaryEnd,
                    ),
                    child: const Text('Forgot password?'),
                  ),
                ),
                if (authState.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  _errorCard(authState.errorMessage!),
                ],
                const SizedBox(height: 16),
                _primaryButton(authState),
                const SizedBox(height: 16),
                _secondaryButton(authState),
                const SizedBox(height: 24),
                Center(
                  child: TextButton(
                    onPressed: authState.isLoading
                        ? null
                        : () {
                            if (widget.selectedRole == UserRole.owner) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Owner accounts are provisioned by support. Please sign in or contact support.',
                                  ),
                                ),
                              );
                              return;
                            }

                            context.go(
                              '/signup?role=${widget.selectedRole.name}&phone=${widget.phoneNumber}',
                            );
                          },
                    style: TextButton.styleFrom(
                      foregroundColor: isDark
                          ? AppTheme.pureWhite
                          : AppColors.black,
                    ),
                    child: Text(
                      widget.selectedRole == UserRole.owner
                          ? 'Need owner access? Contact support'
                          : 'Create account',
                      style: TextStyle(fontWeight: FontWeight.w700),
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

  Widget _buildInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required FormFieldValidator<String> validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onFieldSubmitted,
    bool obscureText = false,
    Widget? suffix,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onFieldSubmitted: onFieldSubmitted,
      obscureText: obscureText,
      validator: validator,
      decoration: _inputDecoration(label: label, icon: icon, suffix: suffix),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
    Widget? suffix,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppTheme.liquidPrimaryStart.withAlpha(46)),
    );

    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppTheme.liquidPrimaryEnd.withAlpha(170)),
    );

    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppTheme.liquidPrimaryEnd),
      suffixIcon: suffix,
      filled: true,
      fillColor: isDark
          ? AppTheme.pureWhite.withAlpha(26)
          : AppTheme.pureWhite.withAlpha(110),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
      enabledBorder: border,
      focusedBorder: focusedBorder,
      errorBorder: border,
      focusedErrorBorder: focusedBorder,
      errorStyle: const TextStyle(
        color: AppTheme.errorRed,
        fontSize: 11,
        height: 1.1,
        fontWeight: FontWeight.w500,
      ),
      helperStyle: TextStyle(
        color: OwnerDashboardColors.managePropertiesHeaderSecondary(context),
        fontSize: 11,
      ),
    );
  }

  Widget _primaryButton(AuthState authState) {
    const gradient = LinearGradient(
      colors: [Color(0xFF4F7CFF), Color(0xFF6FA8FF)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return SizedBox(
      height: 58,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Material(
          color: Colors.transparent,
          child: Ink(
            decoration: BoxDecoration(
              gradient: gradient,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF4F7CFF).withAlpha(75),
                  blurRadius: 18,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: InkWell(
              onTap: authState.isLoading ? null : _onEmailPressed,
              child: Center(
                child: authState.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: AppLoadingIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.white,
                          ),
                        ),
                      )
                    : const Text(
                        'Sign In',
                        style: TextStyle(
                          color: AppColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _secondaryButton(AuthState authState) {
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: authState.isLoading ? null : _onGooglePressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: AppTheme.pureWhite.withAlpha(90),
          side: BorderSide(color: AppTheme.liquidPrimaryStart.withAlpha(80)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.pureWhite,
                border: Border.all(
                  color: AppTheme.liquidPrimaryStart.withAlpha(80),
                ),
              ),
              child: const Text(
                'G',
                style: TextStyle(
                  color: Color(0xFF4285F4),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Continue with Google',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _errorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorRed.withAlpha(80)),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: AppTheme.errorRed,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _liquidBlob({
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
        offset: Offset(travel, -travel * 0.4),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(color: color, blurRadius: 70, spreadRadius: 6),
            ],
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
    if (value.length < 12) return 'Password must be at least 12 characters';
    return null;
  }

  Future<void> _onGooglePressed() async {
    final notifier = ref.read(authProvider.notifier);

    try {
      final user = await notifier.continueWithGoogle(phone: widget.phoneNumber);
      if (!mounted) return;
      _navigateByRole(UserRoleX.tryParse(user.role) ?? widget.selectedRole);
    } catch (_) {
      // Error state is managed by auth notifier.
    }
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
    } catch (_) {
      // Error state is managed by auth notifier.
    }
  }

  void _navigateByRole(UserRole role) {
    if (role == UserRole.owner) {
      context.goNamed('ownerDashboard');
      return;
    }
    context.goNamed('tenantDashboard');
  }
}
