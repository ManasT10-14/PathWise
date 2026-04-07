import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../models/app_user.dart';
import '../models/consultation.dart';
import '../models/roadmap.dart';
import '../providers/app_services.dart';
import '../theme/app_theme.dart';
import '../theme/glass_card.dart';
import '../theme/gradient_background.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton_loader.dart';
import 'consultation_detail_screen.dart';
import 'roadmap_detail_screen.dart';

class JourneyScreen extends StatefulWidget {
  const JourneyScreen({super.key, required this.appUser});

  final AppUser appUser;

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  int _tab = 0; // 0 = Roadmaps, 1 = Consultations

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('My Journey')),
      body: GradientBackground(
        variant: GradientVariant.secondary,
        child: Column(
          children: [
            // Segmented toggle
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.06)
                      : Colors.black.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    _ToggleTab(
                      label: 'Roadmaps',
                      icon: Icons.map_rounded,
                      isActive: _tab == 0,
                      onTap: () => setState(() => _tab = 0),
                    ),
                    _ToggleTab(
                      label: 'Consultations',
                      icon: Icons.people_rounded,
                      isActive: _tab == 1,
                      onTap: () => setState(() => _tab = 1),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 300.ms),

            // Content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _tab == 0
                    ? _RoadmapsView(
                        key: const ValueKey('roadmaps'),
                        appUser: widget.appUser,
                      )
                    : _ConsultationsView(
                        key: const ValueKey('consultations'),
                        appUser: widget.appUser,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Toggle tab button
// ---------------------------------------------------------------------------

class _ToggleTab extends StatelessWidget {
  const _ToggleTab({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.accent.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isActive
                ? Border.all(color: AppTheme.accent.withOpacity(0.3))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isActive
                    ? AppTheme.accent
                    : (isDark ? Colors.white.withOpacity(0.4) : Colors.black38),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive
                      ? AppTheme.accent
                      : (isDark ? Colors.white.withOpacity(0.5) : Colors.black45),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Roadmaps tab
// ---------------------------------------------------------------------------

class _RoadmapsView extends StatelessWidget {
  const _RoadmapsView({super.key, required this.appUser});

  final AppUser appUser;

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<List<Roadmap>>(
      stream: svc.roadmaps.watchForUser(appUser.uid),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: SkeletonLoader.list(itemCount: 3),
          );
        }

        final roadmaps = snap.data!;
        if (roadmaps.isEmpty) {
          return EmptyStateWidget(
            title: 'No Roadmaps Yet',
            subtitle: 'Generate your first AI-powered roadmap from the home screen',
            icon: Icons.map_outlined,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          itemCount: roadmaps.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final r = roadmaps[i];
            final progress = r.stageProgress.values.isEmpty
                ? 0.0
                : r.stageProgress.values.reduce((a, b) => a + b) /
                    r.stageProgress.values.length;

            return GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => RoadmapDetailScreen(roadmapId: r.id),
                ),
              ),
              child: GlassCard(
                glowColor: progress >= 1.0 ? AppTheme.success : null,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Progress circle
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircularProgressIndicator(
                            value: progress.clamp(0, 1),
                            strokeWidth: 4,
                            backgroundColor: Colors.white.withOpacity(0.06),
                            color: progress >= 1.0
                                ? AppTheme.success
                                : AppTheme.accent,
                          ),
                          Text(
                            '${(progress * 100).round()}%',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            r.targetRole.isEmpty ? 'Roadmap' : r.targetRole,
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            r.timeline,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? Colors.white.withOpacity(0.5)
                                  : Colors.black45,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (r.replanVersion != null && r.replanVersion! > 1)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.auto_fix_high, size: 12, color: AppTheme.accent.withOpacity(0.7)),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Version ${r.replanVersion}',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppTheme.accent.withOpacity(0.7),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark ? Colors.white.withOpacity(0.3) : Colors.black26,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: (i * 80).ms, duration: 300.ms).slideY(begin: 0.05, end: 0),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Consultations tab
// ---------------------------------------------------------------------------

class _ConsultationsView extends StatelessWidget {
  const _ConsultationsView({super.key, required this.appUser});

  final AppUser appUser;

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppTheme.warning;
      case 'accepted':
        return AppTheme.success;
      case 'completed':
        return AppTheme.accent;
      case 'cancelled':
        return AppTheme.error;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.schedule_rounded;
      case 'accepted':
        return Icons.check_circle_outline_rounded;
      case 'completed':
        return Icons.task_alt_rounded;
      case 'cancelled':
        return Icons.cancel_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<List<Consultation>>(
      stream: svc.consultations.watchForUser(appUser.uid),
      builder: (context, snap) {
        if (!snap.hasData) {
          return Padding(
            padding: const EdgeInsets.all(20),
            child: SkeletonLoader.list(itemCount: 3),
          );
        }

        final consultations = snap.data!;
        if (consultations.isEmpty) {
          return EmptyStateWidget(
            title: 'No Consultations Yet',
            subtitle: 'Book a session with an expert from the home screen',
            icon: Icons.people_outline_rounded,
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
          itemCount: consultations.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) {
            final c = consultations[i];
            final statusColor = _statusColor(c.status);

            return GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ConsultationDetailScreen(
                    consultationId: c.id,
                    appUser: appUser,
                    expertDocId: c.expertId,
                  ),
                ),
              ),
              child: GlassCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Status icon
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(_statusIcon(c.status), color: statusColor, size: 22),
                    ),
                    const SizedBox(width: 14),
                    // Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${c.type.toUpperCase()} Session',
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  c.status.toUpperCase(),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              if (c.scheduledAt != null) ...[
                                Icon(Icons.calendar_today_rounded, size: 12,
                                    color: isDark ? Colors.white.withOpacity(0.4) : Colors.black38),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat.yMMMd().add_jm().format(c.scheduledAt!),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark ? Colors.white.withOpacity(0.5) : Colors.black45,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              Text(
                                'INR ${c.price}',
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: AppTheme.accent,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark ? Colors.white.withOpacity(0.3) : Colors.black26,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: (i * 80).ms, duration: 300.ms).slideY(begin: 0.05, end: 0),
            );
          },
        );
      },
    );
  }
}
