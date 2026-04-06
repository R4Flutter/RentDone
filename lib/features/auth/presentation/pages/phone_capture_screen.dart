import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/core/constants/user_role.dart';

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
      duration: const Duration(seconds: 16),
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
    final brandHover = OwnerDashboardColors.brandPrimaryHover(context);

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
                    gradient: isDark
                        ? const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF0D1428),
                              Color(0xFF111C34),
                              Color(0xFF12203A),
                            ],
                          )
                        : const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFEAF1FF),
                              Color(0xFFF2F7FF),
                              Color(0xFFE6EEFF),
                            ],
                          ),
                  ),
                ),
              ),
              _blob(
                top: -90,
                left: -40,
                size: 220,
                color: AppTheme.liquidPrimaryStart.withValues(alpha: 0.28),
                travel: 14 * shift,
              ),
              _blob(
                bottom: -110,
                right: -60,
                size: 260,
                color: AppTheme.liquidPrimaryEnd.withValues(alpha: 0.24),
                travel: -18 * shift,
              ),
              SafeArea(
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return SingleChildScrollView(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 16,
                                      sigmaY: 16,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [
                                            brand.withValues(
                                              alpha: isDark ? 0.5 : 0.32,
                                            ),
                                            brandHover.withValues(
                                              alpha: isDark ? 0.62 : 0.42,
                                            ),
                                          ],
                                        ),
                                        border: Border.all(
                                          color: brand.withValues(
                                            alpha: isDark ? 0.48 : 0.34,
                                          ),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: brand.withValues(
                                              alpha: isDark ? 0.26 : 0.18,
                                            ),
                                            blurRadius: 22,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 36,
                                            height: 36,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(
                                                alpha: isDark ? 0.14 : 0.28,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Icon(
                                              Icons.verified_user_rounded,
                                              color: textPrimary,
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              'Phone Verification',
                                              style: theme.textTheme.titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.25,
                                                    color: textPrimary,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 18),
                                Text(
                                  'Verify Your Number',
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        height: 1.1,
                                        color: textPrimary,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Enter your 10-digit Indian mobile number to continue.',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: textSecondary,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: brand.withValues(
                                      alpha: isDark ? 0.20 : 0.12,
                                    ),
                                    border: Border.all(
                                      color: brand.withValues(
                                        alpha: isDark ? 0.34 : 0.22,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    'Free mode: no paid SMS OTP is used. Phone format is validated and account security is enforced by email/password or Google sign-in plus email verification.',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: textPrimary,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: BackdropFilter(
                                    filter: ImageFilter.blur(
                                      sigmaX: 20,
                                      sigmaY: 20,
                                    ),
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: isDark
                                              ? [
                                                  Colors.white.withValues(
                                                    alpha: 0.10,
                                                  ),
                                                  Colors.white.withValues(
                                                    alpha: 0.05,
                                                  ),
                                                ]
                                              : [
                                                  Colors.white.withValues(
                                                    alpha: 0.88,
                                                  ),
                                                  Colors.white.withValues(
                                                    alpha: 0.72,
                                                  ),
                                                ],
                                        ),
                                        border: Border.all(
                                          color: AppTheme.liquidPrimaryStart
                                              .withValues(
                                                alpha: isDark ? 0.34 : 0.22,
                                              ),
                                        ),
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          TextFormField(
                                            controller: _phoneController,
                                            focusNode: _phoneFocus,
                                            keyboardType: TextInputType.phone,
                                            textInputAction:
                                                TextInputAction.done,
                                            inputFormatters: [
                                              FilteringTextInputFormatter
                                                  .digitsOnly,
                                              LengthLimitingTextInputFormatter(
                                                10,
                                              ),
                                            ],
                                            validator: _validateIndianMobile,
                                            decoration: InputDecoration(
                                              labelText: 'Phone Number',
                                              hintText:
                                                  '10-digit mobile number',
                                              labelStyle: theme
                                                  .textTheme
                                                  .labelLarge
                                                  ?.copyWith(
                                                    color: textSecondary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                              hintStyle: theme
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    color: textSecondary
                                                        .withValues(
                                                          alpha: 0.75,
                                                        ),
                                                  ),
                                              prefixIcon: Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 12,
                                                  right: 8,
                                                ),
                                                child: Text(
                                                  '🇮🇳',
                                                  style: theme
                                                      .textTheme
                                                      .titleLarge
                                                      ?.copyWith(fontSize: 22),
                                                ),
                                              ),
                                              prefixIconConstraints:
                                                  const BoxConstraints(
                                                    minWidth: 46,
                                                    minHeight: 24,
                                                  ),
                                              filled: true,
                                              fillColor: isDark
                                                  ? Colors.white.withValues(
                                                      alpha: 0.07,
                                                    )
                                                  : Colors.white.withValues(
                                                      alpha: 0.78,
                                                    ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'Valid Indian number only: must start with 6, 7, 8, or 9.',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: textSecondary,
                                                  fontWeight: FontWeight.w500,
                                                  height: 1.35,
                                                ),
                                          ),
                                          const SizedBox(height: 6),
                                          CheckboxListTile(
                                            value: _confirmed,
                                            dense: true,
                                            contentPadding: EdgeInsets.zero,
                                            controlAffinity:
                                                ListTileControlAffinity.leading,
                                            title: Text(
                                              'I confirm this is my correct number',
                                              style: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                    color: textPrimary,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                            ),
                                            onChanged: (value) {
                                              setState(
                                                () =>
                                                    _confirmed = value == true,
                                              );
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  height: 56,
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor:
                                          AppTheme.liquidPrimaryStart,
                                    ),
                                    onPressed: _goToLogin,
                                    child: const Text(
                                      'Continue to Sign In',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Center(
                                  child: TextButton(
                                    onPressed: () =>
                                        context.goNamed('roleSelection'),
                                    child: const Text('Back to Role Selection'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
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
            boxShadow: [BoxShadow(color: color, blurRadius: 70)],
          ),
        ),
      ),
    );
  }

  String? _validateIndianMobile(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Phone number is required';
    if (digits.length != 10) return 'Phone number must be exactly 10 digits';
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(digits)) {
      return 'Enter a valid Indian mobile number';
    }
    return null;
  }

  Future<void> _goToLogin() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_confirmed) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('Please confirm this is your number.')),
        );
      return;
    }

    final digits = _phoneController.text.replaceAll(RegExp(r'\D'), '');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final brand = OwnerDashboardColors.brandPrimary(context);
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            Colors.white.withValues(alpha: 0.13),
                            brand.withValues(alpha: 0.14),
                          ]
                        : [
                            Colors.white.withValues(alpha: 0.94),
                            brand.withValues(alpha: 0.16),
                          ],
                  ),
                  border: Border.all(
                    color: brand.withValues(alpha: isDark ? 0.42 : 0.24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withValues(
                        alpha: isDark ? 0.34 : 0.12,
                      ),
                      blurRadius: 26,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: brand.withValues(alpha: isDark ? 0.30 : 0.14),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: brand.withValues(
                              alpha: isDark ? 0.28 : 0.14,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: brand.withValues(
                                alpha: isDark ? 0.44 : 0.24,
                              ),
                            ),
                          ),
                          child: Icon(
                            Icons.verified_user_rounded,
                            size: 18,
                            color: OwnerDashboardColors.textPrimary(context),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Confirm Number',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                      color: OwnerDashboardColors.textPrimary(
                                        context,
                                      ),
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Is this the correct number?',
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      color: OwnerDashboardColors.textSecondary(
                                        context,
                                      ),
                                      height: 1.35,
                                    ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '+91 $digits',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      foregroundColor:
                                          OwnerDashboardColors.textSecondary(
                                            context,
                                          ),
                                    ),
                                    onPressed: () =>
                                        Navigator.of(context).pop(false),
                                    child: const Text('Edit'),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton(
                                    style: FilledButton.styleFrom(
                                      backgroundColor:
                                          OwnerDashboardColors.brandPrimary(
                                            context,
                                          ),
                                      foregroundColor: isDark
                                          ? AppColors.white
                                          : AppColors.cFF0F172A,
                                    ),
                                    onPressed: () =>
                                        Navigator.of(context).pop(true),
                                    child: const Text('Yes, Continue'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (confirmed != true || !mounted) return;
    context.go('/login?role=${widget.selectedRole.name}&phone=$digits');
  }
}
