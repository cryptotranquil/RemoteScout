import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/scout_theme.dart';
import 'core/ui/animated_notch_nav_bar.dart';

/// Root navigator key so detail routes can cover the bottom nav.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    return Scaffold(
      body: shell,
      bottomNavigationBar: AnimatedNotchNavBar(
        items: const [
          AnimatedNotchNavBarItem(
            icon: Icons.explore_outlined,
            label: 'Discover',
          ),
          AnimatedNotchNavBarItem(
            icon: Icons.bookmark_outline,
            label: 'Saved',
          ),
          AnimatedNotchNavBarItem(
            icon: Icons.work_outline,
            label: 'Applications',
          ),
          AnimatedNotchNavBarItem(icon: Icons.tune, label: 'Profile'),
        ],
        currentIndex: shell.currentIndex,
        onTap: shell.goBranch,
        accentColor: colors.primary,
        backgroundColor: colors.card,
        inactiveColor: colors.muted,
      ),
    );
  }
}
