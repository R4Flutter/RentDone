import 'dart:ui';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/core/constants/user_role.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key, required this.selectedRole});

  final UserRole selectedRole;

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final AnimationController _bgController;
  late final FocusNode _phoneFocus;
  late final FocusNode _emailFocus;
  late final FocusNode _passwordFocus;
  late final FocusNode _confirmPasswordFocus;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  bool _isCtaPressed = false;
  String? _authError;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
    _confirmPasswordController = TextEditingController();
    _phoneFocus = FocusNode()..addListener(_onFocusChanged);
    _emailFocus = FocusNode()..addListener(_onFocusChanged);
    _passwordFocus = FocusNode()..addListener(_onFocusChanged);
    _confirmPasswordFocus = FocusNode()..addListener(_onFocusChanged);

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneFocus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _emailFocus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _passwordFocus
      ..removeListener(_onFocusChanged)
      ..dispose();
    _confirmPasswordFocus
      ..removeListener(_onFocusChanged)
      ..dispose();
    super.dispose();
  }

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppTheme.darkBackground,
      body: AnimatedBuilder(
        animation: _bgController,
        builder: (context, _) {
          final t = _bgController.value;

          return Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: const [
                        AppTheme.nearBlack,
                        AppTheme.darkBackground,
                      ],
                    ),
                  ),
                ),
              ),
              _floatingBubble(
                top: -90 + (t * 18),
                left: -85 + (t * 8),
                size: 260,
                blurSigma: 80,
                opacity: 0.12,
                colors: const [AppTheme.liquidPrimaryStart, AppTheme.infoBlue],
              ),
              _floatingBubble(
                bottom: -110 + (t * 14),
                right: -95 - (t * 8),
                size: 300,
                blurSigma: 80,
                opacity: 0.12,
                colors: const [AppTheme.liquidPrimaryEnd, AppTheme.primaryBlue],
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final keyboardInset = MediaQuery.of(
                      context,
                    ).viewInsets.bottom;
                    final availableHeight = math.max(
                      0.0,
                      constraints.maxHeight - keyboardInset - 44,
                    );

                    return SingleChildScrollView(
                      physics: const ClampingScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        24,
                        24,
                        24,
                        24 + keyboardInset,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: availableHeight),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 500),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 420),
                              curve: Curves.easeOutCubic,
                              builder: (context, v, child) => Opacity(
                                opacity: v,
                                child: Transform.translate(
                                  offset: Offset(0, (1 - v) * 24),
                                  child: child,
                                ),
                              ),
                              child: _buildContentColumn(),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContentColumn() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildBranding(),
        const SizedBox(height: 40),
        _buildSignupCard(),
      ],
    );
  }

  Widget _buildBranding() {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppTheme.darkSurface.withOpacity(0.80),
                    AppTheme.primaryBlue.withOpacity(0.24),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: AppTheme.primarySoftBlue.withOpacity(0.20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withOpacity(0.20),
                    blurRadius: 20,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: const [
                  Icon(
                    Icons.home_work_rounded,
                    color: AppTheme.pureWhite,
                    size: 30,
                  ),
                  Positioned(
                    right: 14,
                    bottom: 14,
                    child: Icon(
                      Icons.check_circle,
                      color: AppTheme.infoBlue,
                      size: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'RentDone',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: AppTheme.pureWhite,
            letterSpacing: 0.1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Property Management Simplified',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppTheme.darkTextSecondary.withOpacity(0.70),
          ),
        ),
      ],
    );
  }

  Widget _buildSignupCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: AppTheme.pureWhite.withOpacity(0.06),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: AppTheme.pureWhite.withOpacity(0.15),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryBlue.withOpacity(0.18),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Create Account',
                  style: TextStyle(
                    fontSize: 31,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.pureWhite,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Join our network of property owners',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.darkTextSecondary.withOpacity(0.70),
                  ),
                ),
                const SizedBox(height: 24),
                _glassInput(
                  controller: _phoneController,
                  focusNode: _phoneFocus,
                  label: 'Phone Number',
                  icon: Icons.phone_rounded,
                  keyboardType: TextInputType.phone,
                  inputAction: TextInputAction.next,
                  formatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  onChanged: (_) {
                    if (_authError != null) setState(() => _authError = null);
                  },
                  validator: _validatePhone,
                ),
                const SizedBox(height: 16),
                _glassInput(
                  controller: _emailController,
                  focusNode: _emailFocus,
                  label: 'Email Address',
                  icon: Icons.alternate_email_rounded,
                  keyboardType: TextInputType.emailAddress,
                  inputAction: TextInputAction.next,
                  onChanged: (_) {
                    if (_authError != null) setState(() => _authError = null);
                  },
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),
                _glassInput(
                  controller: _passwordController,
                  focusNode: _passwordFocus,
                  label: 'Password',
                  icon: Icons.lock_rounded,
                  inputAction: TextInputAction.next,
                  obscure: _obscurePassword,
                  suffix: _visibilityToggle(
                    _obscurePassword,
                    () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  onChanged: (_) {
                    if (_authError != null) setState(() => _authError = null);
                  },
                  validator: _validatePassword,
                ),
                const SizedBox(height: 16),
                _glassInput(
                  controller: _confirmPasswordController,
                  focusNode: _confirmPasswordFocus,
                  label: 'Confirm Password',
                  icon: Icons.shield_rounded,
                  inputAction: TextInputAction.done,
                  obscure: _obscureConfirmPassword,
                  suffix: _visibilityToggle(
                    _obscureConfirmPassword,
                    () => setState(
                      () => _obscureConfirmPassword = !_obscureConfirmPassword,
                    ),
                  ),
                  onChanged: (_) {
                    if (_authError != null) setState(() => _authError = null);
                  },
                  onSubmitted: (_) {
                    if (!_isLoading) _onSignupPressed();
                  },
                  validator: _validateConfirmPassword,
                ),
                if (_authError != null) ...[
                  const SizedBox(height: 14),
                  _errorCard(_authError!),
                ],
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => context.goNamed('roleSelection'),
                    icon: const Icon(Icons.swap_horiz_rounded, size: 14),
                    label: const Text('Change Role'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppTheme.infoBlue,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _ctaButton(),
                const SizedBox(height: 20),
                Center(
                  child: GestureDetector(
                    onTap: _isLoading
                        ? null
                        : () => context.go(
                            '/login?role=${widget.selectedRole.name}',
                          ),
                    child: RichText(
                      text: TextSpan(
                        text: 'Already have an account? ',
                        style: TextStyle(
                          color: AppTheme.darkTextSecondary.withOpacity(0.70),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                        children: const [
                          TextSpan(
                            text: 'Sign In',
                            style: TextStyle(
                              color: AppTheme.liquidPrimaryStart,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
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

  Widget _glassInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    TextInputAction? inputAction,
    List<TextInputFormatter>? formatters,
    ValueChanged<String>? onChanged,
    ValueChanged<String>? onSubmitted,
    FormFieldValidator<String>? validator,
    bool obscure = false,
    Widget? suffix,
  }) {
    final focused = focusNode.hasFocus;
    final borderColor = focused
        ? AppTheme.liquidPrimaryStart
        : AppTheme.pureWhite.withOpacity(0.08);
    final glowColor = focused
        ? AppTheme.primaryBlue.withOpacity(0.22)
        : Colors.transparent;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          height: 60,
          decoration: BoxDecoration(
            color: AppTheme.pureWhite.withOpacity(focused ? 0.07 : 0.05),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(color: glowColor, blurRadius: 18, spreadRadius: 1),
            ],
          ),
          child: TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboardType,
            textInputAction: inputAction,
            inputFormatters: formatters,
            onChanged: onChanged,
            onFieldSubmitted: onSubmitted,
            obscureText: obscure,
            validator: validator,
            style: const TextStyle(
              color: AppTheme.pureWhite,
              fontSize: 14.5,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14),
              labelText: label,
              labelStyle: TextStyle(
                color: AppTheme.darkTextSecondary.withOpacity(0.95),
                fontSize: 13,
              ),
              prefixIcon: Icon(
                icon,
                color: focused
                    ? AppTheme.infoBlue
                    : AppTheme.liquidPrimaryStart,
                size: 20,
                shadows: [
                  Shadow(
                    color: AppTheme.primaryBlue.withOpacity(0.45),
                    blurRadius: 12,
                  ),
                ],
              ),
              suffixIcon: suffix,
              errorStyle: const TextStyle(
                color: AppTheme.errorRed,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _visibilityToggle(bool isObscured, VoidCallback onTap) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(
        isObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded,
        color: AppTheme.darkTextSecondary.withOpacity(0.92),
        size: 20,
      ),
    );
  }

  Widget _ctaButton() {
    return AnimatedScale(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      scale: _isCtaPressed ? 0.97 : 1,
      child: SizedBox(
        height: 60,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Material(
            color: Colors.transparent,
            child: Ink(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [AppTheme.liquidPrimaryStart, AppTheme.infoBlue],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryBlue.withOpacity(0.38),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: GestureDetector(
                onTapDown: _isLoading
                    ? null
                    : (_) => setState(() => _isCtaPressed = true),
                onTapUp: _isLoading
                    ? null
                    : (_) => setState(() => _isCtaPressed = false),
                onTapCancel: _isLoading
                    ? null
                    : () => setState(() => _isCtaPressed = false),
                onTap: _isLoading ? null : _onSignupPressed,
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppTheme.pureWhite,
                            ),
                          ),
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(
                            color: AppTheme.pureWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorCard(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.errorRed.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.errorRed.withOpacity(0.7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: AppTheme.errorRed),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppTheme.errorRed,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _floatingBubble({
    double? top,
    double? left,
    double? bottom,
    double? right,
    required double size,
    required double blurSigma,
    required double opacity,
    required List<Color> colors,
  }) {
    return Positioned(
      top: top,
      left: left,
      bottom: bottom,
      right: right,
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Opacity(
            opacity: opacity,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: colors,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _validatePhone(String? input) {
    final digits = (input ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Phone number is required';
    if (digits.length != 10) return 'Phone number must be 10 digits';
    return null;
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
    if (value.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  String? _validateConfirmPassword(String? input) {
    final value = input ?? '';
    if (value.isEmpty) return 'Confirm password is required';
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _onSignupPressed() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _authError = null;
    });

    try {
      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          );
      final user = credential.user;
      if (user == null) {
        throw FirebaseAuthException(code: 'unknown', message: 'Signup failed.');
      }

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'userId': user.uid,
        'email': _emailController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'role': 'owner',
        'createdAt': FieldValue.serverTimestamp(),
        'tenantScore': 0,
      }, SetOptions(merge: true));

      if (!mounted) return;
      context.goNamed('ownerDashboard');
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() {
        _authError = _mapAuthError(error);
      });
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() {
        _authError =
            error.message ?? 'Could not create account. Please try again.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _authError = 'Could not create account. Please try again.';
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isCtaPressed = false;
      });
    }
  }

  String _mapAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return 'This email is already in use.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return error.message ?? 'Could not create account. Please try again.';
    }
  }
}
