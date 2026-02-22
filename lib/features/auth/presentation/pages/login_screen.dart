import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:rentdone/core/constants/user_role.dart';
import 'package:rentdone/features/auth/presentation/providers/auth_provider.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key, required this.selectedRole});

  final UserRole selectedRole;

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _obscurePassword = true;
  String? _phoneError;

  @override
  void initState() {
    super.initState();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(authProvider.notifier).setSelectedRole(widget.selectedRole);
    });
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validatePhone(String phone) {
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) {
      return 'Phone number is required';
    }
    if (digits.length < 10) {
      return 'Phone must be at least 10 digits';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authProvider);
    final notifier = ref.read(authProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isOwner = widget.selectedRole == UserRole.owner;

    final bg60Color = isDark
        ? const Color(0xFF0A0E27)
        : const Color(0xFFF5F7FA);
    final accent30Color = const Color(0xFF2563EB);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              bg60Color,
              isDark ? const Color(0xFF1A1F3A) : const Color(0xFFFBFDFF),
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeaderCard(context, bg60Color, accent30Color, isOwner),
                const SizedBox(height: 32),
                _buildLoginForm(
                  context,
                  state,
                  notifier,
                  bg60Color,
                  accent30Color,
                  isDark,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(
    BuildContext context,
    Color bg60Color,
    Color accent30Color,
    bool isOwner,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent30Color.withValues(alpha: 0.9),
            accent30Color.withValues(alpha: 0.7),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: accent30Color.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  isOwner ? Icons.apartment_rounded : Icons.home_work_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  '${widget.selectedRole.label} Access',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Secure login for ${widget.selectedRole.label.toLowerCase()} dashboard',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              OutlinedButton(
                onPressed: () => context.goNamed('roleSelection'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38, width: 1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('Change Role'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(
    BuildContext context,
    dynamic authState,
    dynamic authNotifier,
    Color bg60Color,
    Color accent30Color,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1A1F3A).withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accent30Color.withValues(alpha: 0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black26
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Welcome to RentDone',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sign in with your phone number and create account easily',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.white54 : Colors.black54,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),
          _buildPhoneField(context, authNotifier, isDark, accent30Color),
          if (_phoneError != null) ...[
            const SizedBox(height: 8),
            Text(
              _phoneError!,
              style: TextStyle(
                color: Colors.red[400],
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(height: 12),
          _buildGoogleButton(authState, isDark, accent30Color),
          const SizedBox(height: 20),
          _buildDivider(isDark),
          const SizedBox(height: 20),
          _buildEmailField(context, authNotifier, isDark, accent30Color),
          const SizedBox(height: 12),
          _buildPasswordField(isDark, accent30Color),
          if (authState.errorMessage != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red[200]!, width: 1),
              ),
              child: Text(
                authState.errorMessage!,
                style: TextStyle(
                  color: Colors.red[700],
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _buildSubmitButton(authState, isDark, accent30Color),
          const SizedBox(height: 12),
          _buildToggleModeButton(authState, isDark),
        ],
      ),
    );
  }

  Widget _buildPhoneField(
    BuildContext context,
    authNotifier,
    bool isDark,
    Color accent30Color,
  ) {
    final theme = Theme.of(context);

    return TextField(
      controller: _phoneController,
      keyboardType: TextInputType.phone,
      maxLength: 10,
      onChanged: (value) {
        setState(() {
          _phoneError = null;
        });
        authNotifier.clearError();
      },
      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: 'Phone Number',
        hintText: 'Enter 10 digits',
        prefixIcon: Icon(Icons.phone_rounded, color: accent30Color),
        counterText: '',
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : accent30Color.withValues(alpha: 0.04),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent30Color.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent30Color.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent30Color, width: 2),
        ),
      ),
    );
  }

  Widget _buildEmailField(
    BuildContext context,
    authNotifier,
    bool isDark,
    Color accent30Color,
  ) {
    final theme = Theme.of(context);

    return TextField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      onChanged: (_) => authNotifier.clearError(),
      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: 'Email Address',
        hintText: 'name@example.com',
        prefixIcon: Icon(Icons.alternate_email_rounded, color: accent30Color),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : accent30Color.withValues(alpha: 0.04),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent30Color.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent30Color.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent30Color, width: 2),
        ),
      ),
    );
  }

  Widget _buildPasswordField(bool isDark, Color accent30Color) {
    final theme = Theme.of(context);

    return TextField(
      controller: _passwordController,
      obscureText: _obscurePassword,
      onChanged: (_) => ref.read(authProvider.notifier).clearError(),
      style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        labelText: 'Password',
        hintText: 'At least 6 characters',
        prefixIcon: Icon(Icons.lock_rounded, color: accent30Color),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
          icon: Icon(
            _obscurePassword
                ? Icons.visibility_off_rounded
                : Icons.visibility_rounded,
            color: accent30Color.withValues(alpha: 0.6),
          ),
        ),
        filled: true,
        fillColor: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : accent30Color.withValues(alpha: 0.04),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent30Color.withValues(alpha: 0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent30Color.withValues(alpha: 0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent30Color, width: 2),
        ),
      ),
    );
  }

  Widget _buildGoogleButton(
    dynamic authState,
    bool isDark,
    Color accent30Color,
  ) {
    const Color googleBlue = Color(0xFF4285F4);

    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: authState.isLoading ? null : _onGooglePressed,
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: googleBlue.withValues(alpha: 0.3),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.login_rounded, color: googleBlue),
        label: Text(
          'Continue with Google',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: Divider(
            color: isDark ? Colors.white12 : Colors.black12,
            thickness: 1,
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'or continue with email',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.black54,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: isDark ? Colors.white12 : Colors.black12,
            thickness: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton(
    dynamic authState,
    bool isDark,
    Color accent30Color,
  ) {
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: authState.isLoading ? null : _onEmailPressed,
        style: FilledButton.styleFrom(
          backgroundColor: accent30Color,
          disabledBackgroundColor: accent30Color.withValues(alpha: 0.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: authState.isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                authState.isRegisterMode ? 'Create Account' : 'Sign In',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.3,
                ),
              ),
      ),
    );
  }

  Widget _buildToggleModeButton(dynamic authState, bool isDark) {
    return TextButton(
      onPressed: authState.isLoading
          ? null
          : () {
              ref
                  .read(authProvider.notifier)
                  .setMode(registerMode: !authState.isRegisterMode);
            },
      child: Text(
        authState.isRegisterMode
            ? 'Already have an account? Sign in'
            : 'New here? Create an account',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: const Color(0xFF2563EB),
        ),
      ),
    );
  }

  Future<void> _onGooglePressed() async {
    final phoneError = _validatePhone(_phoneController.text);
    if (phoneError != null) {
      setState(() => _phoneError = phoneError);
      return;
    }

    final notifier = ref.read(authProvider.notifier);
    try {
      final user = await notifier.continueWithGoogle(
        phone: _phoneController.text,
      );
      if (!mounted) return;
      _navigateByRole(UserRoleX.tryParse(user.role) ?? widget.selectedRole);
    } catch (_) {}
  }

  Future<void> _onEmailPressed() async {
    final phoneError = _validatePhone(_phoneController.text);
    if (phoneError != null) {
      setState(() => _phoneError = phoneError);
      return;
    }

    final notifier = ref.read(authProvider.notifier);
    try {
      final user = await notifier.continueWithEmail(
        phone: _phoneController.text,
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      _navigateByRole(UserRoleX.tryParse(user.role) ?? widget.selectedRole);
    } catch (_) {}
  }

  void _navigateByRole(UserRole role) {
    if (role == UserRole.owner) {
      context.goNamed('ownerDashboard');
      return;
    }
    context.goNamed('tenantPayments');
  }
}
