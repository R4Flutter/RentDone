import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
      duration: const Duration(seconds: 25),
    )..repeat();
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
      body: Stack(
        children: [
          // 1. Cinematic Background
          _buildCinematicBackground(isDark, brand),

          // 2. Main Content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 450),
                  child: Column(
                    children: [
                      _buildBrandHeader(isDark, brand)
                          .animate()
                          .fadeIn(duration: 800.ms)
                          .slideY(begin: -0.2, end: 0, curve: Curves.easeOutBack),
                      
                      const SizedBox(height: 40),

                      GlassContainer(
                        blurAmount: 25,
                        opacity: isDark ? 0.12 : 0.65,
                        borderRadius: 32,
                        padding: const EdgeInsets.all(32),
                        borderColor: brand.withValues(alpha: isDark ? 0.2 : 0.1),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'IDENTIFICATION',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 3.0,
                                  color: brand,
                                ),
                                textAlign: TextAlign.center,
                              ).animate().fadeIn(delay: 200.ms).moveY(begin: 10, end: 0),
                              
                              const SizedBox(height: 8),
                              
                              Text(
                                'Verification Portal',
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: textPrimary,
                                  letterSpacing: -0.5,
                                ),
                                textAlign: TextAlign.center,
                              ).animate().fadeIn(delay: 300.ms).moveY(begin: 10, end: 0),
                              
                              const SizedBox(height: 32),

                              _buildPhoneField(theme, isDark, textSecondary)
                                  .animate()
                                  .fadeIn(delay: 500.ms)
                                  .slideX(begin: -0.1),
                              
                              const SizedBox(height: 20),

                              Text(
                                'Secure identity verification using mobile credentials. Encrypted end-to-end.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: textSecondary.withValues(alpha: 0.7),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ).animate().fadeIn(delay: 600.ms),
                              
                              const SizedBox(height: 32),

                              _buildConfirmationTile(theme, textPrimary)
                                  .animate()
                                  .fadeIn(delay: 700.ms),
                              
                              const SizedBox(height: 32),

                              _buildPrimaryButton(brand)
                                  .animate()
                                  .fadeIn(delay: 800.ms)
                                  .scale(begin: const Offset(0.95, 0.95)),
                            ],
                          ),
                        ),
                      ).animate().fadeIn(delay: 100.ms).scale(
                        begin: const Offset(0.98, 0.98),
                        curve: Curves.easeOutCubic,
                        duration: 600.ms,
                      ),

                      const SizedBox(height: 40),
                      
                      TextButton.icon(
                        onPressed: () => context.goNamed('roleSelection'),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
                        label: const Text('Return to role selection'),
                        style: TextButton.styleFrom(
                          foregroundColor: textSecondary,
                          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
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

  Widget _buildCinematicBackground(bool isDark, Color brand) {
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
              color: brand.withValues(alpha: 0.15),
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
          ],
        );
      },
    );
  }

  Widget _buildBrandHeader(bool isDark, Color brand) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
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
            width: 90,
            height: 90,
            errorBuilder: (_, _, _) => Icon(Icons.apartment_rounded, size: 70, color: brand),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'RENTDONE',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : Colors.black87,
            letterSpacing: 4.0,
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
        fontWeight: FontWeight.w900,
        letterSpacing: 3,
        color: OwnerDashboardColors.brandPrimary(context),
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      validator: _validateIndianMobile,
      decoration: InputDecoration(
        labelText: 'Identification Number',
        labelStyle: TextStyle(
          color: textSecondary.withValues(alpha: 0.7),
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        hintText: '00000 00000',
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🇮🇳', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Text(
                '+91',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Container(width: 1.5, height: 24, color: textSecondary.withValues(alpha: 0.2)),
            ],
          ),
        ),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(color: OwnerDashboardColors.brandPrimary(context), width: 2.0),
        ),
      ),
    );
  }

  Widget _buildConfirmationTile(ThemeData theme, Color textPrimary) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: OwnerDashboardColors.brandPrimary(context).withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: OwnerDashboardColors.brandPrimary(context).withValues(alpha: 0.05)),
      ),
      child: InkWell(
        onTap: () => setState(() => _confirmed = !_confirmed),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          child: Row(
            children: [
              Checkbox(
                value: _confirmed,
                onChanged: (v) => setState(() => _confirmed = v ?? false),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                activeColor: OwnerDashboardColors.brandPrimary(context),
              ),
              Expanded(
                child: Text(
                  'I verify that this information is correct',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton(Color brand) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: brand.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: GlassButton(
        onPressed: _goToLogin,
        label: 'INITIALIZE ACCESS',
        isPrimary: true,
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
              dy * (t * 2 - 1.0)
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
        const SnackBar(content: Text('Please verify your credentials first')),
      );
      return;
    }

    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => GlassDialog(
        title: 'VERIFICATION',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Confirm access credentials for the provided mobile number:',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: OwnerDashboardColors.brandPrimary(context).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '+91 $digits',
                style: TextStyle(
                  fontSize: 26, 
                  fontWeight: FontWeight.w900, 
                  letterSpacing: 2,
                  color: OwnerDashboardColors.brandPrimary(context),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('EDIT'),
          ),
          GlassButton(
            onPressed: () => Navigator.pop(ctx, true),
            label: 'PROCEED',
            isPrimary: true,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ],
      ),
    );

    if (proceed == true && mounted) {
      context.go('/login?role=${widget.selectedRole.name}&phone=$digits');
    }
  }
}

