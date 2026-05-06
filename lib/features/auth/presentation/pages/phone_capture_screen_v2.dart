import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/core/constants/user_role.dart';

class PhoneCapturePageV2 extends StatefulWidget {
  const PhoneCapturePageV2({super.key, required this.selectedRole});
  final UserRole selectedRole;

  @override
  State<PhoneCapturePageV2> createState() => _PhoneCapturePageV2State();
}

class _PhoneCapturePageV2State extends State<PhoneCapturePageV2>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  late final FocusNode _phoneFocus;
  late final AnimationController _bgController;
  late final AnimationController _pulseController;
  late final AnimationController _shimmerController;
  bool _confirmed = false;
  bool _phoneHasFocus = false;

  static const _brand = AppTheme.darkPrimaryBlue;
  static const _brandEnd = AppTheme.liquidPrimaryEnd;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _phoneFocus = FocusNode()
      ..addListener(() => setState(() => _phoneHasFocus = _phoneFocus.hasFocus));
    _bgController = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))..repeat(reverse: true);
    _shimmerController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _phoneController.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          AuthMeshBackground(controller: _bgController, isDark: isDark),
          _buildContent(isDark),
        ],
      ),
    );
  }

  Widget _buildContent(bool isDark) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              children: [
                _buildLogo(isDark)
                    .animate()
                    .fadeIn(duration: 700.ms)
                    .slideY(begin: -0.3, end: 0, curve: Curves.easeOutCubic),
                const SizedBox(height: 32),
                _buildCard(isDark)
                    .animate()
                    .fadeIn(delay: 150.ms, duration: 600.ms)
                    .scale(begin: const Offset(0.96, 0.96), curve: Curves.easeOutCubic),
                const SizedBox(height: 28),
                _buildBackButton(isDark)
                    .animate()
                    .fadeIn(delay: 900.ms),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(bool isDark) {
    return Column(
      children: [
        AnimatedBuilder(
          animation: _pulseController,
          builder: (_, child) {
            return Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _brand.withValues(alpha: 0.15 + 0.10 * _pulseController.value),
                    blurRadius: 30 + 15 * _pulseController.value,
                    spreadRadius: 4,
                  ),
                ],
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_brand, _brandEnd],
                ),
              ),
              child: child,
            );
          },
          child: const Icon(Icons.apartment_rounded, color: Colors.white, size: 46),
        ),
        const SizedBox(height: 18),
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [_brand, Color(0xFF60A5FA), _brandEnd],
          ).createShader(bounds),
          child: const Text(
            'RENTDONE',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 5.0,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.selectedRole == UserRole.owner ? '🏢 Owner Portal' : '🏠 Tenant Portal',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.white.withValues(alpha: isDark ? 0.5 : 0.55),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildCard(bool isDark) {
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
                  ? [
                      Colors.white.withValues(alpha: 0.08),
                      Colors.white.withValues(alpha: 0.04),
                    ]
                  : [
                      Colors.white.withValues(alpha: 0.85),
                      Colors.white.withValues(alpha: 0.70),
                    ],
            ),
            border: Border.all(
              color: isDark
                  ? _brand.withValues(alpha: 0.25)
                  : _brand.withValues(alpha: 0.15),
              width: 1.5,
            ),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCardHeader(isDark),
                const SizedBox(height: 28),
                _buildPhoneField(isDark),
                const SizedBox(height: 18),
                _buildSecurityNote(isDark),
                const SizedBox(height: 22),
                _buildConfirmTile(isDark),
                const SizedBox(height: 26),
                _buildContinueButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader(bool isDark) {
    final textColor = isDark ? Colors.white : AppTheme.lightTextPrimary;
    final subColor = isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
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
              child: const Icon(Icons.phone_android_rounded, color: _brand, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              'Phone Verification',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: textColor,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ).animate().fadeIn(delay: 250.ms).moveY(begin: 8, end: 0),
        const SizedBox(height: 8),
        Text(
          'Enter your mobile number to get started',
          style: TextStyle(fontSize: 13, color: subColor, fontWeight: FontWeight.w500),
          textAlign: TextAlign.center,
        ).animate().fadeIn(delay: 350.ms),
      ],
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
        borderRadius: BorderRadius.circular(18),
        boxShadow: _phoneHasFocus
            ? [BoxShadow(color: _brand.withValues(alpha: 0.18), blurRadius: 16, offset: const Offset(0, 4))]
            : [],
      ),
      child: TextFormField(
        controller: _phoneController,
        focusNode: _phoneFocus,
        keyboardType: TextInputType.phone,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w900,
          letterSpacing: 3,
          color: isDark ? Colors.white : AppTheme.lightTextPrimary,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(10),
        ],
        validator: _validatePhone,
        decoration: InputDecoration(
          labelText: 'Mobile Number',
          labelStyle: TextStyle(
            color: _phoneHasFocus ? _brand : (isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          hintText: '00000 00000',
          hintStyle: TextStyle(
            color: isDark ? Colors.white.withValues(alpha: 0.20) : Colors.black.withValues(alpha: 0.20),
            letterSpacing: 3,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🇮🇳', style: TextStyle(fontSize: 20)),
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
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide(color: borderColor, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: _brand, width: 2.0),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppTheme.errorRed, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: AppTheme.errorRed, width: 2.0),
          ),
        ),
      ),
    ).animate().fadeIn(delay: 450.ms).slideX(begin: -0.08);
  }

  Widget _buildSecurityNote(bool isDark) {
    return Row(
      children: [
        Icon(Icons.lock_outline_rounded, size: 13, color: AppTheme.successGreen.withValues(alpha: 0.8)),
        const SizedBox(width: 6),
        Text(
          'End-to-end encrypted · Never shared',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ).animate().fadeIn(delay: 550.ms);
  }

  Widget _buildConfirmTile(bool isDark) {
    final textColor = isDark ? Colors.white : AppTheme.lightTextPrimary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: _confirmed
            ? _brand.withValues(alpha: isDark ? 0.12 : 0.06)
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
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
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
                  'I confirm this is my correct mobile number',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textColor),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: 650.ms);
  }

  Widget _buildContinueButton() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (_, child) {
        return Container(
          height: 58,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [_brand, Color(0xFF2563EB)],
            ),
            boxShadow: [
              BoxShadow(
                color: _brand.withValues(alpha: 0.40),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _goToLogin,
          borderRadius: BorderRadius.circular(18),
          splashColor: Colors.white.withValues(alpha: 0.12),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
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
    ).animate().fadeIn(delay: 750.ms).scale(begin: const Offset(0.95, 0.95), curve: Curves.easeOutBack);
  }

  Widget _buildBackButton(bool isDark) {
    return TextButton.icon(
      onPressed: () => context.goNamed('roleSelection'),
      icon: Icon(Icons.arrow_back_ios_new_rounded, size: 14,
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary),
      label: Text(
        'Back to role selection',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
        ),
      ),
    );
  }

  String? _validatePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Mobile number is required';
    if (digits.length != 10) return 'Enter a valid 10-digit number';
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) return 'Enter a valid Indian mobile number';
    return null;
  }

  Future<void> _goToLogin() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline_rounded, color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Please confirm your mobile number first', style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          backgroundColor: AppTheme.darkPrimaryBlue,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      );
      return;
    }
    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final proceed = await _showConfirmDialog(digits);
    if (proceed == true && mounted) {
      context.go('/login?role=${widget.selectedRole.name}&phone=$digits');
    }
  }

  Future<bool?> _showConfirmDialog(String digits) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: isDark ? const Color(0xFF0F172A).withValues(alpha: 0.92) : Colors.white.withValues(alpha: 0.95),
                  border: Border.all(color: _brand.withValues(alpha: 0.25), width: 1.5),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _brand.withValues(alpha: 0.12),
                      ),
                      child: const Icon(Icons.verified_rounded, color: _brand, size: 28),
                    ),
                    const SizedBox(height: 16),
                    Text('Confirm Number',
                        style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppTheme.lightTextPrimary,
                        )),
                    const SizedBox(height: 8),
                    Text('Proceed with this mobile number?',
                        style: TextStyle(
                          fontSize: 13, color: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                        ),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: _brand.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _brand.withValues(alpha: 0.20)),
                      ),
                      child: Text(
                        '+91  $digits',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 3, color: _brand),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary,
                              side: BorderSide(color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _brand,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                            child: const Text('Confirm', style: TextStyle(fontWeight: FontWeight.w800)),
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
      ),
    );
  }
}

