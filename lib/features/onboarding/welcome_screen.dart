import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/neumorphic.dart';

/// First-run welcome (03_App_Flow.md §2).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  color: palette.base,
                  shape: BoxShape.circle,
                  boxShadow: [
                    ...palette.raised(blur: 22, distance: 10),
                    BoxShadow(
                      color: fade(Luna.luna500, 0.18),
                      blurRadius: 26,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.travel_explore,
                    size: 56,
                    color: Luna.luna500,
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
                      color: palette.textSecondary,
                    ),
              ),
              const Spacer(),
              NeuButton(
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
    );
  }
}
