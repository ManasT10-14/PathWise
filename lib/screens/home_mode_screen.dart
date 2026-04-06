import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../main.dart';
import '../models/app_user.dart';
import '../theme/glass_card.dart';
import '../theme/gradient_background.dart';
import 'ai_guidance_screen.dart';
import 'experts_screen.dart';

class HomeModeScreen extends StatelessWidget {
  const HomeModeScreen({super.key, required this.appUser});

  final AppUser appUser;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guidance'),
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
      body: GradientBackground(
        variant: GradientVariant.primary,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Hello, ${appUser.name}',
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Choose how you want to grow next.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            _GlassModeCard(
              index: 0,
              title: 'AI Guidance',
              subtitle:
                  'Upload or paste your résumé, add skills and goals — get a tailored roadmap with milestones and resources.',
              icon: Icons.psychology_outlined,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => AiGuidanceScreen(appUser: appUser),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _GlassModeCard(
              index: 1,
              title: 'Human Expert Consultation',
              subtitle:
                  'Browse verified experts, pick chat / audio / video, pay securely, and book a session.',
              icon: Icons.groups_2_outlined,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ExpertsScreen(appUser: appUser),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GlassModeCard extends StatelessWidget {
  const _GlassModeCard({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final int index;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 36, color: theme.colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: theme.colorScheme.outline),
          ],
        ),
      ).animate().fadeIn(delay: (index * 100).ms).slideX(begin: -0.1, end: 0),
    );
  }
}
