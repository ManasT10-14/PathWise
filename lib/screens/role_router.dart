import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../providers/app_services.dart';
import '../theme/app_theme.dart';
import '../widgets/skeleton_loader.dart';
import 'admin_dashboard_screen.dart';
import 'expert_home_screen.dart';
import 'user_main_shell.dart';

class RoleRouter extends StatefulWidget {
  const RoleRouter({super.key, required this.firebaseUser});

  final User firebaseUser;

  @override
  State<RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<RoleRouter> {
  bool _retried = false;

  @override
  Widget build(BuildContext context) {
    final svc = context.svc;
    return StreamBuilder<AppUser?>(
      stream: svc.users.watchUser(widget.firebaseUser.uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: SkeletonLoader(lines: 2, hasAvatar: true)),
          );
        }

        final appUser = snap.data;

        // If user doc doesn't exist, try to create it once
        if (appUser == null && !_retried) {
          _retried = true;
          svc.users.ensureUserDocument(widget.firebaseUser);
          return const Scaffold(
            body: Center(child: SkeletonLoader(lines: 2, hasAvatar: true)),
          );
        }

        if (appUser == null) {
          // Still null after retry — show error
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppTheme.warning),
                  const SizedBox(height: 16),
                  const Text('Failed to load your profile'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () {
                      setState(() => _retried = false);
                    },
                    child: const Text('Retry'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => svc.auth.signOut(),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          );
        }

        switch (appUser.role) {
          case UserRole.admin:
            return AdminDashboardScreen(appUser: appUser);
          case UserRole.expert:
            return ExpertHomeScreen(appUser: appUser);
          case UserRole.user:
            return UserMainShell(appUser: appUser, firebaseUser: widget.firebaseUser);
        }
      },
    );
  }
}
