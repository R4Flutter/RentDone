import 'dart:ui';
import 'package:flutter/material.dart';

/// Glassmorphism Design System for RentDone
/// Combines frosted glass effect, backdrop blur, and modern aesthetics

class GlassmorphismConfig {
  // Blur amounts
  static const double blurAmount = 10.0;
  static const double strongBlurAmount = 20.0;

  // Opacity values
  static const double glassOpacity = 0.1;
  static const double strongGlassOpacity = 0.15;
  static const double cardOpacity = 0.08;

  // Border radius
  static const double borderRadiusSmall = 12.0;
  static const double borderRadiusMedium = 16.0;
  static const double borderRadiusLarge = 24.0;

  // Spacing
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 12.0;
  static const double paddingLarge = 16.0;
}

/// Creates a glassmorphic background container
class GlassContainer extends StatelessWidget {
  final Widget child;
  final Color? glassColor;
  final double borderRadius;
  final double blurAmount;
  final Color? borderColor;
  final double borderWidth;
  final EdgeInsets padding;
  final double opacity;
  final VoidCallback? onTap;
  final Gradient? gradient;

  const GlassContainer({
    super.key,
    required this.child,
    this.glassColor,
    this.borderRadius = GlassmorphismConfig.borderRadiusMedium,
    this.blurAmount = GlassmorphismConfig.blurAmount,
    this.borderColor,
    this.borderWidth = 1.5,
    this.padding = const EdgeInsets.all(GlassmorphismConfig.paddingLarge),
    this.opacity = GlassmorphismConfig.glassOpacity,
    this.onTap,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultColor = isDark ? Colors.white : Colors.black;
    final defaultBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.2)
        : Colors.black.withValues(alpha: 0.15);

    return GestureDetector(
      onTap: onTap,
      child: RepaintBoundary(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
            child: Container(
              decoration: BoxDecoration(
                gradient:
                    gradient ??
                    LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        (glassColor ?? defaultColor).withValues(alpha: opacity),
                        (glassColor ?? defaultColor).withValues(alpha: opacity * 0.5),
                      ],
                    ),
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: borderColor ?? defaultBorderColor,
                  width: borderWidth,
                ),
              ),
              padding: padding,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// Glassmorphic card for dashboard content
class GlassCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final Color? glassColor;
  final double? elevation;
  final EdgeInsets? margin;
  final EdgeInsets? padding;

  const GlassCard({
    super.key,
    required this.child,
    this.onTap,
    this.glassColor,
    this.elevation = 0,
    this.margin,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      glassColor: glassColor,
      borderRadius: GlassmorphismConfig.borderRadiusLarge,
      blurAmount: GlassmorphismConfig.blurAmount,
      padding:
          padding ?? const EdgeInsets.all(GlassmorphismConfig.paddingLarge),
      opacity: GlassmorphismConfig.cardOpacity,
      borderColor: Theme.of(context).brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.15)
          : Colors.black.withValues(alpha: 0.08),
      onTap: onTap,
      child: child,
    );
  }
}

