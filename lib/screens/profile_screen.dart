import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../main.dart';
import '../models/app_user.dart';
import '../providers/app_services.dart';
import '../theme/app_theme.dart';
import '../theme/glass_card.dart';
import '../theme/gradient_background.dart';

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
                          decoration: const InputDecoration(labelText: 'Resume (text)'),
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

                  // Apply as Expert (only for regular users)
                  if (widget.appUser.role == UserRole.user) ...[
                    _ExpertApplicationCard(appUser: widget.appUser),
                    const SizedBox(height: 16),
                  ],

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

                  // Bottom padding for nav bar
                  const SizedBox(height: 80),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpertApplicationCard extends StatefulWidget {
  const _ExpertApplicationCard({required this.appUser});
  final AppUser appUser;

  @override
  State<_ExpertApplicationCard> createState() => _ExpertApplicationCardState();
}

class _ExpertApplicationCardState extends State<_ExpertApplicationCard> {
  String? _status; // null = loading, 'none' = no application
  bool _submitting = false;
  final _domainCtrl = TextEditingController();
  final _experienceCtrl = TextEditingController();
  final _qualificationCtrl = TextEditingController();
  final _linkedinCtrl = TextEditingController();
  final _whyCtrl = TextEditingController();
  final _priceChatCtrl = TextEditingController(text: '200');
  final _priceCallCtrl = TextEditingController(text: '400');
  final _priceVideoCtrl = TextEditingController(text: '500');

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _domainCtrl.dispose();
    _experienceCtrl.dispose();
    _qualificationCtrl.dispose();
    _linkedinCtrl.dispose();
    _whyCtrl.dispose();
    _priceChatCtrl.dispose();
    _priceCallCtrl.dispose();
    _priceVideoCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    final status = await context.svc.experts.getApplicationStatus(widget.appUser.uid);
    if (mounted) setState(() => _status = status ?? 'none');
  }

  Future<void> _showApplicationDialog() async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollCtrl) => Container(
          decoration: BoxDecoration(
            color: Theme.of(ctx).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Apply as Expert', style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                'Fill in your details so the admin can verify your expertise.',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Colors.white.withOpacity(0.5)),
              ),
              const SizedBox(height: 24),

              // Pre-filled info
              GlassCard(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Your Profile', style: Theme.of(ctx).textTheme.labelSmall?.copyWith(
                      color: AppTheme.accentSecondary, fontWeight: FontWeight.w700, letterSpacing: 0.8,
                    )),
                    const SizedBox(height: 8),
                    _InfoRow(label: 'Name', value: widget.appUser.name),
                    _InfoRow(label: 'Email', value: widget.appUser.email),
                    if (widget.appUser.skills.isNotEmpty)
                      _InfoRow(label: 'Skills', value: widget.appUser.skills.join(', ')),
                    if (widget.appUser.careerGoals.isNotEmpty)
                      _InfoRow(label: 'Goals', value: widget.appUser.careerGoals),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Application fields
              TextField(
                controller: _domainCtrl,
                decoration: const InputDecoration(
                  labelText: 'Domain / Specialty *',
                  hintText: 'e.g. Machine Learning, System Design, Data Science',
                  prefixIcon: Icon(Icons.category_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _experienceCtrl,
                decoration: const InputDecoration(
                  labelText: 'Work Experience *',
                  hintText: 'e.g. 5 years as ML Engineer at Google',
                  prefixIcon: Icon(Icons.work_outline_rounded, size: 20),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _qualificationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Qualifications',
                  hintText: 'e.g. M.Tech in CS from IIT Delhi, AWS Certified',
                  prefixIcon: Icon(Icons.school_rounded, size: 20),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _linkedinCtrl,
                decoration: const InputDecoration(
                  labelText: 'LinkedIn / Portfolio URL',
                  hintText: 'https://linkedin.com/in/yourprofile',
                  prefixIcon: Icon(Icons.link_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 14),
              Text('Session Rates (INR) *', style: Theme.of(ctx).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('Set your rate for each session type (0-5000)',
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(color: Colors.white.withOpacity(0.5))),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceChatCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Chat',
                        prefixIcon: Icon(Icons.chat_rounded, size: 18),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _priceCallCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Audio',
                        prefixIcon: Icon(Icons.call_rounded, size: 18),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _priceVideoCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Video',
                        prefixIcon: Icon(Icons.videocam_rounded, size: 18),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _whyCtrl,
                decoration: const InputDecoration(
                  labelText: 'Why do you want to mentor? *',
                  hintText: 'What motivates you to guide learners?',
                  prefixIcon: Icon(Icons.favorite_outline_rounded, size: 20),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (_domainCtrl.text.trim().isEmpty ||
                            _experienceCtrl.text.trim().isEmpty ||
                            _whyCtrl.text.trim().isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Please fill in all required fields (*)')),
                          );
                          return;
                        }
                        Navigator.pop(ctx, true);
                      },
                      icon: const Icon(Icons.send_rounded, size: 18),
                      label: const Text('Submit Application'),
                    ),
                  ),
                ],
              ),
              // Extra padding so keyboard doesn't hide the last field
              SizedBox(height: MediaQuery.of(ctx).viewInsets.bottom + 40),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _submitting = true);
    try {
      await context.svc.experts.submitApplication(
        uid: widget.appUser.uid,
        name: widget.appUser.name,
        email: widget.appUser.email,
        domain: _domainCtrl.text.trim(),
        experience: _experienceCtrl.text.trim(),
        skills: widget.appUser.skills,
        qualification: _qualificationCtrl.text.trim(),
        linkedinUrl: _linkedinCtrl.text.trim(),
        whyMentor: _whyCtrl.text.trim(),
        priceChat: (int.tryParse(_priceChatCtrl.text.trim()) ?? 200).clamp(0, 5000),
        priceCall: (int.tryParse(_priceCallCtrl.text.trim()) ?? 400).clamp(0, 5000),
        priceVideo: (int.tryParse(_priceVideoCtrl.text.trim()) ?? 500).clamp(0, 5000),
      );
      if (mounted) {
        setState(() => _status = 'pending');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application submitted! An admin will review it.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (_status == null) return const SizedBox.shrink(); // Loading

    return GlassCard(
      glowColor: _status == 'pending' ? AppTheme.warning : AppTheme.accentSecondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.accentSecondary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.workspace_premium_rounded, size: 20, color: AppTheme.accentSecondary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Become an Expert',
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'Share your knowledge and earn',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.white.withOpacity(0.5) : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_status == 'none')
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _submitting ? null : _showApplicationDialog,
                icon: _submitting
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send_rounded, size: 18),
                label: Text(_submitting ? 'Submitting...' : 'Apply Now'),
              ),
            )
          else if (_status == 'pending')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.hourglass_top_rounded, size: 16, color: AppTheme.warning),
                  SizedBox(width: 6),
                  Text(
                    'Application pending review',
                    style: TextStyle(color: AppTheme.warning, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
            )
          else if (_status == 'rejected')
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.close_rounded, size: 16, color: AppTheme.error),
                  SizedBox(width: 6),
                  Text(
                    'Application not approved',
                    style: TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
            ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 50,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.4),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
