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
              if (list.isEmpty) {
                return EmptyStateWidget(
                  title: 'No Bookings Yet',
                  subtitle: 'Your consultation requests will appear here',
                  icon: Icons.calendar_today_outlined,
                );
              }

              return ListView.separated(
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
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        c.type.toUpperCase(),
                                        style: theme.textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.bold,
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
                                      onTap: () {
                                        // Per EXP-04: pass roadmapId=c.consultationId (backend looks up
                                        // user's active roadmap via userId), learnerId=c.userId.
                                        Navigator.of(context).push(
                                          MaterialPageRoute<void>(
                                            builder: (_) => ExpertAnnotationScreen(
                                              roadmapId: c.consultationId,
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
                },
              );
            },
          );
        },
      ),
      ),
    );
  }
}
