import 'package:flutter/material.dart' as m;
import 'package:lottie/lottie.dart';

class AppLoadingIndicator extends m.StatelessWidget {
  const AppLoadingIndicator({
    super.key,
    this.color,
    this.strokeWidth = 4,
    this.value,
    this.backgroundColor,
    this.valueColor,
    this.semanticsLabel,
    this.semanticsValue,
  });

  static const String _assetPath = 'assets/animations/app_loader.lottie';

  final m.Color? color;
  final double strokeWidth;
  final double? value;
  final m.Color? backgroundColor;
  final m.Animation<m.Color?>? valueColor;
  final String? semanticsLabel;
  final String? semanticsValue;

  @override
  m.Widget build(m.BuildContext context) {
    final compact = strokeWidth <= 2.2;
    final size = compact ? 26.0 : 86.0;

    m.Widget child = m.SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        _assetPath,
        repeat: true,
        fit: m.BoxFit.contain,
        errorBuilder: (context, _, __) => m.CircularProgressIndicator(
          color: color,
          strokeWidth: strokeWidth,
          value: value,
          backgroundColor: backgroundColor,
          valueColor: valueColor,
          semanticsLabel: semanticsLabel,
          semanticsValue: semanticsValue,
        ),
      ),
    );

    if (color != null) {
      child = m.ColorFiltered(
        colorFilter: m.ColorFilter.mode(color!, m.BlendMode.srcIn),
        child: child,
      );
    }

    if (semanticsLabel != null || semanticsValue != null) {
      child = m.Semantics(
        label: semanticsLabel,
        value: semanticsValue,
        child: child,
      );
    }

    return child;
  }
}
