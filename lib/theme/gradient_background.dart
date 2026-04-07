import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_theme.dart';

enum GradientVariant { primary, secondary, accent }

class GradientBackground extends StatelessWidget {
  const GradientBackground({
    super.key,
    required this.child,
    this.variant = GradientVariant.primary,
  });

  final Widget child;
  final GradientVariant variant;

  List<Color> _darkColors() {
    switch (variant) {
      case GradientVariant.primary:
        return const [
          Color(0xFF080B14),
          Color(0xFF0C1124),
          Color(0xFF111833),
        ];
      case GradientVariant.secondary:
        return const [
          Color(0xFF080B14),
          Color(0xFF0E0B24),
          Color(0xFF14082E),
        ];
      case GradientVariant.accent:
        return const [
          Color(0xFF080B14),
          Color(0xFF1A0E08),
          Color(0xFF0D1117),
        ];
    }
  }

  List<Color> _lightColors() {
    switch (variant) {
      case GradientVariant.primary:
        return const [Color(0xFFEEF1F8), Color(0xFFE8ECF5), Color(0xFFF0F2F8)];
      case GradientVariant.secondary:
        return const [Color(0xFFF0EDF8), Color(0xFFECECF8), Color(0xFFF0F2F8)];
      case GradientVariant.accent:
        return const [Color(0xFFF8F0ED), Color(0xFFF5F0ED), Color(0xFFF0F2F8)];
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark ? _darkColors() : _lightColors();

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
        // Subtle glow orbs for depth (dark mode only)
        if (isDark) ...[
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accent.withOpacity(0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.accentSecondary.withOpacity(0.05),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
        child,
      ],
    );
  }
}
