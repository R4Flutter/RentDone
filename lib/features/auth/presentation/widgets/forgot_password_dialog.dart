import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';
import 'package:rentdone/shared/design/glassmorphism.dart';

Future<void> showForgotPasswordDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String initialEmail,
  required ValueChanged<String> onEmailSynced,
}) async {
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (_) => _ForgotPasswordDialog(
      ref: ref,
      initialEmail: initialEmail,
      onEmailSynced: onEmailSynced,
    ),
  );
}

class _ForgotPasswordDialog extends ConsumerStatefulWidget {
  const _ForgotPasswordDialog({
    required this.ref,
    required this.initialEmail,
    required this.onEmailSynced,
  });

  final WidgetRef ref;
  final String initialEmail;
  final ValueChanged<String> onEmailSynced;

  @override
  ConsumerState<_ForgotPasswordDialog> createState() =>
      _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends ConsumerState<_ForgotPasswordDialog> {
  late final TextEditingController _emailController;
  bool _isSending = false;
  String? _emailError;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    final email = _emailController.text.trim();
    final emailRegex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

    if (email.isEmpty) {
      setState(() => _emailError = 'Please enter your email address.');
      return;
    }

    if (!emailRegex.hasMatch(email)) {
      setState(() => _emailError = 'Enter a valid email address.');
      return;
    }

    setState(() {
      _emailError = null;
      _isSending = true;
    });

    try {
      await widget.ref
          .read(authRepositoryProvider)
          .sendPasswordResetCode(email: email);
      if (!mounted) return;

      widget.onEmailSynced(email);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Reset email sent successfully. Please check inbox and spam.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final brandColor = OwnerDashboardColors.brandPrimary(context);

    return GlassDialog(
      title: 'Forgot Password',
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enter your email address and we will send you a password reset link.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: OwnerDashboardColors.textSecondary(context),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            onChanged: (_) {
              if (_emailError != null) setState(() => _emailError = null);
            },
            decoration: InputDecoration(
              labelText: 'Email Address',
              prefixIcon: Icon(Icons.email_outlined, size: 20, color: brandColor),
              errorText: _emailError,
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
                borderSide: BorderSide(color: brandColor, width: 1.5),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isSending ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        GlassButton(
          onPressed: _sendReset,
          label: 'Send Reset Link',
          isPrimary: true,
          isLoading: _isSending,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ],
    );
  }
}
