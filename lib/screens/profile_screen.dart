import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/app_user.dart';
import '../models/consultation.dart';
import '../models/roadmap.dart';
import '../providers/app_services.dart';
import 'consultation_detail_screen.dart';
import 'roadmap_detail_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.appUser, required this.firebaseUser});

  final AppUser appUser;
  final User firebaseUser;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _resume;
  late final TextEditingController _goals;
  late List<String> _skills;
  late List<String> _interests;

  @override
  void initState() {
    super.initState();
    final u = widget.appUser;
    _name = TextEditingController(text: u.name);
    _email = TextEditingController(text: u.email);
    _resume = TextEditingController(text: u.resume);
    _goals = TextEditingController(text: u.careerGoals);
    _skills = List<String>.from(u.skills);
    _interests = List<String>.from(u.interests);
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _resume.dispose();
    _goals.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final updated = widget.appUser.copyWith(
      name: _name.text.trim(),
      email: _email.text.trim(),
      resume: _resume.text.trim(),
      careerGoals: _goals.text.trim(),
      skills: _skills,
      interests: _interests,
    );
    await context.svc.users.updateProfile(updated);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated')));
    }
  }

  Future<void> _logout() async {
    await context.svc.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), actions: [
        IconButton(onPressed: _logout, icon: const Icon(Icons.logout)),
      ]),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Account', style: theme.textTheme.titleMedium),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
          TextField(
            controller: _resume,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(labelText: 'Résumé (text)'),
          ),
          TextField(
            controller: _goals,
            decoration: const InputDecoration(labelText: 'Career goals'),
          ),
          const SizedBox(height: 12),
          Text('Skills', style: theme.textTheme.titleSmall),
          Wrap(
            spacing: 8,
            children: _skills
                .map((s) => Chip(label: Text(s), onDeleted: () => setState(() => _skills.remove(s))))
                .toList(),
          ),
          TextField(
            decoration: const InputDecoration(hintText: 'Add skill'),
            onSubmitted: (v) {
              final t = v.trim();
              if (t.isEmpty) return;
              setState(() => _skills.add(t));
            },
          ),
          const SizedBox(height: 12),
          Text('Interests', style: theme.textTheme.titleSmall),
          Wrap(
            spacing: 8,
            children: _interests
                .map((s) => Chip(label: Text(s), onDeleted: () => setState(() => _interests.remove(s))))
                .toList(),
          ),
          TextField(
            decoration: const InputDecoration(hintText: 'Add interest'),
            onSubmitted: (v) {
              final t = v.trim();
              if (t.isEmpty) return;
              setState(() => _interests.add(t));
            },
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: _save, child: const Text('Save profile')),
          const Divider(height: 40),
          Text('Past consultations', style: theme.textTheme.titleMedium),
          StreamBuilder<List<Consultation>>(
            stream: svc.consultations.watchForUser(widget.appUser.uid),
            builder: (context, snap) {
              final list = snap.data ?? [];
              if (list.isEmpty) return const Text('None yet.');
              return Column(
                children: list
                    .map(
                      (c) => ListTile(
                        title: Text(c.status),
                        subtitle: Text('${c.type} • ${c.scheduledAt != null ? DateFormat.yMMMd().add_jm().format(c.scheduledAt!) : '—'}'),
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
                    )
                    .toList(),
              );
            },
          ),
          const Divider(height: 40),
          Text('Generated roadmaps', style: theme.textTheme.titleMedium),
          StreamBuilder<List<Roadmap>>(
            stream: svc.roadmaps.watchForUser(widget.appUser.uid),
            builder: (context, snap) {
              final list = snap.data ?? [];
              if (list.isEmpty) return const Text('None yet — try AI guidance.');
              return Column(
                children: list
                    .map(
                      (r) => ListTile(
                        title: Text(r.targetRole.isEmpty ? 'Roadmap' : r.targetRole),
                        subtitle: Text(r.timeline),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => RoadmapDetailScreen(roadmapId: r.id),
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
