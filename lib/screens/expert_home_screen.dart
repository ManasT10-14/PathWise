import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';

import '../models/app_user.dart';
import '../models/consultation.dart';
import '../models/expert.dart';
import '../models/review.dart';
import '../providers/app_services.dart';
import '../theme/app_theme.dart';
import '../theme/glass_card.dart';
import '../theme/gradient_background.dart';
import '../widgets/empty_state.dart';
import '../widgets/skeleton_loader.dart';
import 'consultation_detail_screen.dart';
import 'expert_annotation_screen.dart';

class ExpertHomeScreen extends StatefulWidget {
  const ExpertHomeScreen({super.key, required this.appUser});

  final AppUser appUser;

  @override
  State<ExpertHomeScreen> createState() => _ExpertHomeScreenState();
}

class _ExpertHomeScreenState extends State<ExpertHomeScreen> {
  int _tab = 0; // 0=Consultations, 1=Profile, 2=Reviews

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expert Console'),
        actions: [
          IconButton(onPressed: () => svc.auth.signOut(), icon: const Icon(Icons.logout)),
        ],
      ),
      body: GradientBackground(
        variant: GradientVariant.secondary,
        child: FutureBuilder<Expert?>(
          future: svc.experts.findExpertForUser(uid: widget.appUser.uid, email: widget.appUser.email),
          builder: (context, expertSnap) {
            if (!expertSnap.hasData) {
              return Padding(padding: const EdgeInsets.all(16), child: SkeletonLoader.list(itemCount: 3));
            }
            final expert = expertSnap.data;
            if (expert == null) {
              return EmptyStateWidget(
                title: 'No Expert Profile',
                subtitle: 'No expert profile linked to this account.',
                icon: Icons.person_off_outlined,
              );
            }

            return Column(
              children: [
                // Tab selector
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        _TabButton(label: 'Consultations', icon: Icons.event_note_rounded, isActive: _tab == 0, onTap: () => setState(() => _tab = 0)),
                        _TabButton(label: 'Profile', icon: Icons.person_rounded, isActive: _tab == 1, onTap: () => setState(() => _tab = 1)),
                        _TabButton(label: 'Reviews', icon: Icons.reviews_rounded, isActive: _tab == 2, onTap: () => setState(() => _tab = 2)),
                      ],
                    ),
                  ),
                ),
                // Tab content
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _tab == 0
                        ? _ConsultationsTab(key: const ValueKey('consult'), expert: expert, appUser: widget.appUser)
                        : _tab == 1
                            ? _ProfileTab(key: const ValueKey('profile'), expert: expert)
                            : _ReviewsTab(key: const ValueKey('reviews'), expert: expert),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab button
// ---------------------------------------------------------------------------
class _TabButton extends StatelessWidget {
  const _TabButton({required this.label, required this.icon, required this.isActive, required this.onTap});
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
            color: isActive ? AppTheme.accent.withOpacity(0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: isActive ? Border.all(color: AppTheme.accent.withOpacity(0.3)) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: isActive ? AppTheme.accent : (isDark ? Colors.white.withOpacity(0.4) : Colors.black38)),
              const SizedBox(width: 5),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.w600 : FontWeight.w400, color: isActive ? AppTheme.accent : (isDark ? Colors.white.withOpacity(0.5) : Colors.black45))),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 0: Consultations with filters
// ---------------------------------------------------------------------------
class _ConsultationsTab extends StatefulWidget {
  const _ConsultationsTab({super.key, required this.expert, required this.appUser});
  final Expert expert;
  final AppUser appUser;

  @override
  State<_ConsultationsTab> createState() => _ConsultationsTabState();
}

