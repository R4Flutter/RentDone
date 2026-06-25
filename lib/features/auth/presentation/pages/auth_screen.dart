import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/core/constants/user_role.dart';
import 'package:rentdone/features/auth/presentation/providers/auth_provider.dart';
import 'package:rentdone/features/auth/presentation/widgets/forgot_password_dialog.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({
    super.key,
    required this.selectedRole,
    required this.phoneNumber,
  });
  final UserRole selectedRole;
  final String phoneNumber;

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;
  late final TabController _tabCtrl;

  final _loginKey = GlobalKey<FormState>();
  final _signupKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;
  late final TextEditingController _passCtrl;
  late final TextEditingController _confirmCtrl;

  bool _obscurePass = true;
  bool _obscureConfirm = true;
  bool _emailFocus = false;
  bool _passFocus = false;
  bool _confirmFocus = false;
  int _currentTab = 0;

  static const _brand = AppTheme.primaryBlue;
  static const _brandDark = AppTheme.primaryHoverBlue;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (_tabCtrl.indexIsChanging) return;
      setState(() => _currentTab = _tabCtrl.index);
      ref.read(authProvider.notifier).setMode(registerMode: _tabCtrl.index == 1);
      ref.read(authProvider.notifier).clearError();
    });
    _emailCtrl = TextEditingController();
    _passCtrl = TextEditingController();
    _confirmCtrl = TextEditingController();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _entryCtrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final n = ref.read(authProvider.notifier);
      n.setSelectedRole(widget.selectedRole);
      n.setMode(registerMode: _tabCtrl.index == 1);
    });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _entryCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          _buildHeaderSection(isDark, screenHeight),
          Expanded(
            child: _buildFormCard(isDark, auth),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection(bool isDark, double screenHeight) {
    final isOwner = widget.selectedRole == UserRole.owner;
    final accent = isOwner ? AppTheme.primaryBlue : AppTheme.tenantTeal;

    return SizedBox(
      height: screenHeight * 0.38,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF020617), const Color(0xFF0A1628)]
                    : [_brand, _brandDark],
              ),
            ),
          ),
          CustomPaint(
            painter: _HeaderPatternPainter(isDark),
            size: Size.infinite,
          ),
          SafeArea(
            child: FadeTransition(
              opacity: CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.0, 0.5)),
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  _buildRoleChipHeader(isDark, accent, isOwner),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        Text(
                          'Welcome to',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.85),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'RentDone',
                          style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isOwner
                              ? 'Manage your properties effortlessly'
                              : 'Find & manage your rental home',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.75),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleChipHeader(bool isDark, Color accent, bool isOwner) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isOwner ? Icons.domain_rounded : Icons.home_rounded, size: 15, color: Colors.white),
          const SizedBox(width: 5),
          Text(
            isOwner ? 'Owner' : 'Tenant',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(bool isDark, dynamic auth) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.2, 0.7)),
      child: SlideTransition(
        position: Tween(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.2, 0.7, curve: Curves.easeOutCubic)),
        ),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkCard : AppTheme.lightCard,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                blurRadius: 30,
                offset: const Offset(0, -10),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildPhoneBadge(isDark),
                const SizedBox(height: 20),
                _buildTabBar(isDark),
                const SizedBox(height: 22),
                SizedBox(
                  height: _currentTab == 0 ? 280 : 360,
                  child: TabBarView(
                    controller: _tabCtrl,
                    children: [
                      _buildLoginForm(isDark, auth),
                      _buildSignupForm(isDark, auth),
                    ],
                  ),
                ),
                if (auth.errorMessage != null) ...[
                  const SizedBox(height: 12),
                  _buildError(auth.errorMessage!).animate().shake(duration: 400.ms),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneBadge(bool isDark) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.3, 0.6)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.successGreen.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone_android_rounded, size: 15, color: AppTheme.successGreen),
            const SizedBox(width: 6),
            Text(
              '+91 ${widget.phoneNumber}',
              style: const TextStyle(color: AppTheme.successGreen, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.3),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.verified_rounded, size: 14, color: AppTheme.successGreen),
          ],
        ),
      ),
    );
  }

  Widget _buildTabBar(bool isDark) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.06) : AppTheme.lightSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.08) : AppTheme.lightBorder),
      ),
      child: TabBar(
        controller: _tabCtrl,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          gradient: const LinearGradient(colors: [_brand, _brandDark]),
          boxShadow: [BoxShadow(color: _brand.withValues(alpha: 0.30), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        dividerColor: Colors.transparent,
        labelColor: Colors.white,
        unselectedLabelColor: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
        labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.3),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, letterSpacing: 0.3),
        tabs: const [
          Tab(text: 'Sign In'),
          Tab(text: 'Create Account'),
        ],
      ),
    );
  }

  Widget _buildLoginForm(bool isDark, dynamic auth) {
    return Form(
      key: _loginKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        children: [
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
              if (!RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$').hasMatch(s)) return 'Enter a valid email';
              return null;
            },
            isDark: isDark,
            hasFocus: _emailFocus,
            onFocusChange: (f) => setState(() => _emailFocus = f),
          ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.06),
          const SizedBox(height: 14),
          _buildField(
            controller: _passCtrl,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            obscure: _obscurePass,
            validator: (v) {
              if (v == null || v.isEmpty) return 'Password is required';
              if (v.length < 6) return 'At least 6 characters';
              return null;
            },
            isDark: isDark,
            hasFocus: _passFocus,
            onFocusChange: (f) => setState(() => _passFocus = f),
            suffix: IconButton(
              icon: Icon(_obscurePass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  size: 20, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
              onPressed: () => setState(() => _obscurePass = !_obscurePass),
            ),
          ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.06),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => showForgotPasswordDialog(
                context: context,
                ref: ref,
                initialEmail: _emailCtrl.text,
                onEmailSynced: (e) => _emailCtrl.text = e,
              ),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
              child: const Text('Forgot Password?', style: TextStyle(color: _brand, fontWeight: FontWeight.w700, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 6),
          _buildSubmitButton('Sign In', auth.isLoading, _onLogin)
              .animate()
              .fadeIn(delay: 400.ms)
              .scale(begin: const Offset(0.96, 0.96), curve: Curves.easeOutBack),
        ],
      ),
    );
  }

  Widget _buildSignupForm(bool isDark, dynamic auth) {
    return Form(
      key: _signupKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: SingleChildScrollView(
        child: Column(
          children: [
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
                if (!RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$').hasMatch(s)) return 'Enter a valid email';
                return null;
              },
              isDark: isDark,
              hasFocus: _emailFocus,
              onFocusChange: (f) => setState(() => _emailFocus = f),
            ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.06),
            const SizedBox(height: 14),
            _buildField(
              controller: _passCtrl,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              obscure: _obscurePass,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 6) return 'At least 6 characters';
                return null;
              },
              isDark: isDark,
              hasFocus: _passFocus,
              onFocusChange: (f) => setState(() => _passFocus = f),
              suffix: IconButton(
                icon: Icon(_obscurePass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 20, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                onPressed: () => setState(() => _obscurePass = !_obscurePass),
              ),
            ).animate().fadeIn(delay: 300.ms).slideX(begin: 0.06),
            const SizedBox(height: 14),
            _buildField(
              controller: _confirmCtrl,
              label: 'Confirm Password',
              icon: Icons.shield_outlined,
              obscure: _obscureConfirm,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please confirm your password';
                if (v != _passCtrl.text) return 'Passwords do not match';
                return null;
              },
              isDark: isDark,
              hasFocus: _confirmFocus,
              onFocusChange: (f) => setState(() => _confirmFocus = f),
              suffix: IconButton(
                icon: Icon(_obscureConfirm ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    size: 20, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
              ),
            ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.06),
            const SizedBox(height: 10),
            _buildStrengthIndicator(isDark),
            const SizedBox(height: 14),
            _buildSubmitButton('Create Account', auth.isLoading, _onSignup)
                .animate()
                .fadeIn(delay: 500.ms)
                .scale(begin: const Offset(0.96, 0.96), curve: Curves.easeOutBack),
          ],
        ),
      ),
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
              if (loading)
                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _brand, strokeWidth: 2.5))
              else ...[
                Container(
                  width: 22,
                  height: 22,
                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF4285F4)),
                  child: const Center(child: Text('G', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900))),
                ),
                const SizedBox(width: 10),
                Text(
                  _currentTab == 0 ? 'Continue with Google' : 'Sign up with Google',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: isDark ? Colors.white : AppTheme.lightTextPrimary),
                ),
              ],
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.06);
  }

  Widget _buildDivider(bool isDark) {
    final c = isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08);
    final muted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    return Row(
      children: [
        Expanded(child: Divider(color: c, thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text('or use email', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.5, color: muted)),
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
            contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: isDark ? Colors.white.withValues(alpha: 0.10) : AppTheme.lightBorder, width: 1.5),
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

  Widget _buildStrengthIndicator(bool isDark) {
    return ListenableBuilder(
      listenable: _passCtrl,
      builder: (context, _) {
        final p = _passCtrl.text;
        if (p.isEmpty) return const SizedBox.shrink();
        int s = 0;
        if (p.length >= 6) s++;
        if (p.length >= 8) s++;
        if (RegExp(r'[A-Z]').hasMatch(p)) s++;
        if (RegExp(r'[0-9]').hasMatch(p)) s++;
        final activeColor = [AppTheme.errorRed, AppTheme.warningAmber, AppTheme.infoBlue, AppTheme.successGreen][s.clamp(0, 3)];
        final labels = ['Weak', 'Fair', 'Good', 'Strong'];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: List.generate(4, (i) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                  height: 4,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: i < (s == 0 ? 1 : s)
                        ? activeColor
                        : (isDark ? Colors.white.withValues(alpha: 0.10) : Colors.black.withValues(alpha: 0.08)),
                  ),
                ),
              )),
            ),
            const SizedBox(height: 4),
            Text(
              'Password strength: ${labels[s.clamp(0, 3)]}',
              style: TextStyle(fontSize: 11, color: activeColor, fontWeight: FontWeight.w600),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSubmitButton(String text, bool loading, VoidCallback onTap) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [_brand, _brandDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [BoxShadow(color: _brand.withValues(alpha: 0.38), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: loading ? null : onTap,
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withValues(alpha: 0.12),
          child: Center(
            child: loading
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                      const SizedBox(width: 8),
                      const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildError(String msg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed, size: 18),
          const SizedBox(width: 10),
          Expanded(child: Text(msg, style: const TextStyle(color: AppTheme.errorRed, fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }

  Future<void> _onLogin() async {
    if (!_loginKey.currentState!.validate()) return;
    final n = ref.read(authProvider.notifier);
    try {
      final user = await n.continueWithEmail(
        phone: widget.phoneNumber,
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (!mounted) return;
      _navigate(user);
    } catch (_) {}
  }

  Future<void> _onSignup() async {
    if (!_signupKey.currentState!.validate()) return;
    final n = ref.read(authProvider.notifier);
    try {
      final user = await n.continueWithEmail(
        phone: widget.phoneNumber,
        email: _emailCtrl.text.trim(),
        password: _passCtrl.text,
      );
      if (!mounted) return;
      _navigate(user);
    } catch (_) {}
  }

  Future<void> _onGoogle() async {
    final n = ref.read(authProvider.notifier);
    try {
      final user = await n.continueWithGoogle(phone: widget.phoneNumber);
      if (!mounted) return;
      _navigate(user);
    } catch (_) {}
  }

  void _navigate(dynamic user) {
    if (UserRoleX.tryParse(user.role) == UserRole.owner) {
      context.goNamed('ownerDashboard');
    } else {
      context.goNamed('tenantDashboard');
    }
  }
}

class _HeaderPatternPainter extends CustomPainter {
  final bool isDark;
  _HeaderPatternPainter(this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.stroke;

    final ringColor = Colors.white.withValues(alpha: isDark ? 0.06 : 0.08);
    paint.color = ringColor;
    paint.strokeWidth = 1.5;

    for (int i = 0; i < 4; i++) {
      final cx = size.width * (0.7 + i * 0.12);
      final cy = size.height * (0.15 + i * 0.06);
      final radius = 30.0 + i * 25;
      canvas.drawCircle(Offset(cx, cy), radius, paint);
    }

    final dotColor = Colors.white.withValues(alpha: isDark ? 0.08 : 0.10);
    paint.style = PaintingStyle.fill;
    paint.color = dotColor;

    final dots = [
      [0.12, 0.25], [0.25, 0.55], [0.08, 0.70],
      [0.85, 0.35], [0.92, 0.55], [0.78, 0.20],
      [0.15, 0.85], [0.45, 0.12], [0.65, 0.08],
      [0.55, 0.80], [0.35, 0.40], [0.70, 0.65],
    ];
    for (final d in dots) {
      canvas.drawCircle(Offset(size.width * d[0], size.height * d[1]), 2.5, paint);
    }

    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.2;
    paint.color = Colors.white.withValues(alpha: isDark ? 0.04 : 0.06);

    final path = Path();
    path.moveTo(size.width * 0.0, size.height * 0.3);
    path.cubicTo(size.width * 0.25, size.height * 0.15, size.width * 0.55, size.height * 0.45, size.width * 1.0, size.height * 0.25);
    canvas.drawPath(path, paint);

    final path2 = Path();
    path2.moveTo(size.width * 0.0, size.height * 0.7);
    path2.cubicTo(size.width * 0.3, size.height * 0.55, size.width * 0.6, size.height * 0.8, size.width * 1.0, size.height * 0.6);
    canvas.drawPath(path2, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
