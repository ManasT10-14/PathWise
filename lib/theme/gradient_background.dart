import 'package:flutter/material.dart';

enum GradientVariant { primary, secondary, accent }

class GradientBackground extends StatelessWidget {
  const GradientBackground({
    super.key,
    required this.child,
    this.variant = GradientVariant.primary,
  });

  final Widget child;
  final GradientVariant variant;

  List<Color> _gradientColors() {
    switch (variant) {
      case GradientVariant.primary:
        return const [Color(0xFF1B5E20), Color(0xFF0D47A1), Color(0xFF1A237E)];
      case GradientVariant.secondary:
        return const [Color(0xFF4A148C), Color(0xFF0D47A1), Color(0xFF00695C)];
      case GradientVariant.accent:
        return const [Color(0xFFE65100), Color(0xFFBF360C), Color(0xFF4E342E)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _gradientColors();

    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
          ),
        ),
        if (!isDark)
          Container(
            color: Colors.white.withOpacity(0.85),
          ),
        child,
      ],
    );
  }
}
