import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/app_theme.dart';
import '../theme/glass_card.dart';

class AiProgressIndicator extends StatelessWidget {
  const AiProgressIndicator({
    super.key,
    required this.currentStep,
    this.totalSteps = 4,
  });

  final int currentStep;
  final int totalSteps;

  static const List<String> _steps = [
    'Analyzing your background',
    'Identifying skill gaps',
    'Building your roadmap',
    'Curating resources',
  ];

  static const List<IconData> _icons = [
    Icons.person_search_rounded,
    Icons.psychology_rounded,
    Icons.map_rounded,
    Icons.library_books_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GlassCard(
      glowColor: AppTheme.accent,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_steps.length, (i) {
          final isCompleted = i < currentStep;
          final isActive = i == currentStep;

          Widget leading;
          if (isCompleted) {
            leading = Container(
              width: 28,
              height: 28,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.success,
              ),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
            );
          } else if (isActive) {
            leading = Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.accent, width: 2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.accent,
                ),
              ),
            );
          } else {
            leading = Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.15) : Colors.black12,
                  width: 2,
                ),
              ),
            );
          }

          final stepRow = Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    _steps[i],
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                      color: isActive
                          ? (isDark ? Colors.white : Colors.black87)
                          : isCompleted
                              ? (isDark ? Colors.white.withOpacity(0.7) : Colors.black54)
                              : (isDark ? Colors.white.withOpacity(0.25) : Colors.black26),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppTheme.accent.withOpacity(0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    _icons[i],
                    size: 18,
                    color: isActive
                        ? AppTheme.accent
                        : isCompleted
                            ? AppTheme.success.withOpacity(0.6)
                            : (isDark ? Colors.white.withOpacity(0.15) : Colors.black12),
                  ),
                ),
              ],
            ),
          );

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isActive)
                stepRow
                    .animate()
                    .fadeIn()
                    .shimmer(duration: 1800.ms, color: AppTheme.accent.withOpacity(0.2))
              else if (isCompleted)
                stepRow.animate().fadeIn(duration: 200.ms)
              else
                stepRow,
              if (i < _steps.length - 1)
                Row(
                  children: [
                    const SizedBox(width: 13),
                    Container(
                      width: 2,
                      height: 12,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(1),
                        color: isCompleted
                            ? AppTheme.success.withOpacity(0.5)
                            : (isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06)),
                      ),
                    ),
                  ],
                ),
            ],
          );
        }),
      ),
    );
  }
}
