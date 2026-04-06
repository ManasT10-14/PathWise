import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/roadmap.dart';
import '../theme/glass_card.dart';

extension _StringCapitalize on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

class TimelineNode extends StatelessWidget {
  const TimelineNode({
    super.key,
    required this.stage,
    required this.progress,
    required this.isFirst,
    required this.isLast,
    required this.isCurrent,
    required this.onProgressChanged,
    this.index = 0,
  });

  final RoadmapStage stage;
  final double progress;
  final bool isFirst;
  final bool isLast;
  final bool isCurrent;
  final ValueChanged<double> onProgressChanged;
  final int index;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    Widget nodeCircle = Container(
      width: isCurrent ? 20 : 14,
      height: isCurrent ? 20 : 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: progress >= 1.0
            ? Colors.green
            : isCurrent
                ? colorScheme.primary
                : colorScheme.outline.withOpacity(0.3),
        boxShadow: isCurrent
            ? [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
    );

    if (isCurrent) {
      nodeCircle = nodeCircle
          .animate(onPlay: (c) => c.repeat())
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.2, 1.2),
            duration: 1000.ms,
          )
          .then()
          .scale(
            begin: const Offset(1.2, 1.2),
            end: const Offset(1, 1),
            duration: 1000.ms,
          );
    }

    final card = GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(stage.title, style: textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Level: ${stage.level.capitalize()}',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          if (stage.tasks.isNotEmpty) ...[
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text('Tasks (${stage.tasks.length})', style: textTheme.labelMedium),
              children: stage.tasks
                  .map(
                    (task) => CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: false,
                      onChanged: null,
                      title: Text(task, style: textTheme.bodySmall),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (stage.resources.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: stage.resources
                  .map(
                    (r) => Chip(
                      label: Text(
                        r.length > 30 ? '${r.substring(0, 30)}...' : r,
                        style: textTheme.labelSmall,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          const SizedBox(height: 8),
          Slider(
            value: progress.clamp(0, 1),
            onChanged: onProgressChanged,
            min: 0,
            max: 1,
            divisions: 20,
          ),
          Text(
            '${(progress * 100).round()}% complete',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 48,
          child: Column(
            children: [
              Container(
                width: 2,
                height: 24,
                color: isFirst ? Colors.transparent : colorScheme.primary,
              ),
              nodeCircle,
              Expanded(
                child: Container(
                  width: 2,
                  color: isLast
                      ? Colors.transparent
                      : colorScheme.primary.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 16),
            child: card
                .animate()
                .fadeIn(delay: (index * 100).ms)
                .slideX(begin: 0.1, end: 0),
          ),
        ),
      ],
    );
  }
}
