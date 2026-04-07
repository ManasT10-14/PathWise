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

  /// Extracts the meaningful part of the milestone title.
  /// Strips the "Beginner — " / "Intermediate — " prefix if present.
  String _shortTitle() {
    final raw = widget.stage.title;
    for (final sep in [' — ', ' -- ', ' - ']) {
      final idx = raw.indexOf(sep);
      if (idx > 0 && idx < 30) {
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
        return 'Start here. Focus on understanding core concepts before jumping into projects. '
            'Follow the resources in order — each builds on the previous one.';
      case 'intermediate':
        return 'You have the basics. Now close your skill gaps with focused practice. '
            'Build small projects to solidify each concept before moving forward.';
      case 'advanced':
        return 'Push for mastery. Take on end-to-end projects, contribute to open source, '
            'and prepare for real-world scenarios. Teach what you learn.';
      default:
        return 'Work through the resources below and track your progress as you complete each topic.';
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
                      letterSpacing: 0.5,
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
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 20,
                    color: Colors.white.withOpacity(0.4),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Stage title — show cleaned version when collapsed, full when expanded
            Text(
              _expanded ? widget.stage.title : _shortTitle(),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
            ),
            // Show task tags when collapsed (if tasks exist)
            if (!_expanded && widget.stage.tasks.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: widget.stage.tasks.take(4).map((t) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppTheme.accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        t,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppTheme.accent.withOpacity(0.7),
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    )).toList(),
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
          // How to approach this stage
          _SectionHeader(icon: Icons.lightbulb_outline_rounded, title: 'How to approach', color: AppTheme.warning),
          const SizedBox(height: 6),
          Text(
            _approachTip(),
            style: theme.textTheme.bodySmall?.copyWith(color: muted, height: 1.5),
          ),

          const SizedBox(height: 16),

          // What you'll learn (extracted from the title)
          _SectionHeader(icon: Icons.checklist_rounded, title: 'What to focus on', color: AppTheme.accentSecondary),
          const SizedBox(height: 6),
          ..._extractFocusAreas().map((area) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Icon(Icons.arrow_right_rounded, size: 16, color: AppTheme.accentSecondary.withOpacity(0.7)),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        area,
                        style: theme.textTheme.bodySmall?.copyWith(color: muted, height: 1.4),
                      ),
                    ),
                  ],
                ),
              )),

          // Resources (clickable)
          if (widget.stage.resources.isNotEmpty) ...[
            const SizedBox(height: 16),
            _SectionHeader(icon: Icons.menu_book_rounded, title: 'Resources', color: AppTheme.accent),
            const SizedBox(height: 6),
            ...widget.stage.resources.map((r) {
              // Extract title and URL if format is "Title (URL)" or just URL
              final urlMatch = RegExp(r'(https?://\S+)').firstMatch(r);
              final url = urlMatch?.group(0);
              final title = url != null ? r.replaceAll(url, '').replaceAll('()', '').trim() : r;
              final displayTitle = title.isNotEmpty ? title : (url ?? r);

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
                        Icon(
                          url != null ? Icons.open_in_new_rounded : Icons.link_rounded,
                          size: 14,
                          color: AppTheme.accent.withOpacity(0.7),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayTitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: url != null ? AppTheme.accent : muted,
                                  fontWeight: FontWeight.w500,
                                  decoration: url != null ? TextDecoration.underline : null,
                                  decorationColor: AppTheme.accent.withOpacity(0.4),
                                  height: 1.4,
                                ),
                              ),
                              if (url != null && title.isNotEmpty)
                                Text(
                                  url,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: muted.withOpacity(0.6),
                                    fontSize: 10,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
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
                    Text(
                      'Your progress',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${(widget.progress * 100).round()}%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppTheme.accent,
                        fontWeight: FontWeight.w700,
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
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }

  /// Extracts focus areas from the milestone title by parsing after colons/dashes.
  List<String> _extractFocusAreas() {
    final raw = widget.stage.title;

    // Try to extract comma-separated topics from the title
    // e.g., "Beginner — Foundations: core syntax, tooling, and delivery of a small project."
    final colonIdx = raw.indexOf(':');
    if (colonIdx > 0 && colonIdx < raw.length - 1) {
      final afterColon = raw.substring(colonIdx + 1).trim();
      // Split on commas and ", and "
      final parts = afterColon
          .replaceAll(', and ', ', ')
          .replaceAll(' and ', ', ')
          .split(',')
          .map((s) => s.trim().replaceAll(RegExp(r'[.]$'), ''))
          .where((s) => s.isNotEmpty && s.length > 2)
          .toList();
      if (parts.isNotEmpty) return parts;
    }

    // Fallback: split on semicolons
    final semiParts = raw
        .split(';')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty && s.length > 5)
        .toList();
    if (semiParts.length > 1) return semiParts;

    // Final fallback — just show the whole description as a single point
    return [raw];
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.color,
  });

  final IconData icon;
  final String title;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                fontSize: 10,
              ),
        ),
      ],
    );
  }
}
