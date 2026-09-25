import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/luna_colors.dart';
import 'core/theme/neumorphic.dart';

/// Root navigator key so detail routes can cover the bottom nav.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Soft raised bottom navigation bar (04_UIUX_Design.md §2).
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    return Scaffold(
      body: shell,
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: palette.base,
            borderRadius: BorderRadius.circular(28),
            boxShadow: palette.raised(blur: 16, distance: 7),
          ),
          child: Row(
            children: [
              _NavItem(
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore,
                label: 'Discover',
                active: shell.currentIndex == 0,
                onTap: () => shell.goBranch(0),
              ),
              _NavItem(
                icon: Icons.bookmark_outline,
                activeIcon: Icons.bookmark,
                label: 'Saved',
                active: shell.currentIndex == 1,
                onTap: () => shell.goBranch(1),
              ),
              _NavItem(
                icon: Icons.work_outline,
                activeIcon: Icons.work,
                label: 'Applications',
                active: shell.currentIndex == 2,
                onTap: () => shell.goBranch(2),
              ),
              _NavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                active: shell.currentIndex == 3,
                onTap: () => shell.goBranch(3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: palette.base,
                    shape: BoxShape.circle,
                    boxShadow: active
                        ? palette.inset(blur: 7, distance: 3)
                        : const [],
                  ),
                  child: Icon(
                    active ? activeIcon : icon,
                    size: 22,
                    color: active ? Luna.luna500 : palette.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall!.copyWith(
                        fontSize: 9.5,
                        color: active ? palette.textPrimary : palette.textSecondary,
                        fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
