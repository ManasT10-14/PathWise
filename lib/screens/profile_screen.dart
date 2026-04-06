import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../main.dart';
import '../models/app_user.dart';
import '../models/consultation.dart';
import '../models/roadmap.dart';
import '../providers/app_services.dart';
import '../theme/glass_card.dart';
import '../theme/gradient_background.dart';
import '../widgets/empty_state.dart';
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
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: GradientBackground(
        variant: GradientVariant.secondary,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              title: const Text('Profile'),
              floating: true,
              actions: [
                ValueListenableBuilder<ThemeMode>(
                  valueListenable: themeMode,
                  builder: (context, mode, _) => IconButton(
                    icon: Icon(
                      mode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
                    ),
                    onPressed: () {
                      themeMode.value = mode == ThemeMode.dark
                          ? ThemeMode.light
                          : ThemeMode.dark;
                    },
                  ),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Profile card
                  GlassCard(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: colorScheme.primaryContainer,
                          child: Text(
                            widget.appUser.name.isNotEmpty
                                ? widget.appUser.name[0].toUpperCase()
                                : '?',
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.appUser.name,
                          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          widget.appUser.email,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Chip(
                          avatar: const Icon(Icons.badge_outlined, size: 16),
                          label: Text(widget.appUser.role.name.toUpperCase()),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 16),

                  // Edit profile card
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Edit Profile', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _name,
                          decoration: const InputDecoration(labelText: 'Name'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _email,
                          decoration: const InputDecoration(labelText: 'Email'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _resume,
                          minLines: 2,
                          maxLines: 5,
                          decoration: const InputDecoration(labelText: 'Résumé (text)'),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _goals,
                          decoration: const InputDecoration(labelText: 'Career goals'),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _save,
                            child: const Text('Save Profile'),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 100.ms),

                  const SizedBox(height: 16),

                  // Skills card
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Skills', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _skills
                              .map(
                                (s) => Chip(
                                  label: Text(s),
                                  onDeleted: () => setState(() => _skills.remove(s)),
                                ),
                              )
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
                      ],
                    ),
                  ).animate().fadeIn(delay: 150.ms),

                  const SizedBox(height: 16),

                  // Interests card
                  GlassCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Interests', style: theme.textTheme.titleSmall),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _interests
                              .map(
                                (s) => Chip(
                                  label: Text(s),
                                  onDeleted: () => setState(() => _interests.remove(s)),
                                ),
                              )
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
                      ],
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 16),

                  // Settings
                  GlassCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        ValueListenableBuilder<ThemeMode>(
                          valueListenable: themeMode,
                          builder: (context, mode, _) => SwitchListTile(
                            title: const Text('Dark Mode'),
                            secondary: Icon(
                              mode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
                            ),
                            value: mode == ThemeMode.dark,
                            onChanged: (v) {
                              themeMode.value = v ? ThemeMode.dark : ThemeMode.light;
                            },
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.logout),
                          title: const Text('Sign Out'),
                          onTap: _logout,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 250.ms),

                  const SizedBox(height: 24),

                  // Past consultations
                  Text('Past Consultations', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  StreamBuilder<List<Consultation>>(
                    stream: svc.consultations.watchForUser(widget.appUser.uid),
                    builder: (context, snap) {
                      final list = snap.data ?? [];
                      if (list.isEmpty) {
                        return EmptyStateWidget(
                          title: 'No Consultations',
                          subtitle: 'Book a session with an expert to get started',
                          icon: Icons.calendar_today_outlined,
                        );
                      }
                      return Column(
                        children: list
                            .map(
                              (c) => GlassCard(
                                padding: const EdgeInsets.all(12),
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(c.status),
                                  subtitle: Text(
                                    '${c.type} • ${c.scheduledAt != null ? DateFormat.yMMMd().add_jm().format(c.scheduledAt!) : '—'}',
                                  ),
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
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // Roadmaps
                  Text('Generated Roadmaps', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  StreamBuilder<List<Roadmap>>(
                    stream: svc.roadmaps.watchForUser(widget.appUser.uid),
                    builder: (context, snap) {
                      final list = snap.data ?? [];
                      if (list.isEmpty) {
                        return EmptyStateWidget(
                          title: 'No Roadmaps Yet',
                          subtitle: 'Try AI Guidance to generate your personalized roadmap',
                          icon: Icons.map_outlined,
                        );
                      }
                      return Column(
                        children: list
                            .map(
                              (r) => GlassCard(
                                padding: const EdgeInsets.all(12),
                                child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(r.targetRole.isEmpty ? 'Roadmap' : r.targetRole),
                                  subtitle: Text(r.timeline),
                                  trailing: const Icon(Icons.chevron_right),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => RoadmapDetailScreen(roadmapId: r.id),
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),

                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
