import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';

Future<void> showForgotPasswordDialog({
  required BuildContext context,
  required WidgetRef ref,
  required String initialEmail,
  required ValueChanged<String> onEmailSynced,
}) async {
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black.withAlpha(45),
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
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSending = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [Colors.white.withAlpha(20), Colors.white.withAlpha(10)]
                    : [
                        Colors.white.withAlpha(186),
                        Colors.white.withAlpha(140),
                      ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: AppTheme.liquidPrimaryStart.withAlpha(48),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.liquidShadow.withAlpha(70),
                  blurRadius: 22,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        gradient:
                            OwnerDashboardColors.managePropertiesAccentGradient(
                              context,
                            ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        color: AppColors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Forgot Password',
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color:
                              OwnerDashboardColors.managePropertiesHeaderPrimary(
                                context,
                              ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Enter your account email and we will send a password reset verification code.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: OwnerDashboardColors.managePropertiesHeaderSecondary(
                      context,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) {
                    if (_emailError != null) {
                      setState(() => _emailError = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Email address',
                    hintText: 'name@example.com',
                    prefixIcon: Icon(
                      Icons.alternate_email_rounded,
                      color: OwnerDashboardColors.managePropertiesActionColor(
                        context,
                      ),
                    ),
                    filled: true,
                    fillColor: AppTheme.pureWhite.withAlpha(100),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    errorText: _emailError,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppTheme.liquidPrimaryStart.withAlpha(40),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppTheme.liquidPrimaryStart.withAlpha(40),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppTheme.liquidPrimaryEnd.withAlpha(180),
                        width: 1.3,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: OutlinedButton(
                          onPressed: _isSending
                              ? null
                              : () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            side: BorderSide(
                              color:
                                  OwnerDashboardColors.managePropertiesActionColor(
                                    context,
                                  ),
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: FilledButton.icon(
                          onPressed: _isSending ? null : _sendReset,
                          style: FilledButton.styleFrom(
                            backgroundColor:
                                OwnerDashboardColors.managePropertiesActionColor(
                                  context,
                                ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: _isSending
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.send_outlined, size: 16),
                          label: Text(_isSending ? 'Sending...' : 'Send Code'),
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
    );
  }
}
