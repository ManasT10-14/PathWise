import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../main.dart';
import '../models/app_user.dart';
import '../theme/app_theme.dart';
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
    final isDark = theme.brightness == Brightness.dark;
    final greeting = _greeting();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pathwise'),
        actions: [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: themeMode,
            builder: (context, mode, _) => IconButton(
              icon: Icon(
                mode == ThemeMode.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              ),
              onPressed: () {
                themeMode.value = mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
              },
            ),
          ),
        ],
      ),
      body: GradientBackground(
        variant: GradientVariant.primary,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // Hero greeting
            Text(
              '$greeting,',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isDark ? Colors.white.withOpacity(0.5) : Colors.black54,
              ),
            ).animate().fadeIn(duration: 400.ms),
            const SizedBox(height: 2),
            Text(
              appUser.name.isNotEmpty ? appUser.name.split(' ').first : 'there',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideX(begin: -0.03, end: 0),
            const SizedBox(height: 6),
            Text(
              'What would you like to do today?',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.white.withOpacity(0.4) : Colors.black45,
              ),
            ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

            const SizedBox(height: 32),

            // AI Guidance card
            _FeatureCard(
              index: 0,
              icon: Icons.auto_awesome_rounded,
              iconColor: AppTheme.accent,
              glowColor: AppTheme.accent,
              title: 'AI Career Guidance',
              subtitle: 'Get a personalized learning roadmap powered by Gemini AI. '
                  'Analyzes your skills, detects gaps, and builds a path to your dream role.',
              ctaText: 'Start Analysis',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => AiGuidanceScreen(appUser: appUser)),
              ),
            ),

            const SizedBox(height: 16),

            // Expert card
            _FeatureCard(
              index: 1,
              icon: Icons.person_search_rounded,
              iconColor: AppTheme.accentSecondary,
              glowColor: AppTheme.accentSecondary,
              title: 'Expert Consultation',
              subtitle: 'Connect with verified domain experts for personalized mentorship. '
                  'Book sessions, get career advice, and validate your learning path.',
              ctaText: 'Browse Experts',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => ExpertsScreen(appUser: appUser)),
              ),
            ),

            // Bottom padding so content doesn't hide behind the nav bar
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.index,
    required this.icon,
    required this.iconColor,
    required this.glowColor,
    required this.title,
    required this.subtitle,
    required this.ctaText,
    required this.onTap,
  });

  final int index;
  final IconData icon;
  final Color iconColor;
  final Color glowColor;
  final String title;
  final String subtitle;
  final String ctaText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        glowColor: glowColor,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 24, color: iconColor),
                ),
                const Spacer(),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 20,
                  color: isDark ? Colors.white.withOpacity(0.3) : Colors.black26,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: isDark ? Colors.white.withOpacity(0.5) : Colors.black54,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                ctaText,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: iconColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ).animate().fadeIn(delay: (index * 150 + 300).ms, duration: 500.ms).slideY(begin: 0.08, end: 0),
    );
  }
}

