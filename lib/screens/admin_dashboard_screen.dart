import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../models/app_user.dart';
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
          NavigationDestination(icon: Icon(Icons.people_outline), label: 'Users'),
          NavigationDestination(icon: Icon(Icons.badge_outlined), label: 'Experts'),
          NavigationDestination(icon: Icon(Icons.event_note_outlined), label: 'Consults'),
          NavigationDestination(icon: Icon(Icons.reviews_outlined), label: 'Reviews'),
        ],
      ),
      body: GradientBackground(
        variant: GradientVariant.accent,
        child: IndexedStack(
          index: _tab,
          children: [
            // Users tab
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
                            if (v == 'expert') await svc.users.setRole(u.uid, UserRole.expert);
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

            // Experts tab
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
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(e.name),
                        subtitle: Text(e.email),
                        secondary: CircleAvatar(
                          backgroundColor: e.isVerified
                              ? Colors.green.withOpacity(0.15)
                              : Colors.orange.withOpacity(0.15),
                          child: Icon(
                            e.isVerified ? Icons.verified : Icons.pending,
                            color: e.isVerified ? Colors.green : Colors.orange,
                          ),
                        ),
                        value: e.isVerified,
                        onChanged: (v) => svc.experts.setVerified(e.id, v),
                      ),
                    ).animate().fadeIn(delay: (i * 50).ms);
                  },
                );
              },
            ),

            // Consultations tab
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
                        title: Text(c.status),
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

            // Reviews tab
            StreamBuilder<List<Review>>(
              stream: svc.reviews.watchAll(),
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
                    title: 'No Reviews',
                    subtitle: 'No reviews submitted yet',
                    icon: Icons.reviews_outlined,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final r = list[i];
                    return GlassCard(
                      padding: const EdgeInsets.all(12),
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Colors.amber.withOpacity(0.15),
                          child: Text(
                            '${r.rating}',
                            style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text('${r.rating} stars'),
                        subtitle: Text(r.feedback, maxLines: 2, overflow: TextOverflow.ellipsis),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          onPressed: () => svc.reviews.deleteReview(r.id),
                        ),
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
