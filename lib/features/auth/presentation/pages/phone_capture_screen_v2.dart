import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/core/constants/user_role.dart';
import 'package:rentdone/features/auth/presentation/widgets/auth_aurora_background.dart';

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
  late final AnimationController _bgCtrl;
  late final AnimationController _entryCtrl;
  bool _confirmed = false;
  bool _phoneHasFocus = false;

  static const _brand = AppTheme.primaryBlue;
  static const _brandDark = AppTheme.primaryHoverBlue;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _phoneFocus = FocusNode()
      ..addListener(() => setState(() => _phoneHasFocus = _phoneFocus.hasFocus));
    _bgCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 20))
      ..repeat();
    _entryCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..forward();
  }

  @override
  void dispose() {
    _bgCtrl.dispose();
    _entryCtrl.dispose();
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
          AuthAuroraBackground(controller: _bgCtrl, isDark: isDark),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(isDark),
                Expanded(child: _buildGlassCard(isDark)),
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
      height: MediaQuery.of(context).size.height * 0.28,
      child: FadeTransition(
        opacity: CurvedAnimation(
            parent: _entryCtrl, curve: const Interval(0.0, 0.45)),
        child: Column(
          children: [
            const SizedBox(height: 12),
            _buildChip(isOwner),
            const Spacer(),
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_brand, _brandDark]),
                boxShadow: [
                  BoxShadow(
                      color: _brand.withValues(alpha: 0.30),
                      blurRadius: 24,
                      spreadRadius: 2),
                ],
              ),
              child: const Icon(Icons.phone_android_rounded,
                  color: Colors.white, size: 30),
            ),
            const SizedBox(height: 16),
            const Text(
              'Enter your mobile number',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "We'll use this to secure your account",
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
            isOwner ? 'Owner Portal' : 'Tenant Portal',
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

  Widget _buildGlassCard(bool isDark) {
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildPhoneField(isDark),
                      const SizedBox(height: 16),
                      _buildSecurityNote(isDark),
                      const SizedBox(height: 22),
                      _buildConfirmTile(isDark),
                      const SizedBox(height: 26),
                      _buildContinueButton(),
                      const SizedBox(height: 16),
                      _buildBackButton(isDark),
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

  Widget _buildPhoneField(bool isDark) {
    final borderColor = _phoneHasFocus
        ? _brand
        : (isDark
            ? Colors.white.withValues(alpha: 0.08)
            : _brand.withValues(alpha: 0.12));
    final fillColor = isDark
        ? (_phoneHasFocus
            ? _brand.withValues(alpha: 0.06)
            : Colors.white.withValues(alpha: 0.04))
        : (_phoneHasFocus
            ? _brand.withValues(alpha: 0.03)
            : Colors.white.withValues(alpha: 0.65));

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        boxShadow: _phoneHasFocus
            ? [
                BoxShadow(
                    color: _brand.withValues(alpha: 0.18),
                    blurRadius: 22,
                    offset: const Offset(0, 4)),
              ]
            : [],
      ),
      child: TextFormField(
        controller: _phoneController,
        focusNode: _phoneFocus,
        keyboardType: TextInputType.phone,
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
          letterSpacing: 3.5,
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
            color: _phoneHasFocus
                ? _brand
                : (isDark
                    ? AppTheme.darkTextSecondary
                    : AppTheme.lightTextSecondary),
            fontWeight: FontWeight.w600,
            fontSize: 14,
          ),
          hintText: '00000 00000',
          hintStyle: TextStyle(
            color: isDark
                ? Colors.white.withValues(alpha: 0.14)
                : Colors.black.withValues(alpha: 0.14),
            letterSpacing: 3.5,
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('\u{1F1EE}\u{1F1F3}',
                    style: TextStyle(fontSize: 22)),
                const SizedBox(width: 10),
                Text(
                  '+91',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: _phoneHasFocus
                        ? _brand
                        : (isDark
                            ? AppTheme.darkTextSecondary
                            : AppTheme.lightTextSecondary),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 1.5,
                  height: 24,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.10),
                ),
              ],
            ),
          ),
          filled: true,
          fillColor: fillColor,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide(color: borderColor, width: 1.2),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: _brand, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide:
                const BorderSide(color: AppTheme.errorRed, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide:
                const BorderSide(color: AppTheme.errorRed, width: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityNote(bool isDark) {
    final muted = isDark ? AppTheme.darkTextMuted : AppTheme.lightTextMuted;
    return Row(
      children: [
        Icon(Icons.shield_outlined,
            size: 15,
            color: AppTheme.successGreen.withValues(alpha: 0.80)),
        const SizedBox(width: 8),
        Text(
          'Encrypted end-to-end · Never shared with third parties',
          style: TextStyle(
              fontSize: 12, color: muted, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildConfirmTile(bool isDark) {
    final textColor = isDark ? Colors.white : AppTheme.lightTextPrimary;
    final isOwner = widget.selectedRole == UserRole.owner;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: _confirmed
            ? _brand.withValues(alpha: isDark ? 0.10 : 0.05)
            : (isDark
                ? Colors.white.withValues(alpha: 0.04)
                : _brand.withValues(alpha: 0.02)),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _confirmed
              ? _brand.withValues(alpha: 0.30)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : _brand.withValues(alpha: 0.10)),
          width: 1.2,
        ),
      ),
      child: InkWell(
        onTap: () => setState(() => _confirmed = !_confirmed),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: _confirmed ? _brand : Colors.transparent,
                  border: Border.all(
                    color: _confirmed
                        ? _brand
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.22)
                            : _brand.withValues(alpha: 0.25)),
                    width: 2,
                  ),
                ),
                child: _confirmed
                    ? const Icon(Icons.check_rounded,
                        size: 16, color: Colors.white)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  isOwner
                      ? 'I confirm this is my correct mobile number as a property owner'
                      : 'I confirm this is my correct mobile number as a tenant',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                      height: 1.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
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
          onTap: _goToLogin,
          borderRadius: BorderRadius.circular(24),
          splashColor: Colors.white.withValues(alpha: 0.10),
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
                      letterSpacing: 0.5),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton(bool isDark) {
    final sub =
        isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;
    return Center(
      child: TextButton.icon(
        onPressed: () => context.goNamed('roleSelection'),
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 14, color: sub),
        label: Text('Back to role selection',
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 13, color: sub)),
      ),
    );
  }

  String? _validatePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Mobile number is required';
    if (digits.length != 10) return 'Enter a valid 10-digit number';
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits))
      return 'Enter a valid Indian mobile number';
    return null;
  }

  Future<void> _goToLogin() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  color: Colors.white, size: 18),
              SizedBox(width: 10),
              Text('Please confirm your mobile number first',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          backgroundColor: _brand,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    final textColor = isDark ? Colors.white : AppTheme.lightTextPrimary;
    final subColor =
        isDark ? AppTheme.darkTextSecondary : AppTheme.lightTextSecondary;

    return showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Dialog(
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  color: isDark
                      ? AppTheme.darkCard.withValues(alpha: 0.92)
                      : Colors.white.withValues(alpha: 0.94),
                  border: Border.all(
                      color: _brand.withValues(alpha: 0.18), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                        color: _brand.withValues(alpha: 0.10),
                        blurRadius: 44,
                        offset: const Offset(0, 14)),
                    BoxShadow(
                        color: Colors.black
                            .withValues(alpha: isDark ? 0.3 : 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 6)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                            colors: [_brand, _brandDark]),
                        boxShadow: [
                          BoxShadow(
                              color: _brand.withValues(alpha: 0.28),
                              blurRadius: 18),
                        ],
                      ),
                      child: const Icon(Icons.verified_rounded,
                          color: Colors.white, size: 30),
                    ),
                    const SizedBox(height: 20),
                    Text('Confirm Number',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            color: textColor)),
                    const SizedBox(height: 8),
                    Text('Proceed with this mobile number?',
                        style: TextStyle(
                            fontSize: 14, color: subColor),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 18),
                      decoration: BoxDecoration(
                        color: _brand.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _brand.withValues(alpha: 0.15)),
                      ),
                      child: Text(
                        '+91  $digits',
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          color: _brand,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: subColor,
                                side: BorderSide(
                                    color: isDark
                                        ? AppTheme.darkBorder
                                        : AppTheme.lightBorder),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(16)),
                              ),
                              child: const Text('Edit',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _brand,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(16)),
                              ),
                              child: const Text('Confirm',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800)),
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
      ),
    );
  }
}
