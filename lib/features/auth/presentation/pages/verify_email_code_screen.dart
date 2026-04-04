import 'dart:async';
import 'dart:ui';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/app/app_theme.dart';
import 'package:rentdone/core/constants/user_role.dart';

class VerifyEmailCodeScreen extends StatefulWidget {
  const VerifyEmailCodeScreen({
    super.key,
    required this.selectedRole,
    required this.phoneNumber,
    required this.email,
  });

  final UserRole selectedRole;
  final String phoneNumber;
  final String email;

  @override
  State<VerifyEmailCodeScreen> createState() => _VerifyEmailCodeScreenState();
}

class _VerifyEmailCodeScreenState extends State<VerifyEmailCodeScreen> {
  final _codeController = TextEditingController();
  bool _isVerifying = false;
  bool _isCheckingStatus = false;
  bool _isResending = false;
  String? _error;
  int _resendCooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _resendCooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCooldown <= 1) {
        timer.cancel();
        setState(() => _resendCooldown = 0);
        return;
      }
      setState(() => _resendCooldown -= 1);
    });
  }

  String _extractActionCode(String input) {
    final value = input.trim();
    if (value.isEmpty) return '';

    final uri = Uri.tryParse(value);
    final codeFromUri = uri?.queryParameters['oobCode'];
    if (codeFromUri != null && codeFromUri.trim().isNotEmpty) {
      return codeFromUri.trim();
    }

    final regex = RegExp(r'oobCode=([^&\s]+)');
    final match = regex.firstMatch(value);
    if (match != null && match.groupCount >= 1) {
      return (match.group(1) ?? '').trim();
    }

    return value;
  }

  Future<void> _verifyCode() async {
    if (_isVerifying) return;

    final rawInput = _codeController.text.trim();
    final code = _extractActionCode(rawInput);
    if (code.isEmpty) {
      setState(() => _error = 'Paste the verification link from your email.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _error = null;
    });

    try {
      final auth = FirebaseAuth.instance;
      final info = await auth.checkActionCode(code);
      final actionEmail =
          (info.data['email'] ?? '').toString().trim().toLowerCase();
      final expectedEmail = widget.email.trim().toLowerCase();

      if (expectedEmail.isNotEmpty &&
          actionEmail.isNotEmpty &&
          actionEmail != expectedEmail) {
        throw FirebaseAuthException(
          code: 'invalid-action-code',
          message: 'This verification link belongs to another email.',
        );
      }

      await auth.applyActionCode(code);
      await auth.currentUser?.reload();

      if (!mounted) return;

      final currentUser = auth.currentUser;
      if (currentUser != null && currentUser.emailVerified) {
        if (widget.selectedRole == UserRole.owner) {
          context.goNamed('ownerDashboard');
        } else {
          context.goNamed('tenantDashboard');
        }
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email verified. Please sign in now.')),
      );

      final loginUri = Uri(
        path: '/login',
        queryParameters: {
          'role': widget.selectedRole.name,
          'phone': widget.phoneNumber,
        },
      );
      context.go(loginUri.toString());
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Unable to verify link. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isVerifying = false);
      }
    }
  }

  Future<void> _resendCode() async {
    if (_isResending || _resendCooldown > 0) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _error =
            'Session expired. Sign in again and request a verification link.';
      });
      return;
    }

    setState(() {
      _isResending = true;
      _error = null;
    });

    try {
      await user.sendEmailVerification();
      _startCooldown(60);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Verification link sent. Check Primary, Updates, Promotions, and Spam folders.',
          ),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(error));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Could not resend code. Please try again.');
    } finally {
      if (mounted) {
        setState(() => _isResending = false);
      }
    }
  }

  Future<void> _checkVerificationStatus() async {
    if (_isCheckingStatus) return;

    setState(() {
      _isCheckingStatus = true;
      _error = null;
    });

    try {
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;
      if (user == null) {
        setState(() {
          _error =
              'Session expired. Sign in again, then click the verification link from your email.';
        });
        return;
      }

      await user.reload();
      final refreshed = auth.currentUser;
      if (!mounted) return;

      if (refreshed != null && refreshed.emailVerified) {
        if (widget.selectedRole == UserRole.owner) {
          context.goNamed('ownerDashboard');
        } else {
          context.goNamed('tenantDashboard');
        }
        return;
      }

      setState(() {
        _error =
            'Email is still not verified. Open the verification link from your inbox/spam, then tap "I have verified".';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not check verification status. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isCheckingStatus = false);
      }
    }
  }

  String _friendlyError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-action-code':
      case 'expired-action-code':
        return 'Verification link is invalid or expired. Request a new one.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'No internet connection. Please retry.';
      default:
        return error.message ?? 'Something went wrong. Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = OwnerDashboardColors.isDark(context);

    return Scaffold(
      backgroundColor: OwnerDashboardColors.pageBackground(context),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: OwnerDashboardColors.ownerPageBackgroundGradient(
                  context,
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(26),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: isDark
                                ? [
                                    Colors.white.withValues(alpha: 0.12),
                                    OwnerDashboardColors.brandPrimary(
                                      context,
                                    ).withValues(alpha: 0.14),
                                  ]
                                : [
                                    Colors.white.withValues(alpha: 0.94),
                                    OwnerDashboardColors.brandPrimary(
                                      context,
                                    ).withValues(alpha: 0.12),
                                  ],
                          ),
                          border: Border.all(
                            color: OwnerDashboardColors.brandPrimary(
                              context,
                            ).withValues(alpha: isDark ? 0.34 : 0.18),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Verify Your Email',
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(
                                    color: OwnerDashboardColors.textPrimary(
                                      context,
                                    ),
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Firebase sends a verification link (not OTP code) to ${widget.email}. Open that email and paste the full link below.',
                              style: TextStyle(
                                color: OwnerDashboardColors.textSecondary(
                                  context,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'If not visible, check Primary, Updates, Promotions, and Spam. Search for "Firebase" or "verify your email".',
                              style: TextStyle(
                                color: OwnerDashboardColors.textSecondary(
                                  context,
                                ),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 14),
                            TextField(
                              controller: _codeController,
                              autocorrect: false,
                              enableSuggestions: false,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _verifyCode(),
                              style: TextStyle(
                                color: OwnerDashboardColors.textPrimary(context),
                              ),
                              decoration: InputDecoration(
                                labelText: 'Paste Verification Link',
                                prefixIcon: const Icon(
                                  Icons.verified_user_rounded,
                                ),
                                filled: true,
                                fillColor: isDark
                                    ? Colors.white.withValues(alpha: 0.08)
                                    : Colors.white.withValues(alpha: 0.78),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 10),
                              Text(
                                _error!,
                                style: const TextStyle(
                                  color: AppTheme.errorRed,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            SizedBox(
                              height: 52,
                              child: FilledButton.icon(
                                onPressed: _isVerifying ? null : _verifyCode,
                                icon: _isVerifying
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(Icons.check_circle_rounded),
                                label: Text(
                                  _isVerifying ? 'Verifying...' : 'Verify Link',
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            OutlinedButton.icon(
                              onPressed: _isCheckingStatus
                                  ? null
                                  : _checkVerificationStatus,
                              icon: _isCheckingStatus
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.refresh_rounded),
                              label: Text(
                                _isCheckingStatus
                                    ? 'Checking...'
                                    : 'I have verified',
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: (_isResending || _resendCooldown > 0)
                                  ? null
                                  : _resendCode,
                              child: Text(
                                _resendCooldown > 0
                                    ? 'Resend in $_resendCooldown s'
                                    : (_isResending
                                          ? 'Sending...'
                                          : 'Resend Verification Link'),
                              ),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: () async {
                                await FirebaseAuth.instance.signOut();
                                if (!context.mounted) return;
                                context.go(
                                  '/phone?role=${widget.selectedRole.name}',
                                );
                              },
                              icon: const Icon(Icons.switch_account_rounded),
                              label: const Text('Use Different Email'),
                            ),
                            TextButton(
                              onPressed: () {
                                final loginUri = Uri(
                                  path: '/login',
                                  queryParameters: {
                                    'role': widget.selectedRole.name,
                                    'phone': widget.phoneNumber,
                                  },
                                );
                                context.go(loginUri.toString());
                              },
                              child: const Text('Back to Sign In'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