/// Glassmorphic dialog with modern glass effect
class GlassDialog extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final Widget content;
  final List<Widget>? actions;
  final Color? backgroundColor;
  final double? titleFontSize;
  final TextStyle? titleStyle;
  final EdgeInsets? contentPadding;
  final EdgeInsets? actionsPadding;

  const GlassDialog({
    super.key,
    this.title,
    this.titleWidget,
    required this.content,
    this.actions,
    this.backgroundColor,
    this.titleFontSize,
    this.titleStyle,
    this.contentPadding,
    this.actionsPadding,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Center(
        child: SingleChildScrollView(
          child: GlassContainer(
            glassColor: isDark ? Colors.white : Colors.black,
            borderRadius: GlassmorphismConfig.borderRadiusLarge,
            blurAmount: GlassmorphismConfig.strongBlurAmount,
            opacity: GlassmorphismConfig.strongGlassOpacity,
            borderColor: isDark
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.white.withValues(alpha: 0.3),
            padding: EdgeInsets.zero,
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.85,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  if (title != null || titleWidget != null)
                    Padding(
                      padding: const EdgeInsets.all(
                        GlassmorphismConfig.paddingLarge,
                      ),
                      child:
                          titleWidget ??
                          Text(
                            title!,
                            style:
                                titleStyle ??
                                Theme.of(
                                  context,
                                ).textTheme.headlineSmall?.copyWith(
                                  color: textColor,
                                  fontWeight: FontWeight.w600,
                                ),
                            textAlign: TextAlign.center,
                          ),
                    ),
                  if (title != null || titleWidget != null)
                    Divider(
                      height: 1,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
                          : Colors.black.withValues(alpha: 0.1),
                    ),
                  // Content
                  Padding(
                    padding:
                        contentPadding ??
                        const EdgeInsets.all(GlassmorphismConfig.paddingLarge),
                    child: DefaultTextStyle(
                      style: TextStyle(color: textColor),
                      child: content,
                    ),
                  ),
                  // Actions
                  if (actions != null && actions!.isNotEmpty)
                    Padding(
                      padding:
                          actionsPadding ??
                          const EdgeInsets.all(
                            GlassmorphismConfig.paddingLarge,
                          ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: actions!.asMap().entries.map((entry) {
                            return Padding(
                              padding: EdgeInsets.only(
                                left: entry.key == 0
                                    ? 0
                                    : GlassmorphismConfig.paddingMedium,
                              ),
                              child: entry.value,
                            );
                          }).toList(),
                        ),
                      ),
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

/// Glassmorphic button with modern design
class GlassButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;
  final IconData? icon;
  final bool isPrimary;
  final bool isLoading;
  final double? width;
  final EdgeInsets? padding;
  final TextStyle? textStyle;

  const GlassButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.icon,
    this.isPrimary = false,
    this.isLoading = false,
    this.width,
    this.padding,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return SizedBox(
      width: width,
      child: GlassContainer(
        glassColor: isPrimary
            ? primaryColor
            : (isDark ? Colors.white : Colors.black),
        borderRadius: GlassmorphismConfig.borderRadiusMedium,
        blurAmount: GlassmorphismConfig.blurAmount,
        opacity: isPrimary ? 0.2 : GlassmorphismConfig.cardOpacity,
        padding: padding ?? const EdgeInsets.symmetric(vertical: 12),
        onTap: isLoading ? null : onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null && !isLoading)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(
                  icon,
                  size: 18,
                  color: isPrimary
                      ? primaryColor
                      : (isDark ? Colors.white : Colors.black87),
                ),
              ),
            if (isLoading)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(
                      isPrimary
                          ? primaryColor
                          : (isDark ? Colors.white : Colors.black87),
                    ),
                    strokeWidth: 2,
                  ),
                ),
              ),
            Text(
              label,
              style:
                  textStyle ??
                  TextStyle(
                    color: isPrimary
                        ? primaryColor
                        : (isDark ? Colors.white : Colors.black87),
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Glassmorphic app bar
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final List<Widget>? actions;
  final VoidCallback? onBack;
  final bool showBackButton;
  final double? elevation;
  final Color? backgroundColor;

  const GlassAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.actions,
    this.onBack,
    this.showBackButton = true,
    this.elevation = 0,
    this.backgroundColor,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        bottom: Radius.circular(GlassmorphismConfig.borderRadiusLarge),
      ),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GlassmorphismConfig.blurAmount,
          sigmaY: GlassmorphismConfig.blurAmount,
        ),
        child: AppBar(
          title:
              titleWidget ??
              (title != null
                  ? Text(
                      title!,
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    )
                  : null),
          backgroundColor:
              backgroundColor ??
              (isDark ? Colors.white : Colors.black).withValues(alpha: 
                GlassmorphismConfig.glassOpacity,
              ),
          elevation: elevation ?? 0,
          automaticallyImplyLeading: false,
          leading: showBackButton
              ? IconButton(
                  icon: Icon(Icons.arrow_back, color: textColor),
                  onPressed: onBack ?? () => Navigator.pop(context),
                )
              : null,
          actions: actions,
          centerTitle: false,
          flexibleSpace: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  width: 1,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Glassmorphic bottom sheet
class GlassBottomSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final bool showDragHandle;
  final Color? backgroundColor;

  const GlassBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.showDragHandle = true,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(GlassmorphismConfig.borderRadiusLarge),
        ),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(GlassmorphismConfig.borderRadiusLarge),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: GlassmorphismConfig.blurAmount,
            sigmaY: GlassmorphismConfig.blurAmount,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 
                GlassmorphismConfig.glassOpacity,
              ),
              border: Border(
                top: BorderSide(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.2)
                      : Colors.black.withValues(alpha: 0.1),
                  width: 1.5,
                ),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showDragHandle)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.3)
                            : Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                if (title != null)
                  Padding(
                    padding: const EdgeInsets.all(
                      GlassmorphismConfig.paddingLarge,
                    ),
                    child: Text(
                      title!,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Flexible(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Glassmorphic progress indicator
class GlassProgressIndicator extends StatelessWidget {
  final double value;
  final Color? color;
  final double height;

  const GlassProgressIndicator({
    super.key,
    required this.value,
    this.color,
    this.height = 4,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      glassColor: isDark ? Colors.white : Colors.black,
      borderRadius: height / 2,
      padding: EdgeInsets.zero,
      opacity: GlassmorphismConfig.cardOpacity,
      child: Stack(
        children: [
          SizedBox(height: height, width: double.infinity),
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(height / 2),
              child: Container(
                width: value,
                color: color ?? Theme.of(context).primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Extension for easy glass styling on text
extension GlassText on TextStyle {
  TextStyle withGlassEffect(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return copyWith(
      color: isDark ? Colors.white : Colors.black87,
      shadows: [
        Shadow(
          color: (isDark ? Colors.black : Colors.white).withValues(alpha: 0.1),
          offset: const Offset(0, 1),
          blurRadius: 2,
        ),
      ],
    );
  }
}

