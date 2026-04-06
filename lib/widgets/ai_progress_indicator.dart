import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    'Analyzing your background...',
    'Identifying skill gaps...',
    'Building your roadmap...',
    'Curating resources...',
  ];

  static const List<IconData> _icons = [
    Icons.person_search,
    Icons.psychology,
    Icons.map_outlined,
    Icons.library_books,
  ];

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GlassCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(_steps.length, (i) {
          final isCompleted = i < currentStep;
          final isActive = i == currentStep;

          Widget leading;
          if (isCompleted) {
            leading = const Icon(Icons.check_circle, color: Colors.green, size: 24);
          } else if (isActive) {
            leading = SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colorScheme.primary,
              ),
            );
          } else {
            leading = Icon(
              Icons.radio_button_unchecked,
              color: colorScheme.onSurface.withOpacity(0.3),
              size: 24,
            );
          }

          final stepRow = Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                leading,
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _steps[i],
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                      color: isActive
                          ? colorScheme.primary
                          : isCompleted
                              ? colorScheme.onSurface
                              : colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ),
                Icon(
                  _icons[i],
                  size: 18,
                  color: isActive
                      ? colorScheme.primary
                      : colorScheme.onSurface.withOpacity(0.3),
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
                    .shimmer(duration: 1500.ms, color: colorScheme.primary.withOpacity(0.3))
              else if (isCompleted)
                stepRow.animate().fadeIn(duration: 200.ms)
              else
                stepRow,
              if (i < _steps.length - 1)
                Row(
                  children: [
                    const SizedBox(width: 11),
                    Container(
                      width: 2,
                      height: 16,
                      color: isCompleted
                          ? Colors.green
                          : colorScheme.onSurface.withOpacity(0.15),
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
