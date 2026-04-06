import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';

class EmailVerificationPage extends ConsumerStatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  ConsumerState<EmailVerificationPage> createState() =>
      _EmailVerificationPageState();
}

class _EmailVerificationPageState extends ConsumerState<EmailVerificationPage> {
  bool _sending = false;
  bool _checking = false;

  Future<void> _sendVerificationEmail() async {
    if (_sending) return;
    setState(() => _sending = true);

    try {
      final auth = ref.read(firebaseAuthProvider);
      final user = auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        context.go('/login');
        return;
      }

      await user.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent. Check inbox/spam.'),
        ),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message ?? 'Unable to send verification email.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to send verification email.')),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _checkVerificationAndContinue() async {
    if (_checking) return;
    setState(() => _checking = true);

    try {
      final auth = ref.read(firebaseAuthProvider);
      final user = auth.currentUser;
      if (user == null) {
        if (!mounted) return;
        context.go('/login');
        return;
      }

      await user.reload();
      final refreshed = auth.currentUser;
      if (refreshed != null &&
          (refreshed.emailVerified ||
              refreshed.email == null ||
              refreshed.email!.isEmpty)) {
        if (!mounted) return;
        context.go('/');
        return;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email not verified yet. Please verify and try again.'),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to refresh verification status.')),
      );
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _signOut() async {
    await ref.read(authRepositoryProvider).signOut();
    if (!mounted) return;
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(firebaseAuthProvider).currentUser;
    final email = (user?.email ?? '').trim();

    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.mark_email_read_outlined, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Please verify your email before continuing.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    email.isEmpty
                        ? 'Your account does not have an email address.'
                        : 'Verification email: $email',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _sending ? null : _sendVerificationEmail,
                    child: Text(
                      _sending ? 'Sending...' : 'Resend Verification Email',
                    ),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _checking ? null : _checkVerificationAndContinue,
                    child: Text(_checking ? 'Checking...' : 'I Have Verified'),
                  ),
                  const SizedBox(height: 10),
                  TextButton(
                    onPressed: _signOut,
                    child: const Text('Sign Out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
