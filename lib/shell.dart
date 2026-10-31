import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/scout_theme.dart';

/// Root navigator key so detail routes can cover the bottom nav.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

/// Fixed 56dp bottom navigation with a hairline divider (design system §5).
///
/// No floating pill, no shadows: the active destination is signalled by teal
/// ink alone.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.card,
          border: Border(top: BorderSide(color: colors.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: ScoutSpace.sm),
              child: Row(
                children: [
                  _NavItem(
                    icon: Icons.explore_outlined,
                    label: 'Discover',
                    active: shell.currentIndex == 0,
                    onTap: () => shell.goBranch(0),
                  ),
                  _NavItem(
                    icon: Icons.bookmark_outline,
                    label: 'Saved',
                    active: shell.currentIndex == 1,
                    onTap: () => shell.goBranch(1),
                  ),
                  _NavItem(
                    icon: Icons.work_outline,
                    label: 'Applications',
                    active: shell.currentIndex == 2,
                    onTap: () => shell.goBranch(2),
                  ),
                  _NavItem(
                    icon: Icons.tune,
                    label: 'Profile',
                    active: shell.currentIndex == 3,
                    onTap: () => shell.goBranch(3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final color = active ? colors.primary : colors.muted;
    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: color),
                const SizedBox(height: 1),
                Text(
                  label,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelMedium!.copyWith(
                        fontSize: 11,
                        color: color,
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
