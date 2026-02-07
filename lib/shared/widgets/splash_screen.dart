import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';


class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
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
  ).animate(
    CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutExpo,
    ),
  );

  _controller.forward();

  // Navigate after 3 seconds
  Future.delayed(const Duration(seconds: 3), () {
    if (!mounted) return;
    context.goNamed('roleSelection');
  });
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
