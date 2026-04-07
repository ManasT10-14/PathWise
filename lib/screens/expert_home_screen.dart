import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../models/app_user.dart';
import '../models/consultation.dart';
import '../models/expert.dart';
import '../providers/app_services.dart';
import '../theme/app_theme.dart';
import '../theme/glass_card.dart';
import '../theme/gradient_background.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton_loader.dart';
import 'consultation_detail_screen.dart';
import 'expert_annotation_screen.dart';

class ExpertHomeScreen extends StatelessWidget {
  const ExpertHomeScreen({super.key, required this.appUser});

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

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expert Console'),
        actions: [
          IconButton(
            onPressed: () => svc.auth.signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: GradientBackground(
        variant: GradientVariant.secondary,
        child: FutureBuilder<Expert?>(
        future: svc.experts.findExpertForUser(uid: appUser.uid, email: appUser.email),
        builder: (context, expertSnap) {
          if (!expertSnap.hasData) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: SkeletonLoader.list(itemCount: 3),
            );
          }

          final expert = expertSnap.data;
          if (expert == null) {
            return EmptyStateWidget(
              title: 'No Expert Profile',
              subtitle:
                  'No expert profile linked to this account. Ask an admin to create an experts document with your email.',
              icon: Icons.person_off_outlined,
            );
          }

          return StreamBuilder<List<Consultation>>(
            stream: svc.consultations.watchForExpert(expert.id),
            builder: (context, snap) {
              if (!snap.hasData) {
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: SkeletonLoader.list(itemCount: 3),
                );
              }

              final list = snap.data!;
              final pending = list.where((c) => c.status == 'pending').length;
              final completed = list.where((c) => c.status == 'completed').length;
              final accepted = list.where((c) => c.status == 'accepted').length;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Expert profile summary
                  GlassCard(
                    glowColor: AppTheme.accent,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: colorScheme.primaryContainer,
                          child: Text(
                            expert.name.isNotEmpty ? expert.name[0].toUpperCase() : '?',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      expert.name,
                                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (expert.isVerified)
                                    const Icon(Icons.verified_rounded, size: 18, color: AppTheme.accentSecondary),
                                ],
                              ),
                              if (expert.domain.isNotEmpty)
                                Text(
                                  expert.domain,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppTheme.accent,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${expert.rating.toStringAsFixed(1)} (${expert.totalReviews} reviews)',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 300.ms),

                  const SizedBox(height: 12),

                  // Quick stats row
                  Row(
                    children: [
                      _StatChip(label: 'Pending', value: '$pending', color: AppTheme.warning),
                      const SizedBox(width: 8),
                      _StatChip(label: 'Active', value: '$accepted', color: AppTheme.accent),
                      const SizedBox(width: 8),
                      _StatChip(label: 'Done', value: '$completed', color: AppTheme.success),
                      const SizedBox(width: 8),
                      _StatChip(label: 'Total', value: '${list.length}', color: AppTheme.accentSecondary),
                    ],
                  ).animate().fadeIn(delay: 100.ms, duration: 300.ms),

                  const SizedBox(height: 20),

                  Text(
                    'Consultations',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),

                  if (list.isEmpty)
                    EmptyStateWidget(
                      title: 'No Bookings Yet',
                      subtitle: 'Your consultation requests will appear here',
                      icon: Icons.calendar_today_outlined,
                    )
                  else
                    ...List.generate(list.length, (i) {
                      final c = list[i];
                      final statusColor = _statusColor(c.status);

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                padding: const EdgeInsets.all(16),
                itemCount: list.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final c = list[i];
                  final statusColor = _statusColor(c.status);

                  return GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ConsultationDetailScreen(
                          consultationId: c.id,
                          appUser: appUser,
                          expertDocId: expert.id,
                        ),
                      ),
                    ),
                    child: GlassCard(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: statusColor.withOpacity(0.15),
                            child: Icon(
                              Icons.person_outline,
                              color: statusColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Show learner name
                                FutureBuilder(
                                  future: svc.users.fetchUser(c.userId),
                                  builder: (ctx, userSnap) {
                                    final learnerName = userSnap.data?.name ?? 'Learner';
                                    return Text(
                                      learnerName,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    );
                                  },
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        '${c.type.toUpperCase()} session',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurface.withOpacity(0.6),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: statusColor.withOpacity(0.5)),
                                      ),
                                      child: Text(
                                        c.status,
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (c.scheduledAt != null)
                                  Text(
                                    DateFormat.yMMMd().add_jm().format(c.scheduledAt!),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurface.withOpacity(0.6),
                                    ),
                                  ),
                                Text(
                                  'INR ${c.price}',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    color: colorScheme.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          c.status == 'completed'
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.chevron_right, color: colorScheme.outline),
                                    const SizedBox(height: 4),
                                    GestureDetector(
                                      onTap: () async {
                                        // Look up the learner's latest roadmap
                                        final roadmapSnap = await svc.roadmaps
                                            .watchForUser(c.userId)
                                            .first;
                                        if (roadmapSnap.isEmpty) {
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('This learner has no roadmap yet'),
                                              ),
                                            );
                                          }
                                          return;
                                        }
                                        final latestRoadmap = roadmapSnap.first;
                                        if (!context.mounted) return;
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => ExpertAnnotationScreen(
                                              roadmapId: latestRoadmap.id,
                                              learnerId: c.userId,
                                              consultationId: c.id,
                                            ),
                                          ),
                                        );
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: colorScheme.primaryContainer,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Annotate',
                                          style: TextStyle(
                                            color: colorScheme.onPrimaryContainer,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Icon(Icons.chevron_right, color: colorScheme.outline),
                        ],
                      ),
                    ).animate().fadeIn(delay: (i * 80).ms).slideY(begin: 0.05, end: 0),
                      );
                    }),
                  const SizedBox(height: 80),
                ],
              );
            },
          );
        },
      ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Column(
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white.withOpacity(0.4),
                    fontSize: 10,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
