import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../providers/app_services.dart';
import '../theme/app_theme.dart';
import '../theme/glass_card.dart';
import '../theme/gradient_background.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final svc = context.svc;
      final cred = await svc.auth.signInWithGoogle();
      final User? u = cred?.user;
      if (u == null) {
        setState(() => _busy = false);
        return;
      }
      await svc.users.ensureUserDocument(u);
      if (!mounted) return;
      setState(() => _busy = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: GradientBackground(
        variant: GradientVariant.primary,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // App icon
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.accent.withOpacity(0.2),
                          AppTheme.accentSecondary.withOpacity(0.1),
                        ],
                      ),
                      border: Border.all(
                        color: AppTheme.accent.withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: const Icon(
                      Icons.route_rounded,
                      size: 48,
                      color: AppTheme.accent,
                    ),
                  )
                      .animate()
                      .fadeIn(duration: 600.ms)
                      .scale(begin: const Offset(0.7, 0.7), end: const Offset(1, 1), curve: Curves.easeOutBack),

                  const SizedBox(height: 32),

                  // Title
                  Text(
                    'Pathwise',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -1,
                    ),
                  ).animate().fadeIn(delay: 200.ms, duration: 500.ms),

                  const SizedBox(height: 8),

                  // Tagline
                  Text(
                    'Your AI-powered career navigator',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: isDark ? AppTheme.accentSecondary.withOpacity(0.7) : AppTheme.accent,
                      fontWeight: FontWeight.w500,
                    ),
                  ).animate().fadeIn(delay: 350.ms, duration: 500.ms),

                  const SizedBox(height: 12),

                  Text(
                    'Personalized roadmaps, AI skill analysis,\nand expert mentorship — all in one place.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white.withOpacity(0.4) : Colors.black45,
                      height: 1.6,
                    ),
                  ).animate().fadeIn(delay: 500.ms, duration: 500.ms),

                  const SizedBox(height: 48),

                  // Login card
                  GlassCard(
                    borderRadius: 24,
                    padding: const EdgeInsets.all(28),
                    glowColor: AppTheme.accent,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Get started',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to access your personalized learning journey',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white.withOpacity(0.5) : Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (_error != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.error.withOpacity(0.3)),
                              ),
                              child: Text(
                                _error!,
                                style: TextStyle(color: AppTheme.error, fontSize: 12),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton.icon(
                            onPressed: _busy ? null : _signIn,
                            icon: _busy
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : const Icon(Icons.login_rounded),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _busy ? 'Signing in...' : 'Sign in with Google',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 650.ms, duration: 600.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 24),

                  // Features preview
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _FeaturePill(icon: Icons.auto_awesome, label: 'AI Roadmaps'),
                      const SizedBox(width: 8),
                      _FeaturePill(icon: Icons.people, label: 'Expert Mentors'),
                    ],
                  ).animate().fadeIn(delay: 900.ms, duration: 400.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  const _FeaturePill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
        border: Border.all(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.accent.withOpacity(0.7)),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white.withOpacity(0.5) : Colors.black54,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
