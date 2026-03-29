import 'package:flutter/material.dart';
import '../models/app_user.dart';
import '../models/consultation.dart';
import '../models/expert.dart';
import '../models/review.dart';
import '../providers/app_services.dart';
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
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
      body: IndexedStack(
        index: _tab,
        children: [
          StreamBuilder<List<AppUser>>(
            stream: svc.users.watchAllUsers(),
            builder: (context, snap) {
              final list = snap.data ?? [];
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final u = list[i];
                  return ListTile(
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
                  );
                },
              );
            },
          ),
          StreamBuilder<List<Expert>>(
            stream: svc.experts.watchExperts(),
            builder: (context, snap) {
              final list = snap.data ?? [];
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final e = list[i];
                  return SwitchListTile(
                    title: Text(e.name),
                    subtitle: Text(e.email),
                    value: e.isVerified,
                    onChanged: (v) => svc.experts.setVerified(e.id, v),
                  );
                },
              );
            },
          ),
          StreamBuilder<List<Consultation>>(
            stream: svc.consultations.watchAll(),
            builder: (context, snap) {
              final list = snap.data ?? [];
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final c = list[i];
                  return ListTile(
                    title: Text(c.status),
                    subtitle: Text('user ${c.userId} • expert ${c.expertId}'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ConsultationDetailScreen(
                          consultationId: c.id,
                          appUser: widget.appUser,
                          expertDocId: c.expertId,
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          StreamBuilder<List<Review>>(
            stream: svc.reviews.watchAll(),
            builder: (context, snap) {
              final list = snap.data ?? [];
              return ListView.builder(
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final r = list[i];
                  return ListTile(
                    title: Text('★ ${r.rating}'),
                    subtitle: Text(r.feedback),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => svc.reviews.deleteReview(r.id),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
