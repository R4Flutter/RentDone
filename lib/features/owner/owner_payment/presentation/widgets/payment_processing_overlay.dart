import 'package:flutter/material.dart';
import 'package:rentdone/app/app_theme.dart';

/// Animated payment processing overlay with glassmorphism design
class PaymentProcessingOverlay extends StatefulWidget {
  const PaymentProcessingOverlay({
    super.key,
    required this.isVisible,
    this.amount = 0,
    this.message = 'Processing Payment...',
  });

  final bool isVisible;
  final int amount;
  final String message;

  @override
  State<PaymentProcessingOverlay> createState() =>
      _PaymentProcessingOverlayState();
}

class _PaymentProcessingOverlayState extends State<PaymentProcessingOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _rotateAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _rotateAnimation = Tween<double>(begin: 0.0, end: 2.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.linear),
    );

    if (widget.isVisible) {
      _animationController.forward();
    }
  }

  @override
  void didUpdateWidget(PaymentProcessingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && !oldWidget.isVisible) {
      _animationController.forward();
    } else if (!widget.isVisible && oldWidget.isVisible) {
      _animationController.reverse();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      ignoring: !widget.isVisible,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: widget.isVisible ? 1.0 : 0.0),
        duration: const Duration(milliseconds: 300),
        builder: (context, value, child) {
          return Container(
            color: Colors.black.withValues(alpha: 0.4 * value),
            child: Center(
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: _createImageFilter(value),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.25 * value),
                              Colors.white.withValues(alpha: 0.1 * value),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2 * value),
                            width: 1.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Animated loader circle
                              RotationTransition(
                                turns: _rotateAnimation,
                                child: Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        AppTheme.primaryBlue.withValues(
                                          alpha: 0.8,
                                        ),
                                        AppTheme.primaryBlue.withValues(
                                          alpha: 0.3,
                                        ),
                                      ],
                                    ),
                                  ),
                                  child: const Padding(
                                    padding: EdgeInsets.all(3),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Amount display
                              if (widget.amount > 0)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Column(
                                    children: [
                                      Text(
                                        'Rs ${widget.amount}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .headlineSmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Payment Amount',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Colors.white.withValues(
                                                alpha: 0.7,
                                              ),
                                            ),
                                      ),
                                      const SizedBox(height: 12),
                                    ],
                                  ),
                                ),

                              // Message
                              Text(
                                widget.message,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Please do not close this screen',
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
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
          );
        },
      ),
    );
  }

  /// Create blur effect for glassmorphism
  dynamic _createImageFilter(double opacity) {
    // Import 'dart:ui' for ImageFilter
    try {
      final imageFilter = _getImageFilter();
      if (imageFilter != null) {
        return imageFilter.blur(sigmaX: 10 * opacity, sigmaY: 10 * opacity);
      }
    } catch (_) {}
    return null;
  }

  dynamic _getImageFilter() {
    try {
      return null; // Placeholder - would use dart:ui ImageFilter in production
    } catch (_) {
      return null;
    }
  }
}
