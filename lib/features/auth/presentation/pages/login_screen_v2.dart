import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/core/constants/user_role.dart';
import 'package:rentdone/features/auth/presentation/providers/auth_provider.dart';
import 'package:rentdone/features/auth/presentation/widgets/forgot_password_dialog.dart';
import 'package:rentdone/features/auth/presentation/widgets/auth_aurora_background.dart';

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
  late final AnimationController _entryCtrl;
  bool _obscure = true;
  bool _emailFocus = false;
  bool _passFocus = false;

  static const _brand = AppTheme.primaryBlue;
  static const _brandDark = AppTheme.primaryHoverBlue;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController();
    _passCtrl = TextEditingController();
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 20))
      ..repeat();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
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
    _entryCtrl.dispose();
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
          AuthAuroraBackground(controller: _bgCtrl, isDark: isDark),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(isDark),
                Expanded(child: _buildGlassCard(isDark, auth)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final isOwner = widget.selectedRole == UserRole.owner;
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.26,
      child: FadeTransition(
        opacity: CurvedAnimation(
            parent: _entryCtrl, curve: const Interval(0.0, 0.45)),
        child: Column(
          children: [
            const SizedBox(height: 12),
            _buildChip(isOwner),
            const Spacer(),
            const Text(
              'Welcome back',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Sign in to continue to RentDone',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.70),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(bool isOwner) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
            color: Colors.white.withValues(alpha: 0.20), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
              isOwner ? Icons.domain_rounded : Icons.home_rounded,
              size: 16,
              color: Colors.white),
          const SizedBox(width: 6),
          Text(
            isOwner ? 'Owner' : 'Tenant',
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: Colors.white,
                letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassCard(bool isDark, dynamic auth) {
    return FadeTransition(
      opacity: CurvedAnimation(
          parent: _entryCtrl, curve: const Interval(0.15, 0.65)),
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
            .animate(CurvedAnimation(
                parent: _entryCtrl,
                curve:
                    const Interval(0.15, 0.65, curve: Curves.easeOutCubic))),
        child: ClipRRect(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark
                    ? AppTheme.darkCard.withValues(alpha: 0.78)
                    : Colors.white.withValues(alpha: 0.86),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(
                  color: _brand.withValues(alpha: isDark ? 0.14 : 0.10),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _brand
                        .withValues(alpha: isDark ? 0.10 : 0.06),
                    blurRadius: 44,
                    offset: const Offset(0, 18),
                  ),
                  BoxShadow(
                    color:
                        Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 32, 28, 36),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPhoneBadge(isDark),
                      const SizedBox(height: 22),
                      _buildGoogleButton(isDark, auth.isLoading),
                      const SizedBox(height: 18),
                      _buildDivider(isDark),
                      const SizedBox(height: 18),
                      _buildField(
                        controller: _emailCtrl,
                        label: 'Email Address',
                        icon: Icons.alternate_email_rounded,
                        keyboard: TextInputType.emailAddress,
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'Email is required';
                          if (!RegExp(
                                  r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
                              .hasMatch(s)) return 'Enter a valid email';
                          return null;
                        },
                        isDark: isDark,
                        hasFocus: _emailFocus,
                        onFocusChange: (f) =>
                            setState(() => _emailFocus = f),
                      ),
                      const SizedBox(height: 14),
                      _buildField(
                        controller: _passCtrl,
                        label: 'Password',
                        icon: Icons.lock_outline_rounded,
                        obscure: _obscure,
                        validator: (v) {
                          if (v == null || v.isEmpty)
                            return 'Password is required';
                          if (v.length < 6)
                            return 'At least 6 characters';
                          return null;
                        },
                        isDark: isDark,
                        hasFocus: _passFocus,
                        onFocusChange: (f) =>
                            setState(() => _passFocus = f),
                        suffix: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            size: 20,
                            color: isDark
                                ? AppTheme.darkTextSecondary
                                : AppTheme.lightTextSecondary,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: auth.isLoading
                              ? null
                              : () => showForgotPasswordDialog(
                                  context: context,
                                  ref: ref,
                                  initialEmail: _emailCtrl.text,
                                  onEmailSynced: (e) =>
                                      _emailCtrl.text = e),
                          style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4, vertical: 2)),
                          child: const Text('Forgot Password?',
                              style: TextStyle(
                                  color: _brand,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ),
                      ),
                      if (auth.errorMessage != null) ...[
                        _buildError(auth.errorMessage!),
                        const SizedBox(height: 14),
                      ],
                      const SizedBox(height: 4),
                      _buildSignInButton(auth.isLoading),
                      const SizedBox(height: 24),
                      _buildFooter(isDark),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneBadge(bool isDark) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.infoBlue.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: AppTheme.infoBlue.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.phone_android_rounded,
              size: 16, color: AppTheme.infoBlue),
          const SizedBox(width: 8),
          Text(
            '+91 ${widget.phoneNumber}',
            style: const TextStyle(
                color: AppTheme.infoBlue,
                fontWeight: FontWeight.w800,
                fontSize: 13,
                letterSpacing: 0.4),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.verified_rounded,
              size: 14, color: AppTheme.successGreen),
        ],
      ),
    );
  }

  Widget _buildGoogleButton(bool isDark, bool loading) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark
            ? Colors.white.withValues(alpha: 0.06)
            : Colors.white,
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.10)
              : _brand.withValues(alpha: 0.10),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: isDark ? 0.18 : 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : _onGoogle,
          borderRadius: BorderRadius.circular(24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: _brand, strokeWidth: 2.5))
              else ...[
                Container(
                  width: 24,
                  height: 24,
                  decoration: const BoxDecoration(
                      shape: BoxShape.circle, color: Color(0xFF4285F4)),
                  child: const Center(
                      child: Text('G',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.w900))),
                ),
                const SizedBox(width: 12),
                Text(
                  'Continue with Google',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isDark
                          ? Colors.white
                          : AppTheme.lightTextPrimary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    final c = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);
    final muted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    return Row(
      children: [
        Expanded(child: Divider(color: c, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text('or use email',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                  color: muted)),
        ),
        Expanded(child: Divider(color: c, thickness: 1)),
      ],
    );
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
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: hasFocus
              ? [
                  BoxShadow(
                      color: _brand.withValues(alpha: 0.15),
                      blurRadius: 22,
                      offset: const Offset(0, 4)),
                ]
              : [],
        ),
        child: TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboard,
          validator: validator,
          style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : AppTheme.lightTextPrimary),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: TextStyle(
              color: hasFocus
                  ? _brand
                  : (isDark
                      ? AppTheme.darkTextSecondary
                      : AppTheme.lightTextSecondary),
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            prefixIcon: Icon(icon,
                size: 22,
                color: hasFocus
                    ? _brand
                    : (isDark
                        ? AppTheme.darkTextSecondary
                        : AppTheme.lightTextSecondary)),
            suffixIcon: suffix,
            filled: true,
            fillColor: isDark
                ? (hasFocus
                    ? _brand.withValues(alpha: 0.06)
                    : Colors.white.withValues(alpha: 0.04))
                : (hasFocus
                    ? _brand.withValues(alpha: 0.03)
                    : Colors.white.withValues(alpha: 0.65)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : _brand.withValues(alpha: 0.12),
                width: 1.2,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide:
                  const BorderSide(color: _brand, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(
                  color: AppTheme.errorRed, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(
                  color: AppTheme.errorRed, width: 2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(String msg) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppTheme.errorRed.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppTheme.errorRed, size: 18),
          const SizedBox(width: 12),
          Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      color: AppTheme.errorRed,
                      fontSize: 13,
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Widget _buildSignInButton(bool loading) {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_brand, _brandDark]),
        boxShadow: [
          BoxShadow(
              color: _brand.withValues(alpha: 0.35),
              blurRadius: 22,
              offset: const Offset(0, 10)),
          BoxShadow(
              color: _brand.withValues(alpha: 0.12),
              blurRadius: 6,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : _onEmail,
          borderRadius: BorderRadius.circular(24),
          splashColor: Colors.white.withValues(alpha: 0.10),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Sign In',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5)),
                      SizedBox(width: 8),
                      Icon(Icons.arrow_forward_rounded,
                          color: Colors.white, size: 20),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    final sub = isDark
        ? AppTheme.darkTextSecondary
        : AppTheme.lightTextSecondary;
    final muted =
        isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Don't have an account? ",
                style: TextStyle(
                    color: sub,
                    fontWeight: FontWeight.w500,
                    fontSize: 14)),
            GestureDetector(
              onTap: () => context.go(
                  '/signup?role=${widget.selectedRole.name}&phone=${widget.phoneNumber}'),
              child: const Text(
                'Create Account',
                style: TextStyle(
                    color: _brand,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    decoration: TextDecoration.underline),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 12, color: muted),
            const SizedBox(width: 4),
            Text(
              '256-bit encrypted · Your data is safe with us',
              style: TextStyle(
                  fontSize: 11,
                  color: muted,
                  fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _onGoogle() async {
    final n = ref.read(authProvider.notifier);
    try {
      final user =
          await n.continueWithGoogle(phone: widget.phoneNumber);
      if (!mounted) return;
      _navigate(
          UserRoleX.tryParse(user.role) ?? widget.selectedRole);
    } catch (e, st) {
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
      _navigate(
          UserRoleX.tryParse(user.role) ?? widget.selectedRole);
    } catch (e, st) {
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
