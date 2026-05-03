import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/core/constants/user_role.dart';
import 'package:rentdone/shared/design/glassmorphism.dart';

class PhoneCapturePage extends StatefulWidget {
  const PhoneCapturePage({super.key, required this.selectedRole});

  final UserRole selectedRole;

  @override
  State<PhoneCapturePage> createState() => _PhoneCapturePageState();
}

class _PhoneCapturePageState extends State<PhoneCapturePage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _phoneController;
  late final FocusNode _phoneFocus;
  late final AnimationController _bgController;
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _phoneFocus = FocusNode();
    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController.dispose();
    _phoneController.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = OwnerDashboardColors.textPrimary(context);
    final textSecondary = OwnerDashboardColors.textSecondary(context);
    final brand = OwnerDashboardColors.brandPrimary(context);

    return Scaffold(
      backgroundColor: OwnerDashboardColors.pageBackground(context),
      extendBodyBehindAppBar: true,
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, _) {
          final shift = _bgController.value;
          return Stack(
            children: [
              // 1. Dynamic Background Gradient
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [
                              const Color(0xFF0F172A),
                              const Color(0xFF1E293B),
                              const Color(0xFF0F172A),
                            ]
                          : [
                              const Color(0xFFF8FAFC),
                              const Color(0xFFF1F5F9),
                              const Color(0xFFE2E8F0),
                            ],
                    ),
                  ),
                ),
              ),

              // 2. Animated Blobs
              _blob(
                top: -120,
                left: -60,
                size: 300,
                color: brand.withValues(alpha: 0.15),
                travel: 20 * shift,
              ),
              _blob(
                bottom: -150,
                right: -80,
                size: 350,
                color: AppTheme.liquidPrimaryEnd.withValues(alpha: 0.12),
                travel: -25 * shift,
              ),
              _blob(
                top: 200,
                right: -100,
                size: 200,
                color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
                travel: 15 * shift,
              ),

              // 3. Main Content
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 450),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // App Logo / Icon
                          _buildBrandHeader(isDark, brand),
                          const SizedBox(height: 32),

                          // Main Glass Container
                          GlassContainer(
                            blurAmount: 20,
                            opacity: isDark ? 0.1 : 0.6,
                            borderRadius: 32,
                            padding: const EdgeInsets.all(24),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Get Started',
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                          fontWeight: FontWeight.w900,
                                          color: textPrimary,
                                          letterSpacing: -0.5,
                                        ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Enter your number to continue',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: textSecondary,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 32),

                                  // Phone Input
                                  _buildPhoneField(theme, isDark, textSecondary),
                                  const SizedBox(height: 16),

                                  // Instructions
                                  Text(
                                    'We will use this number for your property profile. No OTP required for this setup.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: textSecondary.withValues(alpha: 0.8),
                                      fontSize: 11,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),

                                  // Confirmation Checkbox
                                  _buildConfirmationTile(theme, textPrimary),
                                  const SizedBox(height: 32),

                                  // Primary Button
                                  GlassButton(
                                    onPressed: _goToLogin,
                                    label: 'Continue',
                                    isPrimary: true,
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),
                          // Back Button
                          TextButton.icon(
                            onPressed: () => context.goNamed('roleSelection'),
                            icon: const Icon(Icons.arrow_back_rounded, size: 18),
                            label: const Text('Change Role'),
                            style: TextButton.styleFrom(
                              foregroundColor: textSecondary,
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

  Widget _buildBrandHeader(bool isDark, Color brand) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: brand.withValues(alpha: 0.1),
            border: Border.all(color: brand.withValues(alpha: 0.2)),
          ),
          child: Image.asset(
            'assets/images/rentdone_logo.png',
            width: 80,
            height: 80,
            errorBuilder: (_, __, ___) =>
                Icon(Icons.house_rounded, size: 60, color: brand),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'RentDone',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: OwnerDashboardColors.textPrimary(context),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField(ThemeData theme, bool isDark, Color textSecondary) {
    return TextFormField(
      controller: _phoneController,
      focusNode: _phoneFocus,
      keyboardType: TextInputType.phone,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        letterSpacing: 2,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      validator: _validateIndianMobile,
      decoration: InputDecoration(
        labelText: 'Mobile Number',
        hintText: '00000 00000',
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '🇮🇳',
                style: const TextStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Text(
                '+91',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: textSecondary,
                ),
              ),
              const SizedBox(width: 8),
              Container(width: 1, height: 24, color: textSecondary.withValues(alpha: 0.2)),
            ],
          ),
        ),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: OwnerDashboardColors.brandPrimary(context), width: 1.5),
        ),
      ),
    );
  }

  Widget _buildConfirmationTile(ThemeData theme, Color textPrimary) {
    return InkWell(
      onTap: () => setState(() => _confirmed = !_confirmed),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Checkbox(
              value: _confirmed,
              onChanged: (v) => setState(() => _confirmed = v ?? false),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              activeColor: OwnerDashboardColors.brandPrimary(context),
            ),
            Expanded(
              child: Text(
                'I confirm this is my correct number',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: textPrimary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
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

  String? _validateIndianMobile(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Phone number is required';
    if (digits.length != 10) return 'Phone number must be 10 digits';
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      return 'Enter a valid Indian mobile number';
    }
    return null;
  }

  Future<void> _goToLogin() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_confirmed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please confirm your number first')),
      );
      return;
    }

    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    
    // Modern Glass Confirmation Dialog
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => GlassDialog(
        title: 'Verify Number',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Is this number correct? We will use it for your account.'),
            const SizedBox(height: 16),
            Text(
              '+91 $digits',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Edit'),
          ),
          GlassButton(
            onPressed: () => Navigator.pop(ctx, true),
            label: 'Yes, Proceed',
            isPrimary: true,
          ),
        ],
      ),
    );

    if (proceed == true && mounted) {
      context.go('/login?role=${widget.selectedRole.name}&phone=$digits');
    }
  }
}
