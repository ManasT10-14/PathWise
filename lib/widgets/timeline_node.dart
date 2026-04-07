import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/roadmap.dart';
import '../theme/app_theme.dart';
import '../theme/glass_card.dart';

extension _StringCapitalize on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}

class TimelineNode extends StatefulWidget {
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
  State<TimelineNode> createState() => _TimelineNodeState();
}

class _TimelineNodeState extends State<TimelineNode> {
  bool _expanded = false;

  Color _statusColor() {
    if (widget.progress >= 1.0) return AppTheme.success;
    if (widget.isCurrent) return AppTheme.accent;
    return Colors.white.withOpacity(0.25);
  }

  IconData _statusIcon() {
    if (widget.progress >= 1.0) return Icons.check_rounded;
    if (widget.isCurrent) return Icons.play_arrow_rounded;
    return Icons.circle_outlined;
  }

  String _levelEmoji() {
    switch (widget.stage.level.toLowerCase()) {
      case 'beginner':
        return 'Foundation';
      case 'intermediate':
        return 'Growth';
      case 'advanced':
        return 'Mastery';
      default:
        return widget.stage.level.capitalize();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final statusColor = _statusColor();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Timeline spine
            SizedBox(
              width: 48,
              child: Column(
                children: [
                  // Top connector
                  Container(
                    width: 2,
                    height: 16,
                    decoration: widget.isFirst
                        ? null
                        : BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                widget.progress >= 1.0 ? AppTheme.success : AppTheme.accent.withOpacity(0.3),
                                statusColor,
                              ],
                            ),
                          ),
                  ),
                  // Node circle
                  _buildNodeCircle(statusColor),
                  // Bottom connector
                  Expanded(
                    child: Container(
                      width: 2,
                      color: widget.isLast
                          ? Colors.transparent
                          : (widget.progress >= 1.0
                              ? AppTheme.success.withOpacity(0.5)
                              : Colors.white.withOpacity(0.08)),
                    ),
                  ),
                ],
              ),
            ),
            // Content card
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: GlassCard(
                  glowColor: widget.isCurrent ? AppTheme.accent : null,
                  padding: EdgeInsets.zero,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header (always visible)
                      _buildHeader(theme, statusColor),
                      // Progress bar
                      _buildProgressBar(statusColor),
                      // Expandable content
                      if (_expanded) _buildExpandedContent(theme),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (widget.index * 120).ms, duration: 400.ms).slideX(begin: 0.08, end: 0);
  }

  Widget _buildNodeCircle(Color color) {
    Widget circle = Container(
      width: widget.isCurrent ? 24 : 16,
      height: widget.isCurrent ? 24 : 16,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: widget.progress < 1.0 && !widget.isCurrent
            ? Border.all(color: Colors.white.withOpacity(0.15), width: 2)
            : null,
        boxShadow: widget.isCurrent
            ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 12, spreadRadius: 1)]
            : null,
      ),
      child: widget.progress >= 1.0
          ? const Icon(Icons.check_rounded, size: 12, color: Colors.white)
          : null,
    );

    if (widget.isCurrent) {
      circle = circle
          .animate(onPlay: (c) => c.repeat())
          .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 1200.ms)
          .then()
          .scale(begin: const Offset(1.15, 1.15), end: const Offset(1, 1), duration: 1200.ms);
    }

    return circle;
  }

  Widget _buildHeader(ThemeData theme, Color statusColor) {
    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
        child: Row(
          children: [
            // Level badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: statusColor.withOpacity(0.3)),
              ),
              child: Text(
                _levelEmoji(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: statusColor,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Title
            Expanded(
              child: Text(
                widget.stage.title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            // Progress percentage
            Text(
              '${(widget.progress * 100).round()}%',
              style: theme.textTheme.titleMedium?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            // Expand icon
            AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.expand_more_rounded,
                size: 20,
                color: Colors.white.withOpacity(0.4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: widget.progress.clamp(0, 1),
          minHeight: 4,
          backgroundColor: Colors.white.withOpacity(0.06),
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      ),
    );
  }

  Widget _buildExpandedContent(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Resources
          if (widget.stage.resources.isNotEmpty) ...[
            Text(
              'Resources',
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppTheme.accentSecondary,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 6),
            ...widget.stage.resources.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Icon(Icons.link_rounded, size: 14, color: AppTheme.accent.withOpacity(0.7)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          r.length > 50 ? '${r.substring(0, 50)}...' : r,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white.withOpacity(0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )),
          ],
          // Progress slider
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                'Update progress',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
              const Spacer(),
              Text(
                '${(widget.progress * 100).round()}%',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SliderTheme(
            data: SliderThemeData(
              trackHeight: 6,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: AppTheme.accent,
              inactiveTrackColor: Colors.white.withOpacity(0.06),
              thumbColor: AppTheme.accent,
              overlayColor: AppTheme.accent.withOpacity(0.15),
            ),
            child: Slider(
              value: widget.progress.clamp(0, 1),
              onChanged: widget.onProgressChanged,
              min: 0,
              max: 1,
              divisions: 20,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}
