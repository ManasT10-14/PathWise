import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';

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

  String _cleanTitle() {
    final raw = widget.stage.title;
    // Strip level prefix like "Beginner — " or "Intermediate -- "
    for (final sep in [' — ', ' -- ', ' - ']) {
      final idx = raw.indexOf(sep);
      if (idx > 0 && idx < 25) {
        return raw.substring(idx + sep.length).trim();
      }
    }
    return raw;
  }

  String _levelLabel() {
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

  IconData _levelIcon() {
    switch (widget.stage.level.toLowerCase()) {
      case 'beginner':
        return Icons.school_rounded;
      case 'intermediate':
        return Icons.trending_up_rounded;
      case 'advanced':
        return Icons.rocket_launch_rounded;
      default:
        return Icons.circle_outlined;
    }
  }

  String _approachTip() {
    switch (widget.stage.level.toLowerCase()) {
      case 'beginner':
        return 'Start here. Focus on understanding core concepts before jumping into practice. Follow the resources in order.';
      case 'intermediate':
        return 'You have the basics. Now close your skill gaps with focused practice. Build small projects to solidify each concept.';
      case 'advanced':
        return 'Push for mastery. Take on end-to-end challenges, seek feedback, and prepare for real-world scenarios.';
      default:
        return 'Work through the tasks below and track your progress as you complete each one.';
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
              width: 44,
              child: Column(
                children: [
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
                  _buildNodeCircle(statusColor),
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
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(theme, statusColor),
                      _buildProgressBar(statusColor),
                      if (_expanded) _buildExpandedContent(theme, isDark),
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
    final taskCount = widget.stage.tasks.length;

    return GestureDetector(
      onTap: () => setState(() => _expanded = !_expanded),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: level badge + progress + expand icon
            Row(
              children: [
                Icon(_levelIcon(), size: 16, color: statusColor),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _levelLabel(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: statusColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '${(widget.progress * 100).round()}%',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more_rounded, size: 20, color: Colors.white.withOpacity(0.4)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Stage title
            Text(
              _cleanTitle(),
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            // Task count hint when collapsed
            if (!_expanded && taskCount > 0) ...[
              const SizedBox(height: 6),
              Text(
                '$taskCount tasks to complete  •  Tap to expand',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: AppTheme.accent.withOpacity(0.6),
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
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

  Widget _buildExpandedContent(ThemeData theme, bool isDark) {
    final muted = isDark ? Colors.white.withOpacity(0.5) : Colors.black54;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // How to approach
          _SectionHeader(icon: Icons.lightbulb_outline_rounded, title: 'How to approach', color: AppTheme.warning),
          const SizedBox(height: 6),
          Text(_approachTip(), style: theme.textTheme.bodySmall?.copyWith(color: muted, height: 1.5)),

          const SizedBox(height: 16),

          // Tasks
          if (widget.stage.tasks.isNotEmpty) ...[
            _SectionHeader(icon: Icons.checklist_rounded, title: 'Tasks (${widget.stage.tasks.length})', color: AppTheme.accentSecondary),
            const SizedBox(height: 8),
            ...widget.stage.tasks.asMap().entries.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        margin: const EdgeInsets.only(top: 1),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppTheme.accentSecondary.withOpacity(0.4), width: 1.5),
                        ),
                        child: Center(
                          child: Text(
                            '${entry.key + 1}',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: AppTheme.accentSecondary.withOpacity(0.7)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.value,
                          style: theme.textTheme.bodySmall?.copyWith(color: muted, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                )),
          ],

          // Resources
          if (widget.stage.resources.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionHeader(icon: Icons.menu_book_rounded, title: 'Resources (${widget.stage.resources.length})', color: AppTheme.accent),
            const SizedBox(height: 8),
            ...widget.stage.resources.map((r) {
              final urlMatch = RegExp(r'(https?://\S+)').firstMatch(r);
              final url = urlMatch?.group(0)?.replaceAll(RegExp(r'[)\]]+$'), '');
              final rawTitle = url != null ? r.replaceAll(url, '').replaceAll(RegExp(r'[()\[\]]'), '').trim() : r;
              final displayTitle = rawTitle.isNotEmpty ? rawTitle : (url ?? r);

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GestureDetector(
                  onTap: url != null
                      ? () async {
                          final uri = Uri.tryParse(url);
                          if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      : null,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.accent.withOpacity(0.1)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            url != null ? Icons.open_in_new_rounded : Icons.link_rounded,
                            size: 14,
                            color: AppTheme.accent.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            displayTitle,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: url != null ? AppTheme.accent : muted,
                              fontWeight: FontWeight.w500,
                              decoration: url != null ? TextDecoration.underline : null,
                              decorationColor: AppTheme.accent.withOpacity(0.4),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ],

          // Progress slider
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.speed_rounded, size: 16, color: AppTheme.accent.withOpacity(0.6)),
                    const SizedBox(width: 6),
                    Text('Your progress', style: theme.textTheme.labelSmall?.copyWith(color: muted, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('${(widget.progress * 100).round()}%', style: theme.textTheme.labelMedium?.copyWith(color: AppTheme.accent, fontWeight: FontWeight.w700)),
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
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  List<String> _extractFocusAreas() {
    final raw = widget.stage.title;
    final colonIdx = raw.indexOf(':');
    if (colonIdx > 0 && colonIdx < raw.length - 1) {
      final afterColon = raw.substring(colonIdx + 1).trim();
      final parts = afterColon
          .replaceAll(', and ', ', ')
          .replaceAll(' and ', ', ')
          .split(',')
          .map((s) => s.trim().replaceAll(RegExp(r'[.]$'), ''))
          .where((s) => s.isNotEmpty && s.length > 2)
          .toList();
      if (parts.isNotEmpty) return parts;
    }
    return [raw];
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.title, required this.color});
  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  fontSize: 10,
                ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