// ── Animated Mesh Background (shared across auth screens) ────────────────────

class AuthMeshBackground extends StatelessWidget {
  const AuthMeshBackground({required this.controller, required this.isDark, super.key});
  final AnimationController controller;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (_, child) => CustomPaint(
        painter: _AuthMeshPainter(controller.value, isDark),
        child: Container(),
      ),
    );
  }
}

class _AuthMeshPainter extends CustomPainter {
  final double t;
  final bool isDark;
  _AuthMeshPainter(this.t, this.isDark);

  static const _brand = AppTheme.darkPrimaryBlue;
  static const _brandEnd = AppTheme.liquidPrimaryEnd;

  @override
  void paint(Canvas canvas, Size size) {
    // Base gradient
    final bgPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [const Color(0xFF020617), const Color(0xFF0A1628)]
            : [const Color(0xFFF0F4FF), const Color(0xFFE8F0FE)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // Animated blobs
    _drawBlob(canvas, size,
        cx: size.width * 0.15 + 40 * math.sin(t * 2 * math.pi),
        cy: size.height * 0.15 + 30 * math.cos(t * 2 * math.pi * 0.7),
        radius: size.width * 0.55,
        color: _brand.withValues(alpha: isDark ? 0.18 : 0.12));

    _drawBlob(canvas, size,
        cx: size.width * 0.85 + 35 * math.cos(t * 2 * math.pi * 1.3 + 1),
        cy: size.height * 0.75 + 40 * math.sin(t * 2 * math.pi * 0.9 + 2),
        radius: size.width * 0.50,
        color: _brandEnd.withValues(alpha: isDark ? 0.14 : 0.10));

    _drawBlob(canvas, size,
        cx: size.width * 0.5 + 25 * math.sin(t * 2 * math.pi * 0.5 + 0.5),
        cy: size.height * 0.5 + 20 * math.cos(t * 2 * math.pi * 0.8 + 1),
        radius: size.width * 0.30,
        color: AppTheme.tenantTeal.withValues(alpha: isDark ? 0.08 : 0.06));
  }

  void _drawBlob(Canvas canvas, Size size,
      {required double cx, required double cy, required double radius, required Color color}) {
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color, color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: radius));
    canvas.drawCircle(Offset(cx, cy), radius, paint);
  }

  @override
  bool shouldRepaint(_AuthMeshPainter old) => old.t != t;
}
