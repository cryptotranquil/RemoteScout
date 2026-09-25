import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/neumorphic.dart';
import '../../config/env.dart';
import '../../data/providers.dart';
import '../../models/models.dart';
import '../discover/job_card.dart';
import '../onboarding/notification_prefs_card.dart';

/// Profile tab (03_App_Flow.md §7).
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider).valueOrNull;
    final prefs = ref.watch(prefsProvider).valueOrNull ?? const NotificationPrefs();
    final palette = NeuPalette.of(context);
    final store = ref.read(storeProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: profile == null
            ? const EmptyState(message: 'No profile yet.')
            : ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                children: [
                  const ScreenHeader(
                    title: 'Profile',
                    subtitle: 'Skills, preferences, and how RemoteScout picks for you.',
                  ),
                  NeuCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profile.name.isEmpty ? 'You' : profile.name,
                                    style:
                                        Theme.of(context).textTheme.titleLarge,
                                  ),
                                  if (profile.email.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(profile.email,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall),
                                  ],
                                ],
                              ),
                            ),
                            NeuIconButton(
                              key: const ValueKey('edit-profile'),
                              icon: Icons.edit_outlined,
                              tooltip: 'Edit profile',
                              size: 48,
                              onPressed: () => context.push('/profile/edit'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const NeuSectionLabel('Target roles'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final role in profile.targetRoles)
                              SkillChip(label: role, matched: true),
                          ],
                        ),
                        const SizedBox(height: 14),
                        const NeuSectionLabel('Skills'),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final skill in profile.skills)
                              SkillChip(label: skill, matched: true),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  NeuCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const NeuSectionLabel('Location & salary'),
                        const LocationBadge(
                          scope: 'worldwide',
                          detail: 'Worldwide-remote roles only',
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Minimum salary: ${profile.minimumSalary == null ? 'not set' : profile.minimumSalary!.round().toString()}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Time zones: ${profile.preferredTimezones.isEmpty ? 'flexible' : profile.preferredTimezones.join(', ')}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Experience: ${profile.experienceLevel}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  NotificationPrefsCard(
                    prefs: prefs,
                    onChanged: (p) => store.savePrefs(p),
                  ),
                  const SizedBox(height: 18),
                  NeuCard(
                    onTap: () => context.push('/stats'),
                    child: const Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              NeuSectionLabel('Statistics'),
                              Text('Applications over time, status funnel, '
                                  'match-score distribution'),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  NeuCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const NeuSectionLabel('Data sources & attribution'),
                        Text(
                          Env.isLiveConfigured
                              ? 'Live backend: listings are fetched from Remotive '
                                  'and Remote OK by the scheduled worker, then '
                                  'scored and deduplicated server-side.'
                              : 'Phase 1–2 build: five realistic mock listings are '
                                  'bundled locally. Live Remotive and Remote OK feeds '
                                  'arrive with the Supabase worker (Phase 3).',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Listings from Remotive and Remote OK are always '
                          'shown with attribution and a link back to the '
                          'original listing, per each source\'s terms.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 14),
                        NeuButton(
                          key: const ValueKey('force-refresh'),
                          onPressed: () async {
                            await store.refresh();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text(Env.isLiveConfigured
                                        ? 'Re-checked the sources and re-scored.'
                                        : 'Re-scored against your profile.')),
                              );
                            }
                          },
                          child: Text(Env.isLiveConfigured
                              ? 'Force refresh from sources'
                              : 'Force re-score'),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'RemoteScout never auto-applies. Every submission '
                          'is your click, on the original listing.',
                          style: Theme.of(context).textTheme.labelSmall!.copyWith(
                              color: palette.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