class _ConsultationsTabState extends State<_ConsultationsTab> {
  String _filter = 'all';

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return AppTheme.warning;
      case 'accepted': return AppTheme.success;
      case 'completed': return AppTheme.accent;
      case 'cancelled': return AppTheme.error;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return StreamBuilder<List<Consultation>>(
      stream: svc.consultations.watchForExpert(widget.expert.id),
      builder: (context, snap) {
        if (!snap.hasData) return Padding(padding: const EdgeInsets.all(16), child: SkeletonLoader.list(itemCount: 3));

        final all = snap.data!;
        final filtered = _filter == 'all' ? all : all.where((c) => c.status == _filter).toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          children: [
            // Stats row
            Row(
              children: [
                _MiniStat(label: 'Pending', value: '${all.where((c) => c.status == "pending").length}', color: AppTheme.warning),
                const SizedBox(width: 6),
                _MiniStat(label: 'Active', value: '${all.where((c) => c.status == "accepted").length}', color: AppTheme.success),
                const SizedBox(width: 6),
                _MiniStat(label: 'Done', value: '${all.where((c) => c.status == "completed").length}', color: AppTheme.accent),
                const SizedBox(width: 6),
                _MiniStat(label: 'Total', value: '${all.length}', color: AppTheme.accentSecondary),
              ],
            ).animate().fadeIn(duration: 300.ms),
            const SizedBox(height: 12),

            // Filter chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ['all', 'pending', 'accepted', 'completed', 'cancelled'].map((f) {
                  final isActive = _filter == f;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(f == 'all' ? 'All' : f[0].toUpperCase() + f.substring(1)),
                      selected: isActive,
                      onSelected: (_) => setState(() => _filter = f),
                      selectedColor: AppTheme.accent.withOpacity(0.2),
                      checkmarkColor: AppTheme.accent,
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),

            // Count
            Text('${filtered.length} consultation${filtered.length == 1 ? '' : 's'}', style: theme.textTheme.labelSmall?.copyWith(color: Colors.white.withOpacity(0.4))),
            const SizedBox(height: 8),

            if (filtered.isEmpty)
              EmptyStateWidget(title: 'No ${_filter == "all" ? "" : _filter} consultations', subtitle: 'Nothing to show', icon: Icons.event_busy_rounded)
            else
              ...List.generate(filtered.length, (i) {
                final c = filtered[i];
                final sc = _statusColor(c.status);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GestureDetector(
                    onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) => ConsultationDetailScreen(consultationId: c.id, appUser: widget.appUser, expertDocId: widget.expert.id),
                    )),
                    child: GlassCard(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          CircleAvatar(radius: 18, backgroundColor: sc.withOpacity(0.15), child: Icon(Icons.person_outline, color: sc, size: 18)),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                FutureBuilder(
                                  future: context.svc.users.fetchUser(c.userId),
                                  builder: (_, s) => Text(s.data?.name ?? 'Learner', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                                ),
                                Row(
                                  children: [
                                    Text('${c.type.toUpperCase()} ', style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.5))),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                      decoration: BoxDecoration(color: sc.withOpacity(0.12), borderRadius: BorderRadius.circular(6)),
                                      child: Text(c.status, style: TextStyle(color: sc, fontSize: 10, fontWeight: FontWeight.w700)),
                                    ),
                                    const Spacer(),
                                    Text('INR ${c.price}', style: theme.textTheme.labelSmall?.copyWith(color: AppTheme.accent, fontWeight: FontWeight.w700)),
                                  ],
                                ),
                                if (c.scheduledAt != null)
                                  Text(DateFormat.yMMMd().add_jm().format(c.scheduledAt!), style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurface.withOpacity(0.4), fontSize: 11)),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, size: 20, color: colorScheme.outline),
                        ],
                      ),
                    ).animate().fadeIn(delay: (i * 60).ms).slideY(begin: 0.03, end: 0),
                  ),
                );
              }),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1: Editable Profile
// ---------------------------------------------------------------------------
class _ProfileTab extends StatefulWidget {
  const _ProfileTab({super.key, required this.expert});
  final Expert expert;

  @override
  State<_ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<_ProfileTab> {
  late final TextEditingController _domainCtrl;
  late final TextEditingController _experienceCtrl;
  late final TextEditingController _priceChatCtrl;
  late final TextEditingController _priceCallCtrl;
  late final TextEditingController _priceVideoCtrl;
  late final TextEditingController _skillCtrl;
  late List<String> _skills;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _domainCtrl = TextEditingController(text: widget.expert.domain);
    _experienceCtrl = TextEditingController(text: widget.expert.experience);
    _priceChatCtrl = TextEditingController(text: '${widget.expert.priceChat}');
    _priceCallCtrl = TextEditingController(text: '${widget.expert.priceCall}');
    _priceVideoCtrl = TextEditingController(text: '${widget.expert.priceVideo}');
    _skillCtrl = TextEditingController();
    _skills = List<String>.from(widget.expert.skills);
  }

