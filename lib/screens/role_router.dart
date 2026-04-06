import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../providers/app_services.dart';
import '../widgets/skeleton_loader.dart';
import 'admin_dashboard_screen.dart';
import 'expert_home_screen.dart';
import 'user_main_shell.dart';

class RoleRouter extends StatelessWidget {
  const RoleRouter({super.key, required this.firebaseUser});

  final User firebaseUser;

  @override
  Widget build(BuildContext context) {
    final repo = context.svc.users;
    return StreamBuilder<AppUser?>(
      stream: repo.watchUser(firebaseUser.uid),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(
              child: SkeletonLoader(lines: 2, hasAvatar: true),
            ),
          );
        }
        final appUser = snap.data;
        if (appUser == null) {
          return Scaffold(
            body: Center(
              child: SkeletonLoader(lines: 2, hasAvatar: true),
            ),
          );
        }
        switch (appUser.role) {
          case UserRole.admin:
            return AdminDashboardScreen(appUser: appUser);
          case UserRole.expert:
            return ExpertHomeScreen(appUser: appUser);
          case UserRole.user:
            return UserMainShell(appUser: appUser, firebaseUser: firebaseUser);
        }
      },
    );
  }
}
