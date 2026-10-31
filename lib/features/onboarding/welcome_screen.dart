import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/scout_ui.dart';

/// First-run welcome (03_App_Flow.md §2).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = ScoutColors.of(context);
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      const Spacer(),
                      Container(
                        width: 132,
                        height: 132,
                        decoration: BoxDecoration(
                          color: palette.primaryFixed,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.radar,
                            size: 56,
                            color: palette.onPrimaryFixed,
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                      Text(
                        'RemoteScout',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.displaySmall,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'RemoteScout finds jobs worth your time —\n'
                        'a short, high-confidence shortlist every day,\n'
                        'not another endless feed.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                              color: palette.muted,
                            ),
                      ),
                      const Spacer(),
                      ScoutButton(
                        filled: true,
                        onPressed: () => context.push('/onboarding'),
                        child: const Text('Get started'),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Worldwide-remote roles · Transparent match scores ·\n'
                        'You always make the final Apply click.',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
