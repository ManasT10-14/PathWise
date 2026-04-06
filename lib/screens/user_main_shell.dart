import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../main.dart';
import '../models/app_user.dart';
import 'home_mode_screen.dart';
import 'profile_screen.dart';

class UserMainShell extends StatefulWidget {
  const UserMainShell({super.key, required this.appUser, required this.firebaseUser});

  final AppUser appUser;
  final User firebaseUser;

  @override
  State<UserMainShell> createState() => _UserMainShellState();
}

class _UserMainShellState extends State<UserMainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final pages = [
      HomeModeScreen(appUser: widget.appUser),
      ProfileScreen(appUser: widget.appUser, firebaseUser: widget.firebaseUser),
    ];
    return Scaffold(
      appBar: _index == 0
          ? null
          : AppBar(
              title: const Text('Profile'),
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
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: colorScheme.surface.withOpacity(0.95),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
