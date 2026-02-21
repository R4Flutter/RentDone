import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:rentdone/core/constants/user_role.dart';
import 'package:rentdone/features/auth/di/auth_di.dart';

class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _logoScale;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _logoScale = Tween<double>(
      begin: 1.2,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutExpo));

    _controller.forward();

    _navigateAfterBoot();
  }

  Future<void> _navigateAfterBoot() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    final auth = ref.read(firebaseAuthProvider);
    final user = auth.currentUser;
    if (user == null) {
      context.goNamed('roleSelection');
      return;
    }

    final role = await ref.read(authRepositoryProvider).getUserRole(user.uid);
    if (!mounted) return;

    switch (role) {
      case UserRole.owner:
        context.goNamed('ownerDashboard');
        break;
      case UserRole.tenant:
        context.goNamed('tenantPayments');
        break;
      default:
        context.goNamed('roleSelection');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Scaffold(
      backgroundColor: colors.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            /// LOGO (ZOOM-OUT)
            AnimatedBuilder(
              animation: _logoScale,
              builder: (context, child) {
                return Transform.scale(scale: _logoScale.value, child: child);
              },
              child: Image.asset('assets/images/rentdone_logo.png', width: 290),
            ),

            const SizedBox(height: 8),

            /// APP NAME
            Transform.translate(
              offset: const Offset(-3, 0),
              child: Text(
                'RENTDONE',
                style: textTheme.displayMedium?.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                  color: colors.onSurface,
                  letterSpacing: 0.6,
                ),
              ),
            ),

            const SizedBox(height: 6),

            /// TAGLINE
            Text(
              'Leave the Rent Worries to RentDone',
              style: textTheme.bodyMedium?.copyWith(
                color: colors.onSurface.withValues(alpha: 0.7),
                letterSpacing: 1.2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
