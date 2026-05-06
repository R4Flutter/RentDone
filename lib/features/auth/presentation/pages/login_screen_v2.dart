import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/core/constants/user_role.dart';
import 'package:rentdone/features/auth/presentation/providers/auth_provider.dart';
import 'package:rentdone/features/auth/presentation/widgets/forgot_password_dialog.dart';
import 'package:rentdone/features/auth/presentation/pages/phone_capture_screen_v2.dart';

class LoginPageV2 extends ConsumerStatefulWidget {
  const LoginPageV2({
    super.key,
    required this.selectedRole,
    required this.phoneNumber,
  });
  final UserRole selectedRole;
  final String phoneNumber;

  @override
  ConsumerState<LoginPageV2> createState() => _LoginPageV2State();
}

class _LoginPageV2State extends ConsumerState<LoginPageV2>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passCtrl;
  late final AnimationController _bgCtrl;
  late final AnimationController _pulseCtrl;
  bool _obscure = true;
  bool _emailFocus = false;
  bool _passFocus = false;

  static const _brand = AppTheme.darkPrimaryBlue;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController();
    _passCtrl = TextEditingController();
    _bgCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final n = ref.read(authProvider.notifier);
      n.setSelectedRole(widget.selectedRole);
      n.setMode(registerMode: false);
    });
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _pulseCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          AuthMeshBackground(controller: _bgCtrl, isDark: isDark),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    children: [
                      _buildHeader(isDark)
                          .animate()
                          .fadeIn(duration: 700.ms)
                          .slideY(begin: -0.3, end: 0, curve: Curves.easeOutCubic),
                      const SizedBox(height: 28),
                      _buildCard(isDark, auth)
                          .animate()
                          .fadeIn(delay: 150.ms, duration: 600.ms)
                          .scale(begin: const Offset(0.96, 0.96), curve: Curves.easeOutCubic),
                      const SizedBox(height: 22),
                      _buildFooter(isDark)
                          .animate()
                          .fadeIn(delay: 1100.ms),
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

  Widget _buildHeader(bool isDark) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseCtrl,
          builder: (_, child) => Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_brand, Color(0xFF2563EB)],
              ),
              boxShadow: [
                BoxShadow(
                  color: _brand.withValues(alpha: 0.15 + 0.10 * _pulseCtrl.value),
                  blurRadius: 28 + 14 * _pulseCtrl.value,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: child,
          ),
          child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 42),
        ),
        const SizedBox(height: 16),
        ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [_brand, Color(0xFF60A5FA), Color(0xFF2563EB)],
          ).createShader(b),
          child: const Text(
            'RENTDONE',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 5),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Welcome back',
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withValues(alpha: isDark ? 0.50 : 0.55),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(bool isDark, dynamic auth) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [Colors.white.withValues(alpha: 0.08), Colors.white.withValues(alpha: 0.04)]
                  : [Colors.white.withValues(alpha: 0.88), Colors.white.withValues(alpha: 0.72)],
            ),
            border: Border.all(color: _brand.withValues(alpha: isDark ? 0.25 : 0.15), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: _brand.withValues(alpha: isDark ? 0.12 : 0.08),
                blurRadius: 40,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCardTitle(isDark),
                const SizedBox(height: 24),
                _buildPhoneBadge(isDark),
                const SizedBox(height: 24),
                _buildField(
                  controller: _emailCtrl,
                  label: 'Email Address',
                  icon: Icons.alternate_email_rounded,
                  keyboard: TextInputType.emailAddress,
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'Email is required';
                    // BUG-06 fix: proper email regex
                    final emailRegex = RegExp(
                      r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
                    );
                    if (!emailRegex.hasMatch(s)) return 'Enter a valid email address';
                    return null;
                  },
                  isDark: isDark,
                  hasFocus: _emailFocus,
                  onFocusChange: (f) => setState(() => _emailFocus = f),
                ).animate().fadeIn(delay: 450.ms).slideX(begin: -0.08),
                const SizedBox(height: 16),
                _buildField(
                  controller: _passCtrl,
                  label: 'Password',
                  icon: Icons.lock_outline_rounded,
                  obscure: _obscure,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'At least 6 characters';
                    return null;
                  },
                  isDark: isDark,
                  hasFocus: _passFocus,
                  onFocusChange: (f) => setState(() => _passFocus = f),
                  suffix: IconButton(
                    icon: Icon(
                      _obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                      size: 20,
                      color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                    ),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ).animate().fadeIn(delay: 550.ms).slideX(begin: 0.08),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: auth.isLoading ? null : () => _onForgot(context),
                    style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2)),
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(color: _brand, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                ).animate().fadeIn(delay: 620.ms),
                if (auth.errorMessage != null) ...[
                  _buildError(auth.errorMessage!).animate().shake(duration: 400.ms),
                  const SizedBox(height: 14),
                ],
                const SizedBox(height: 4),
                _buildSignInButton(auth.isLoading)
                    .animate()
                    .fadeIn(delay: 700.ms)
                    .scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOutBack),
                const SizedBox(height: 22),
                _buildDivider(isDark).animate().fadeIn(delay: 800.ms),
                const SizedBox(height: 22),
                _buildGoogleButton(isDark, auth.isLoading)
                    .animate()
                    .fadeIn(delay: 900.ms)
                    .slideY(begin: 0.1),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardTitle(bool isDark) {
    final textColor = isDark ? Colors.white : AppTheme.lightTextPrimary;
    final sub = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _brand.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.login_rounded, color: _brand, size: 20),
            ),
            const SizedBox(width: 10),
            Text('Sign In', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textColor)),
          ],
        ).animate().fadeIn(delay: 200.ms).moveY(begin: 8, end: 0),
        const SizedBox(height: 6),
        Text('Enter your credentials to continue', style: TextStyle(fontSize: 13, color: sub), textAlign: TextAlign.center)
            .animate()
            .fadeIn(delay: 300.ms),
      ],
    );
  }

  Widget _buildPhoneBadge(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.infoBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.infoBlue.withValues(alpha: 0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.verified_user_rounded, size: 16, color: AppTheme.infoBlue),
          const SizedBox(width: 8),
          Text(
            '+91 ${widget.phoneNumber}',
            style: const TextStyle(color: AppTheme.infoBlue, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 350.ms).scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    required bool hasFocus,
    required ValueChanged<bool> onFocusChange,
    bool obscure = false,
    TextInputType? keyboard,
    required FormFieldValidator<String> validator,
    Widget? suffix,
  }) {
    return Focus(
      onFocusChange: onFocusChange,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: hasFocus
              ? [BoxShadow(color: _brand.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 4))]
              : [],
        ),
        child: TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboard,
          validator: validator,
          style: TextStyle(fontWeight: FontWeight.w600, color: isDark ? Colors.white : AppTheme.lightTextPrimary),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: hasFocus ? _brand : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            prefixIcon: Icon(icon, size: 20, color: hasFocus ? _brand : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary)),
            suffixIcon: suffix,
            filled: true,
            fillColor: isDark
                ? (hasFocus ? _brand.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.05))
                : (hasFocus ? _brand.withValues(alpha: 0.04) : AppTheme.lightSurface),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: isDark ? Colors.white.withValues(alpha: 0.10) : AppTheme.lightBorder,
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: _brand, width: 2.0),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.errorRed, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.errorRed, width: 2.0),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(msg, style: const TextStyle(color: AppTheme.errorRed, fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildSignInButton(bool loading) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [_brand, Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: _brand.withValues(alpha: 0.38), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : _onEmail,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withValues(alpha: 0.12),
          child: Center(
            child: loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Sign In', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    final c = isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.10);
    return Row(
      children: [
        Expanded(child: Divider(color: c, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'OR',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 2,
                color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted),
          ),
        ),
        Expanded(child: Divider(color: c, thickness: 1)),
      ],
    );
  }

  Widget _buildGoogleButton(bool isDark, bool loading) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.12) : AppTheme.lightBorder,
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : _onGoogle,
          borderRadius: BorderRadius.circular(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Google "G" icon using colored text
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: const Text(
                  'G',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF4285F4),
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Continue with Google',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    final sub = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Don't have an account? ", style: TextStyle(color: sub, fontWeight: FontWeight.w500, fontSize: 14)),
        GestureDetector(
          onTap: () => context.go('/signup?role=${widget.selectedRole.name}&phone=${widget.phoneNumber}'),
          child: const Text(
            'Create Account',
            style: TextStyle(color: _brand, fontWeight: FontWeight.w800, fontSize: 14, decoration: TextDecoration.underline),
          ),
        ),
      ],
    );
  }

  void _onForgot(BuildContext ctx) {
    showForgotPasswordDialog(
      context: ctx,
      ref: ref,
      initialEmail: _emailCtrl.text,
      onEmailSynced: (e) => _emailCtrl.text = e,
    );
  }

  Future<void> _onGoogle() async {
    final n = ref.read(authProvider.notifier);
    try {
      final user = await n.continueWithGoogle(phone: widget.phoneNumber);
      if (!mounted) return;
      _navigate(UserRoleX.tryParse(user.role) ?? widget.selectedRole);
    } catch (e, st) {
      // BUG-02 fix: error already shown via authState.errorMessage. Log for crash reporting.
      debugPrint('Google login error: $e\n$st');
    }
  }

  Future<void> _onEmail() async {
    if (!_formKey.currentState!.validate()) return;
    final n = ref.read(authProvider.notifier);
    try {
      final user = await n.continueWithEmail(
        phone: widget.phoneNumber,
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (!mounted) return;
      _navigate(UserRoleX.tryParse(user.role) ?? widget.selectedRole);
    } catch (e, st) {
      // BUG-02 fix: error already shown via authState.errorMessage. Log for crash reporting.
      debugPrint('Email login error: $e\n$st');
    }
  }

  void _navigate(UserRole role) {
    if (role == UserRole.owner) {
      context.goNamed('ownerDashboard');
    } else {
      context.goNamed('tenantDashboard');
    }
  }
}
