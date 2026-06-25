import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/core/constants/user_role.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;

  UserRole? _selectedRole;
  final _phoneCtrl = TextEditingController();
  final _phoneFocus = FocusNode();
  bool _phoneHasFocus = false;
  bool _confirmed = false;

  static const _brand = AppTheme.primaryBlue;
  static const _brandDark = AppTheme.primaryHoverBlue;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _entryCtrl.forward();
    _phoneFocus.addListener(() => setState(() => _phoneHasFocus = _phoneFocus.hasFocus));
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    _phoneCtrl.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  bool get _isPhoneValid {
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    return RegExp(r'^[6-9]\d{9}$').hasMatch(digits);
  }

  bool get _canContinue => _selectedRole != null && _isPhoneValid && _confirmed;

  void _continue() {
    if (!_canContinue) return;
    final digits = _phoneCtrl.text.replaceAll(RegExp(r'\D'), '');
    context.go('/auth?role=${_selectedRole!.name}&phone=$digits');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Column(
        children: [
          _buildHeader(isDark, screenHeight),
          Expanded(child: _buildFormCard(isDark)),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDark, double screenHeight) {
    return SizedBox(
      height: screenHeight * 0.35,
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
                  _buildLogoChip(),
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(colors: [_brand, _brandDark]),
                            boxShadow: [BoxShadow(color: _brand.withValues(alpha: 0.30), blurRadius: 16)],
                          ),
                          child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 28),
                        ),
                        const SizedBox(height: 14),
                        ShaderMask(
                          shaderCallback: (b) => const LinearGradient(
                            colors: [Colors.white, Color(0xFFE0E7FF)],
                          ).createShader(b),
                          child: const Text(
                            'RENTDONE',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 4.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Rent made effortless. Property simplified.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.75),
                            fontWeight: FontWeight.w500,
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

  Widget _buildLogoChip() {
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
          Icon(Icons.handshake_rounded, size: 15, color: Colors.white),
          const SizedBox(width: 5),
          const Text(
            'Get Started',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white, letterSpacing: 0.3),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(bool isDark) {
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
                _buildSectionLabel('I am a...', isDark),
                const SizedBox(height: 10),
                _buildRoleSelector(isDark),
                const SizedBox(height: 20),
                _buildSectionLabel('My mobile number', isDark),
                const SizedBox(height: 8),
                _buildPhoneField(isDark),
                const SizedBox(height: 14),
                _buildConsentCheckbox(isDark),
                const SizedBox(height: 20),
                _buildContinueButton(isDark),
                const SizedBox(height: 16),
                _buildFooter(isDark),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text, bool isDark) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _buildRoleSelector(bool isDark) {
    return Row(
      children: [
        Expanded(child: _buildRoleChip('Owner', Icons.business_rounded, UserRole.owner, isDark)),
        const SizedBox(width: 12),
        Expanded(child: _buildRoleChip('Tenant', Icons.person_rounded, UserRole.tenant, isDark)),
      ],
    );
  }

  Widget _buildRoleChip(String label, IconData icon, UserRole role, bool isDark) {
    final selected = _selectedRole == role;
    final borderColor = selected ? _brand : (isDark ? Colors.white.withValues(alpha: 0.10) : AppTheme.lightBorder);
    final bgColor = selected
        ? _brand.withValues(alpha: isDark ? 0.22 : 0.10)
        : (isDark ? Colors.white.withValues(alpha: 0.05) : AppTheme.lightSurface);
    final textColor = selected
        ? _brand
        : (isDark ? AppTheme.darkTextPrimary : AppTheme.lightTextPrimary);

    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: selected ? 2.0 : 1.5),
          boxShadow: selected
              ? [BoxShadow(color: _brand.withValues(alpha: 0.12), blurRadius: 12, offset: const Offset(0, 4))]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: textColor),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor)),
            if (selected) ...[
              const SizedBox(width: 8),
              Icon(Icons.check_circle_rounded, size: 18, color: _brand),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneField(bool isDark) {
    final borderColor = _phoneHasFocus ? _brand : (isDark ? Colors.white.withValues(alpha: 0.10) : AppTheme.lightBorder);
    final fillColor = isDark
        ? (_phoneHasFocus ? _brand.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.05))
        : (_phoneHasFocus ? _brand.withValues(alpha: 0.04) : AppTheme.lightSurface);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: _phoneHasFocus
            ? [BoxShadow(color: _brand.withValues(alpha: 0.20), blurRadius: 18, offset: const Offset(0, 4))]
            : [],
      ),
      child: TextFormField(
        controller: _phoneCtrl,
        focusNode: _phoneFocus,
        keyboardType: TextInputType.phone,
        maxLength: 10,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 20,
          letterSpacing: 3,
          color: isDark ? Colors.white : AppTheme.lightTextPrimary,
        ),
        decoration: InputDecoration(
          counterText: '',
          labelText: '10-digit mobile',
          labelStyle: TextStyle(
            color: _phoneHasFocus ? _brand : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          hintText: '00000 00000',
          hintStyle: TextStyle(
            color: isDark ? Colors.white.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.18),
            letterSpacing: 3,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('\u{1F1EE}\u{1F1F3}', style: TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Text(
                  '+91',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                    color: _phoneHasFocus ? _brand : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  width: 1.5,
                  height: 22,
                  color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.12),
                ),
              ],
            ),
          ),
          filled: true,
          fillColor: fillColor,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: BorderSide(color: borderColor, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(20),
            borderSide: const BorderSide(color: _brand, width: 2.0),
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildConsentCheckbox(bool isDark) {
    final sub = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _confirmed
            ? _brand.withValues(alpha: isDark ? 0.10 : 0.05)
            : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.black.withValues(alpha: 0.02)),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _confirmed ? _brand.withValues(alpha: 0.35) : (isDark ? Colors.white.withValues(alpha: 0.08) : AppTheme.lightBorder),
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _confirmed = !_confirmed),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: _confirmed ? _brand : Colors.transparent,
                  border: Border.all(
                    color: _confirmed ? _brand : (isDark ? Colors.white.withValues(alpha: 0.25) : AppTheme.lightBorder),
                    width: 2,
                  ),
                ),
                child: _confirmed
                    ? const Icon(Icons.check_rounded, size: 14, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'I confirm this is my correct mobile number and agree to the Terms of Service',
                  style: TextStyle(fontSize: 13, color: sub, fontWeight: FontWeight.w600, height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton(bool isDark) {
    final enabled = _canContinue;
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: enabled
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_brand, _brandDark],
              )
            : null,
        color: enabled ? null : _brand.withValues(alpha: 0.35),
        boxShadow: enabled
            ? [BoxShadow(color: _brand.withValues(alpha: 0.38), blurRadius: 20, offset: const Offset(0, 8))]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? _continue : null,
          borderRadius: BorderRadius.circular(18),
          splashColor: Colors.white.withValues(alpha: enabled ? 0.12 : 0),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Continue',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    final muted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.lock_outline_rounded, size: 12, color: muted),
        const SizedBox(width: 4),
        Text(
          'Your data is encrypted and secure',
          style: TextStyle(fontSize: 11, color: muted, fontWeight: FontWeight.w500),
        ),
      ],
    );
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
