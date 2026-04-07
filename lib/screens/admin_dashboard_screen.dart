import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/app_user.dart';
import '../theme/app_theme.dart';
import '../models/consultation.dart';
import '../models/expert.dart';
import '../models/review.dart';
import '../providers/app_services.dart';
import '../theme/glass_card.dart';
import '../theme/gradient_background.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton_loader.dart';
import 'consultation_detail_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, required this.appUser});

  final AppUser appUser;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _tab = 0;

  // ---------------------------------------------------------------------------
  // Analytics helpers
  // ---------------------------------------------------------------------------

  /// Future that resolves when all three platform stat queries complete.
  late final Future<_PlatformStats> _statsFuture = _loadStats();

  Future<_PlatformStats> _loadStats() async {
    final db = FirebaseFirestore.instance;
    final results = await Future.wait([
      db.collection('users').count().get(),
      db.collection('roadmaps').count().get(),
      db.collection('consultations')
          .where(
            'createdAt',
            isGreaterThan: Timestamp.fromDate(
              DateTime.now().subtract(const Duration(days: 7)),
            ),
          )
          .count()
          .get(),
    ]);
    return _PlatformStats(
      totalUsers: results[0].count ?? 0,
      activeRoadmaps: results[1].count ?? 0,
      consultationsThisWeek: results[2].count ?? 0,
    );
  }

  // ---------------------------------------------------------------------------
  // Expert verification actions (ADM-02)
  // ---------------------------------------------------------------------------

  Future<void> _approveExpert(String expertId) async {
    await context.svc.experts.setVerified(expertId, true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expert approved and verified')),
      );
    }
  }

  Future<void> _rejectExpert(String expertId, String expertName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Expert'),
        content: Text(
          'Are you sure you want to reject and remove "$expertName"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await FirebaseFirestore.instance
        .collection('experts')
        .doc(expertId)
        .update({'isVerified': false, 'status': 'rejected'});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expert rejected')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Review moderation actions (ADM-03)
  // ---------------------------------------------------------------------------

  Future<void> _flagReview(String reviewId) async {
    await FirebaseFirestore.instance
        .collection('reviews')
        .doc(reviewId)
        .update({'flagged': true});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review flagged for moderation')),
      );
    }
  }

  Future<void> _deleteReview(String reviewId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Review'),
        content: const Text('Permanently delete this review? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await context.svc.reviews.deleteReview(reviewId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review deleted')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(onPressed: () => svc.auth.signOut(), icon: const Icon(Icons.logout)),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.analytics_outlined), label: 'Analytics'),
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.pending_actions_outlined), label: 'Applicants'),
          NavigationDestination(icon: Icon(Icons.badge_outlined), label: 'Experts'),
          NavigationDestination(icon: Icon(Icons.reviews_outlined), label: 'Reviews'),
        ],
      ),
      body: GradientBackground(
        variant: GradientVariant.accent,
        child: IndexedStack(
          index: _tab,
          children: [
            // ----------------------------------------------------------------
            // Tab 0: Analytics (ADM-01)
            // ----------------------------------------------------------------
            _AnalyticsTab(statsFuture: _statsFuture),

            // ----------------------------------------------------------------
            // Tab 1: Users
            // ----------------------------------------------------------------
            StreamBuilder<List<AppUser>>(
              stream: svc.users.watchAllUsers(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: SkeletonLoader.list(itemCount: 4),
                  );
                }
                final list = snap.data!;
                if (list.isEmpty) {
                  return EmptyStateWidget(
                    title: 'No Users',
                    subtitle: 'No users registered yet',
                    icon: Icons.people_outline,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final u = list[i];
                    return GlassCard(
                      padding: const EdgeInsets.all(12),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: colorScheme.primaryContainer,
                          child: Text(
                            u.name.isNotEmpty ? u.name[0].toUpperCase() : '?',
                            style: TextStyle(color: colorScheme.onPrimaryContainer),
                          ),
                        ),
                        title: Text(u.name),
                        subtitle: Text('${u.email} • ${u.role.name}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) async {
                            if (v == 'admin') await svc.users.setRole(u.uid, UserRole.admin);
                            if (v == 'expert') {
                              await svc.users.setRole(u.uid, UserRole.expert);
                              // Auto-create expert profile so expert can log in immediately
                              await svc.experts.createForUser(
                                uid: u.uid,
                                name: u.name,
                                email: u.email,
                              );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Expert profile created. User can now log in as expert.')),
                                );
                              }
                            }
                            if (v == 'user') await svc.users.setRole(u.uid, UserRole.user);
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'user', child: Text('Set role: user')),
                            PopupMenuItem(value: 'expert', child: Text('Set role: expert')),
                            PopupMenuItem(value: 'admin', child: Text('Set role: admin')),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: (i * 50).ms);
                  },
                );
              },
            ),

            // ----------------------------------------------------------------
            // Tab 2: Expert Applications
            // ----------------------------------------------------------------
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: svc.experts.watchApplications(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: SkeletonLoader.list(itemCount: 3),
                  );
                }
                final apps = snap.data!;
                if (apps.isEmpty) {
                  return EmptyStateWidget(
                    title: 'No Applications',
                    subtitle: 'Expert applications from users will appear here',
                    icon: Icons.pending_actions_outlined,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: apps.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final app = apps[i];
                    final status = app['status'] as String? ?? 'pending';
                    final isPending = status == 'pending';
                    final statusColor = isPending
                        ? AppTheme.warning
                        : status == 'approved'
                            ? AppTheme.success
                            : AppTheme.error;

                    return GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: colorScheme.primaryContainer,
                                child: Text(
                                  (app['name'] as String? ?? '?')[0].toUpperCase(),
                                  style: TextStyle(color: colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      app['name'] as String? ?? 'Unknown',
                                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                    ),
                                    Text(
                                      app['email'] as String? ?? '',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: colorScheme.onSurface.withOpacity(0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // Domain & Experience
                          if ((app['domain'] as String?)?.isNotEmpty == true)
                            _AppInfoRow(icon: Icons.category_rounded, label: 'Domain', value: app['domain'] as String),
                          if ((app['experience'] as String?)?.isNotEmpty == true)
                            _AppInfoRow(icon: Icons.work_outline_rounded, label: 'Experience', value: app['experience'] as String),
                          if ((app['qualification'] as String?)?.isNotEmpty == true)
                            _AppInfoRow(icon: Icons.school_rounded, label: 'Qualification', value: app['qualification'] as String),
                          if ((app['linkedinUrl'] as String?)?.isNotEmpty == true)
                            _AppInfoRow(icon: Icons.link_rounded, label: 'LinkedIn', value: app['linkedinUrl'] as String),
                          if (app['pricing'] is Map) ...[
                            _AppInfoRow(icon: Icons.chat_rounded, label: 'Chat rate', value: 'INR ${(app['pricing'] as Map)['chat'] ?? '—'}'),
                            _AppInfoRow(icon: Icons.call_rounded, label: 'Call rate', value: 'INR ${(app['pricing'] as Map)['call'] ?? '—'}'),
                            _AppInfoRow(icon: Icons.videocam_rounded, label: 'Video rate', value: 'INR ${(app['pricing'] as Map)['video'] ?? '—'}'),
                          ] else if (app['pricePerSession'] != null)
                            _AppInfoRow(icon: Icons.currency_rupee_rounded, label: 'Price/session', value: 'INR ${app['pricePerSession']}'),
                          if ((app['whyMentor'] as String?)?.isNotEmpty == true)
                            _AppInfoRow(icon: Icons.favorite_outline_rounded, label: 'Motivation', value: app['whyMentor'] as String),
                          if ((app['skills'] as List?)?.isNotEmpty == true) ...[
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: (app['skills'] as List).take(6).map((s) => Chip(
                                label: Text(s.toString(), style: const TextStyle(fontSize: 10)),
                                visualDensity: VisualDensity.compact,
                                padding: EdgeInsets.zero,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              )).toList(),
                            ),
                          ],
                          if (isPending) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.icon(
                                    onPressed: () async {
                                      await svc.experts.approveApplication(app['id'] as String, app);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Expert approved and profile created!')),
                                        );
                                      }
                                    },
                                    icon: const Icon(Icons.check_rounded, size: 18),
                                    label: const Text('Approve'),
                                    style: FilledButton.styleFrom(backgroundColor: AppTheme.success),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () async {
                                      await svc.experts.rejectApplication(app['id'] as String);
                                    },
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    label: const Text('Reject'),
                                    style: OutlinedButton.styleFrom(foregroundColor: AppTheme.error),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ).animate().fadeIn(delay: (i * 60).ms);
                  },
                );
              },
            ),

            // ----------------------------------------------------------------
            // Tab 3: Experts (ADM-02)
            // ----------------------------------------------------------------
            StreamBuilder<List<Expert>>(
              stream: svc.experts.watchExperts(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: SkeletonLoader.list(itemCount: 4),
                  );
                }
                final list = snap.data!;
                if (list.isEmpty) {
                  return EmptyStateWidget(
                    title: 'No Experts',
                    subtitle: 'No expert profiles created yet',
                    icon: Icons.badge_outlined,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final e = list[i];
                    return GlassCard(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: e.isVerified
                                    ? AppTheme.success.withOpacity(0.15)
                                    : AppTheme.warning.withOpacity(0.15),
                                child: Icon(
                                  e.isVerified ? Icons.verified : Icons.pending,
                                  color: e.isVerified ? AppTheme.success : AppTheme.warning,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      e.name,
                                      style: theme.textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      e.email,
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ],
                                ),
                              ),
                              Chip(
                                label: Text(e.isVerified ? 'Verified' : 'Pending'),
                                backgroundColor: e.isVerified
                                    ? AppTheme.success.withOpacity(0.2)
                                    : AppTheme.warning.withOpacity(0.2),
                                labelStyle: TextStyle(
                                  color: e.isVerified ? AppTheme.success : AppTheme.warning,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          if (!e.isVerified) ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton.tonal(
                                    onPressed: () => _approveExpert(e.id),
                                    child: const Text('Approve'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: AppTheme.error),
                                    ),
                                    onPressed: () => _rejectExpert(e.id, e.name),
                                    child: const Text('Reject'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ).animate().fadeIn(delay: (i * 50).ms);
                  },
                );
              },
            ),

            // ----------------------------------------------------------------
            // Tab 3: Consultations
            // ----------------------------------------------------------------
            StreamBuilder<List<Consultation>>(
              stream: svc.consultations.watchAll(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: SkeletonLoader.list(itemCount: 4),
                  );
                }
                final list = snap.data!;
                if (list.isEmpty) {
                  return EmptyStateWidget(
                    title: 'No Consultations',
                    subtitle: 'No consultations booked yet',
                    icon: Icons.event_note_outlined,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final c = list[i];
                    return GlassCard(
                      padding: const EdgeInsets.all(12),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(c.status.toUpperCase()),
                        subtitle: Text('user ${c.userId} • expert ${c.expertId}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => ConsultationDetailScreen(
                              consultationId: c.id,
                              appUser: widget.appUser,
                              expertDocId: c.expertId,
                            ),
                          ),
                        ),
                      ),
                    ).animate().fadeIn(delay: (i * 50).ms);
                  },
                );
              },
            ),

            // ----------------------------------------------------------------
            // Tab 4: Reviews (ADM-03)
            // ----------------------------------------------------------------
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('reviews').snapshots(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: SkeletonLoader.list(itemCount: 4),
                  );
                }
                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return EmptyStateWidget(
                    title: 'No Reviews',
                    subtitle: 'No reviews submitted yet',
                    icon: Icons.reviews_outlined,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: docs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final raw = docs[i].data();
                    final r = Review.fromFirestore(docs[i].id, raw);
                    final isFlagged = raw['flagged'] == true;
                    return GlassCard(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            backgroundColor: Colors.amber.withOpacity(0.15),
                            child: Text(
                              '${r.rating}',
                              style: const TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    ...List.generate(
                                      5,
                                      (idx) => Icon(
                                        idx < r.rating
                                            ? Icons.star
                                            : Icons.star_border,
                                        size: 14,
                                        color: Colors.amber,
                                      ),
                                    ),
                                    if (isFlagged) ...[
                                      const SizedBox(width: 6),
                                      Chip(
                                        label: const Text('Flagged'),
                                        backgroundColor: AppTheme.error.withOpacity(0.15),
                                        labelStyle: const TextStyle(
                                          color: AppTheme.error,
                                          fontSize: 10,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  r.feedback,
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            children: [
                              IconButton(
                                icon: Icon(
                                  Icons.flag,
                                  color: isFlagged ? AppTheme.error : colorScheme.onSurface.withOpacity(0.5),
                                ),
                                tooltip: 'Flag review',
                                onPressed: isFlagged ? null : () => _flagReview(r.id),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: AppTheme.error),
                                tooltip: 'Delete review',
                                onPressed: () => _deleteReview(r.id),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ).animate().fadeIn(delay: (i * 50).ms);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Analytics tab widget (ADM-01)
// ---------------------------------------------------------------------------

class _PlatformStats {
  const _PlatformStats({
    required this.totalUsers,
    required this.activeRoadmaps,
    required this.consultationsThisWeek,
  });

  final int totalUsers;
  final int activeRoadmaps;
  final int consultationsThisWeek;
}

class _AnalyticsTab extends StatelessWidget {
  const _AnalyticsTab({required this.statsFuture});

  final Future<_PlatformStats> statsFuture;

  static const _stats = [
    (label: 'Total Users', icon: Icons.people),
    (label: 'Active Roadmaps', icon: Icons.map),
    (label: 'Consultations This Week', icon: Icons.calendar_today),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<_PlatformStats>(
      future: statsFuture,
      builder: (context, snap) {
        final counts = snap.hasData
            ? [
                snap.data!.totalUsers,
                snap.data!.activeRoadmaps,
                snap.data!.consultationsThisWeek,
              ]
            : null;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Platform Analytics',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 16),

            // Stat cards row
            Row(
              children: List.generate(3, (i) {
                final stat = _stats[i];
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : 6, right: i == 2 ? 0 : 6),
                    child: GlassCard(
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
                      child: Column(
                        children: [
                          Icon(stat.icon, size: 28, color: theme.colorScheme.primary),
                          const SizedBox(height: 8),
                          counts != null
                              ? Text(
                                  '${counts[i]}',
                                  style: theme.textTheme.headlineMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: theme.colorScheme.primary,
                                  ),
                                )
                              : const SizedBox(
                                  height: 24,
                                  width: 24,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                          const SizedBox(height: 4),
                          Text(
                            stat.label,
                            style: theme.textTheme.bodySmall,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                          ),
                        ],
                      ),
                    )
                        .animate()
                        .fadeIn(delay: (i * 150).ms)
                        .slideY(begin: 0.1, end: 0, delay: (i * 150).ms),
                  ),
                );
              }),
            ),

            if (snap.hasError) ...[
              const SizedBox(height: 16),
              GlassCard(
                child: Text(
                  'Failed to load analytics: ${snap.error}',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            ],

            const SizedBox(height: 24),
            Text(
              'Quick Overview',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ).animate().fadeIn(delay: 450.ms),
            const SizedBox(height: 12),
            GlassCard(
              child: Column(
                children: [
                  _OverviewRow(
                    icon: Icons.people,
                    label: 'Registered Users',
                    value: counts != null ? '${counts[0]}' : '—',
                  ),
                  const Divider(height: 16),
                  _OverviewRow(
                    icon: Icons.map,
                    label: 'Roadmaps Generated',
                    value: counts != null ? '${counts[1]}' : '—',
                  ),
                  const Divider(height: 16),
                  _OverviewRow(
                    icon: Icons.calendar_today,
                    label: 'Consultations (7 days)',
                    value: counts != null ? '${counts[2]}' : '—',
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 500.ms),
          ],
        );
      },
    );
  }
}

class _OverviewRow extends StatelessWidget {
  const _OverviewRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _AppInfoRow extends StatelessWidget {
  const _AppInfoRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.4)),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodySmall,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