  @override
  void dispose() {
    _domainCtrl.dispose();
    _experienceCtrl.dispose();
    _priceChatCtrl.dispose();
    _priceCallCtrl.dispose();
    _priceVideoCtrl.dispose();
    _skillCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.svc.experts.updateExpertProfile(
        widget.expert.id,
        domain: _domainCtrl.text.trim(),
        experience: _experienceCtrl.text.trim(),
        skills: _skills,
        priceChat: (int.tryParse(_priceChatCtrl.text.trim()) ?? 200).clamp(0, 5000),
        priceCall: (int.tryParse(_priceCallCtrl.text.trim()) ?? 400).clamp(0, 5000),
        priceVideo: (int.tryParse(_priceVideoCtrl.text.trim()) ?? 500).clamp(0, 5000),
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      children: [
        // Profile header
        GlassCard(
          glowColor: AppTheme.accent,
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Text(
                  widget.expert.name.isNotEmpty ? widget.expert.name[0].toUpperCase() : '?',
                  style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(widget.expert.name, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        if (widget.expert.isVerified) ...[const SizedBox(width: 6), const Icon(Icons.verified_rounded, size: 18, color: AppTheme.accentSecondary)],
                      ],
                    ),
                    Text(widget.expert.email, style: theme.textTheme.bodySmall?.copyWith(color: isDark ? Colors.white.withOpacity(0.5) : Colors.black45)),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                        const SizedBox(width: 3),
                        Text('${widget.expert.rating.toStringAsFixed(1)} (${widget.expert.totalReviews})', style: theme.textTheme.bodySmall?.copyWith(color: isDark ? Colors.white.withOpacity(0.5) : Colors.black45)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ).animate().fadeIn(duration: 300.ms),

        const SizedBox(height: 16),

        // Editable fields
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Domain / Specialty', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(controller: _domainCtrl, decoration: const InputDecoration(hintText: 'e.g. Machine Learning, System Design', prefixIcon: Icon(Icons.category_rounded, size: 18))),
              const SizedBox(height: 14),
              Text('Experience', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(controller: _experienceCtrl, decoration: const InputDecoration(hintText: 'e.g. 5 years at Google', prefixIcon: Icon(Icons.work_outline_rounded, size: 18)), maxLines: 2),
            ],
          ),
        ).animate().fadeIn(delay: 100.ms),

        const SizedBox(height: 12),

        // Pricing
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Session Rates (INR)', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('0 - 5000 per session', style: theme.textTheme.bodySmall?.copyWith(color: isDark ? Colors.white.withOpacity(0.4) : Colors.black38)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: _priceChatCtrl, decoration: const InputDecoration(labelText: 'Chat', prefixIcon: Icon(Icons.chat_rounded, size: 16)), keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _priceCallCtrl, decoration: const InputDecoration(labelText: 'Audio', prefixIcon: Icon(Icons.call_rounded, size: 16)), keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: _priceVideoCtrl, decoration: const InputDecoration(labelText: 'Video', prefixIcon: Icon(Icons.videocam_rounded, size: 16)), keyboardType: TextInputType.number)),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(delay: 150.ms),

        const SizedBox(height: 12),

        // Skills
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Skills', style: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (_skills.isNotEmpty)
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _skills.map((s) => Chip(
                    label: Text(s, style: const TextStyle(fontSize: 12)),
                    onDeleted: () => setState(() => _skills.remove(s)),
                    visualDensity: VisualDensity.compact,
                  )).toList(),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _skillCtrl,
                      decoration: const InputDecoration(hintText: 'Add a skill'),
                      onSubmitted: (v) {
                        if (v.trim().isNotEmpty) setState(() { _skills.add(v.trim()); _skillCtrl.clear(); });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () {
                      if (_skillCtrl.text.trim().isNotEmpty) setState(() { _skills.add(_skillCtrl.text.trim()); _skillCtrl.clear(); });
                    },
                    child: const Text('Add'),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(delay: 200.ms),

        const SizedBox(height: 20),

        // Save button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.save_rounded, size: 20),
            label: Text(_saving ? 'Saving...' : 'Save Profile'),
          ),
        ).animate().fadeIn(delay: 250.ms),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Reviews
// ---------------------------------------------------------------------------
class _ReviewsTab extends StatelessWidget {
  const _ReviewsTab({super.key, required this.expert});
  final Expert expert;

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<List<Review>>(
      stream: svc.reviews.watchForExpert(expert.id),
      builder: (context, snap) {
        if (!snap.hasData) return Padding(padding: const EdgeInsets.all(16), child: SkeletonLoader.list(itemCount: 3));

        final reviews = snap.data!;
        if (reviews.isEmpty) {
          return EmptyStateWidget(title: 'No Reviews Yet', subtitle: 'Reviews from learners will appear here', icon: Icons.reviews_outlined);
        }

        // Calc average
        final avg = reviews.fold<double>(0, (s, r) => s + r.rating) / reviews.length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          children: [
            // Rating summary
            GlassCard(
              glowColor: Colors.amber,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(avg.toStringAsFixed(1), style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w700, color: Colors.amber)),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: List.generate(5, (i) => Icon(i < avg.round() ? Icons.star_rounded : Icons.star_outline_rounded, size: 18, color: Colors.amber)),
                      ),
                      Text('${reviews.length} review${reviews.length == 1 ? '' : 's'}', style: theme.textTheme.bodySmall?.copyWith(color: isDark ? Colors.white.withOpacity(0.5) : Colors.black45)),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 300.ms),

            const SizedBox(height: 12),

            // Review cards
            ...List.generate(reviews.length, (i) {
              final r = reviews[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ...List.generate(5, (s) => Icon(s < r.rating ? Icons.star_rounded : Icons.star_outline_rounded, size: 14, color: Colors.amber)),
                          const Spacer(),
                          if (r.timestamp != null)
                            Text(DateFormat.yMMMd().format(r.timestamp!), style: theme.textTheme.labelSmall?.copyWith(color: isDark ? Colors.white.withOpacity(0.3) : Colors.black26)),
                        ],
                      ),
                      if (r.feedback.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(r.feedback, style: theme.textTheme.bodySmall?.copyWith(height: 1.4, color: isDark ? Colors.white.withOpacity(0.7) : Colors.black54), maxLines: 5, overflow: TextOverflow.ellipsis),
                      ],
                    ],
                  ),
                ).animate().fadeIn(delay: (i * 60).ms),
              );
            }),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Mini stat chip
// ---------------------------------------------------------------------------
class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, color: color)),
            Text(label, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Colors.white.withOpacity(0.4), fontSize: 9)),
          ],
        ),
      ),
    );
  }
}
