import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../config/env.dart';
import '../../core/theme/theme_mode.dart';
import '../../core/ui/scout_ui.dart';
import '../../core/utils/formatters.dart';
import '../../data/push_notifications.dart';
import '../../data/providers.dart';
import '../../models/models.dart';

/// Profile tab (03_App_Flow.md §7) — the scout's settings desk.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  /// Local draft so the "Save preferences" button has something to commit.
  NotificationPrefs? _draft;
  bool _saving = false;

  NotificationPrefs _prefs() =>
      _draft ??
      ref.read(prefsProvider).valueOrNull ??
      const NotificationPrefs();

  void _edit(NotificationPrefs Function(NotificationPrefs current) change) {
    final current = _prefs();
    setState(() => _draft = change(current));
  }

  Future<void> _save() async {
    final prefs = _draft;
    if (prefs == null) return;
    setState(() => _saving = true);
    final store = ref.read(storeProvider);
    try {
      final timezone = await PushNotificationService.currentTimeZone();
      await store.savePrefs(prefs.copyWith(timeZone: timezone));
      await store.rescore();
    } catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save preferences: $error')),
      );
      return;
    }
    var pushMessage = '';
    final push = pushNotificationService;
    if (push != null) {
      try {
        final enabled = await push.requestPermissionAndRegister();
        if (!enabled) {
          pushMessage = 'Push permission was not granted. You can enable it '
              'later in your device settings.';
        }
      } catch (error) {
        pushMessage = 'Could not register this device for push notifications: '
            '$error';
      }
    }
    if (!mounted) return;
    setState(() {
      _saving = false;
      _draft = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(pushMessage.isEmpty
            ? 'Preferences saved — matches re-scored.'
            : 'Preferences saved. $pushMessage'),
      ),
    );
  }

  Future<void> _editSalary(Profile profile) async {
    final controller = TextEditingController(
      text: profile.minimumSalary?.round().toString() ?? '',
    );
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Minimum base salary'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. 24000',
            prefixText: '\$ ',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (value == null) return;
    final parsed = double.tryParse(value);
    if (parsed == null) return;
    await ref
        .read(storeProvider)
        .saveProfile(profile.copyWith(minimumSalary: parsed));
  }

  Future<void> _pickDigestTime() async {
    final prefs = _prefs();
    final parts = prefs.digestTime.split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 8,
        minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      ),
    );
    if (picked == null) return;
    _edit(
      (next) => next.copyWith(
        digestTime:
            '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    final profile = ref.watch(profileProvider).valueOrNull;
    final prefs = _draft ??
        ref.watch(prefsProvider).valueOrNull ??
        const NotificationPrefs();
    final jobs = ref.watch(jobsProvider).valueOrNull ?? const <Job>[];
    final lastSync = ref.watch(lastSyncProvider);
    final themeMode = ref.watch(themeModeProvider);
    final store = ref.read(storeProvider);

    final sources = <String, int>{};
    for (final job in jobs) {
      sources.update(_sourceName(job.source), (v) => v + 1, ifAbsent: () => 1);
    }

    return Scaffold(
      body: Column(
        children: [
          ScoutAppHeader(
            subtitle: formatSyncStamp(lastSync),
            avatarName: profile?.name,
          ),
          Expanded(
            child: profile == null
                ? const ScoutEmptyState(
                    icon: Icons.person_outline,
                    message: 'No profile yet.',
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      ScoutSpace.lg,
                      ScoutSpace.sm,
                      ScoutSpace.lg,
                      ScoutSpace.xl,
                    ),
                    children: [
                      _ProfileCard(
                        profile: profile,
                        threshold: prefs.minMatchScore,
                        onEdit: () => context.push('/profile/edit'),
                      ),
                      const SizedBox(height: ScoutSpace.md),
                      Row(
                        children: [
                          Icon(Icons.tune, size: 18, color: colors.primary),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text('Scout preferences',
                                style: text.titleMedium),
                          ),
                          ScoutButton(
                            label: 'Statistics',
                            icon: Icons.insights_outlined,
                            dense: true,
                            expand: false,
                            onPressed: () => context.push('/stats'),
                          ),
                        ],
                      ),
                      const SizedBox(height: ScoutSpace.sm),
                      ScoutCard(
                        child: Column(
                          children: [
                            _RolesSection(
                              profile: profile,
                              onRemove: (role) async {
                                final next = [...profile.targetRoles]
                                  ..remove(role);
                                await store.saveProfile(
                                  profile.copyWith(targetRoles: next),
                                );
                              },
                              onEdit: () => context.push('/profile/edit'),
                            ),
                            const ScoutDivider(verticalPadding: ScoutSpace.md),
                            _SkillsSection(
                              profile: profile,
                              onEdit: () => context.push('/profile/edit'),
                            ),
                            const ScoutDivider(verticalPadding: ScoutSpace.md),
                            _ThresholdSection(
                              value: prefs.minMatchScore,
                              onChanged: (value) => _edit(
                                (next) => next.copyWith(minMatchScore: value),
                              ),
                            ),
                            const ScoutDivider(verticalPadding: ScoutSpace.md),
                            _CompensationSection(
                              profile: profile,
                              onEditSalary: () => _editSalary(profile),
                              onWorldwideChanged: (value) => store.saveProfile(
                                profile.copyWith(
                                  preferredCountries:
                                      value ? const ['worldwide'] : const [],
                                ),
                              ),
                              onEditLocation: () =>
                                  context.push('/profile/edit'),
                            ),
                            const ScoutDivider(verticalPadding: ScoutSpace.md),
                            _SourcesSection(
                              sources: sources,
                              live: Env.isLiveConfigured,
                              onRefresh: () async {
                                final result = await refreshScout(ref);
                                if (!context.mounted) return;
                                showFeedRefreshFeedback(
                                  context,
                                  isLive: result.isLive,
                                  fetched: result.fetched,
                                  inserted: result.inserted,
                                  duplicatesDiscarded:
                                      result.duplicatesDiscarded,
                                  storedJobs: result.storedJobs,
                                  visibleJobs: result.visibleJobs,
                                  errors: result.errors,
                                );
                              },
                            ),
                            const ScoutDivider(verticalPadding: ScoutSpace.md),
                            _NotificationSection(
                              prefs: prefs,
                              onDigestTime: _pickDigestTime,
                              onThresholdChanged: (value) => _edit(
                                (next) => next.copyWith(maxJobsPerDay: value),
                              ),
                              onWeekendChanged: (value) => _edit(
                                (next) => next.copyWith(weekendEnabled: value),
                              ),
                            ),
                            const ScoutDivider(verticalPadding: ScoutSpace.md),
                            _AppearanceSection(
                              mode: themeMode,
                              onChanged: (mode) => ref
                                  .read(themeModeProvider.notifier)
                                  .state = mode,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: ScoutSpace.md),
                      ScoutButton(
                        key: const ValueKey('save-preferences'),
                        label: _saving ? 'Saving…' : 'Save preferences',
                        icon: Icons.save_outlined,
                        variant: ScoutButtonVariant.primary,
                        onPressed: _draft == null || _saving ? null : _save,
                      ),
                      const SizedBox(height: ScoutSpace.sm),
                      Text(
                        'JobRadar never auto-applies. Every submission is '
                        'your click, on the original listing.',
                        textAlign: TextAlign.center,
                        style: text.labelSmall,
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

String _sourceName(String source) {
  switch (source) {
    case 'remotive':
      return 'Remotive';
    case 'remoteok':
      return 'Remote OK';
    case 'himalayas':
      return 'Himalayas';
    case 'jobicy':
      return 'Jobicy';
    case 'arbeitnow':
      return 'Arbeitnow';
    case 'adzuna':
      return 'Adzuna';
    case 'jooble':
      return 'Jooble';
    case 'themuse':
      return 'The Muse';
    case 'findwork':
      return 'Findwork';
    case 'weworkremotely':
      return 'We Work Remotely';
    case 'manual':
      return 'Manual entries';
    default:
      return source;
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.profile,
    required this.threshold,
    required this.onEdit,
  });

  final Profile profile;
  final int threshold;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    final roles = profile.targetRoles.take(2).join(' · ');
    return ScoutCard(
      padding: const EdgeInsets.all(ScoutSpace.md),
      child: Row(
        children: [
          ScoutAvatar(
            name: profile.name.isEmpty ? 'You' : profile.name,
            size: 56,
            squared: true,
          ),
          const SizedBox(width: ScoutSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile.name.isEmpty ? 'You' : profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.verified, size: 15, color: colors.primary),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  roles.isEmpty ? 'No target roles yet' : roles,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        'Scout active • threshold $threshold%',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style:
                            text.labelMedium!.copyWith(color: colors.primary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ScoutIconButton(
            key: const ValueKey('edit-profile'),
            icon: Icons.edit_outlined,
            tooltip: 'Edit profile',
            size: 36,
            ghost: true,
            onPressed: onEdit,
          ),
        ],
      ),
    );
  }
}

class _RolesSection extends StatelessWidget {
  const _RolesSection({
    required this.profile,
    required this.onRemove,
    required this.onEdit,
  });

  final Profile profile;
  final ValueChanged<String> onRemove;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScoutSectionHeader(
          title: 'Target roles & titles',
          icon: Icons.work_outline,
          trailing: Text(
            '${profile.targetRoles.length} active',
            style: text.labelSmall,
          ),
        ),
        const SizedBox(height: ScoutSpace.sm),
        if (profile.targetRoles.isEmpty)
          Text('Add a role to start scouting.', style: text.bodySmall)
        else
          Wrap(
            spacing: ScoutSpace.xs + 2,
            runSpacing: ScoutSpace.xs + 2,
            children: [
              for (final role in profile.targetRoles)
                Container(
                  padding: const EdgeInsets.fromLTRB(
                    ScoutSpace.sm,
                    ScoutSpace.xs,
                    ScoutSpace.xs,
                    ScoutSpace.xs,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainer,
                    borderRadius: BorderRadius.circular(ScoutRadius.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(role, style: text.labelMedium),
                      const SizedBox(width: 2),
                      InkWell(
                        onTap: () => onRemove(role),
                        child: Icon(Icons.close, size: 13, color: colors.muted),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        const SizedBox(height: ScoutSpace.sm),
        ScoutButton(
          label: 'Add role title',
          icon: Icons.add,
          expand: true,
          dense: true,
          variant: ScoutButtonVariant.tonal,
          onPressed: onEdit,
        ),
      ],
    );
  }
}

class _SkillsSection extends StatelessWidget {
  const _SkillsSection({required this.profile, required this.onEdit});

  final Profile profile;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    final skills = profile.skills.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScoutSectionHeader(
          title: 'Skills profile',
          icon: Icons.psychology_outlined,
          trailing: ScoutBadge(
            label: '${profile.skills.length} scored',
            tone: ScoutBadgeTone.tonal,
          ),
        ),
        const SizedBox(height: ScoutSpace.sm),
        if (skills.isEmpty)
          Text('No skills yet — add the tools you actually use.',
              style: text.bodySmall)
        else
          for (final skill in skills)
            Padding(
              padding: const EdgeInsets.only(bottom: ScoutSpace.xs + 1),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: ScoutSpace.sm,
                  vertical: ScoutSpace.xs + 2,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceLow,
                  borderRadius: BorderRadius.circular(ScoutRadius.md),
                ),
                child: Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  spacing: ScoutSpace.sm,
                  runSpacing: ScoutSpace.xs,
                  children: [
                    Text(skill, style: text.labelLarge),
                    Text('Matched on every listing', style: text.labelSmall),
                  ],
                ),
              ),
            ),
        if (profile.skills.length > skills.length)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              '+${profile.skills.length - skills.length} more skills',
              style: text.labelSmall,
            ),
          ),
        const SizedBox(height: ScoutSpace.sm),
        ScoutButton(
          label: 'Edit skills',
          icon: Icons.edit_outlined,
          expand: true,
          dense: true,
          onPressed: onEdit,
        ),
      ],
    );
  }
}

class _ThresholdSection extends StatelessWidget {
  const _ThresholdSection({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text('Minimum fit score', style: text.labelLarge),
            ),
            Text(
              '$value%',
              style: text.labelLarge!.copyWith(color: colors.primary),
            ),
          ],
        ),
        Slider(
          value: value.toDouble().clamp(50, 95),
          min: 50,
          max: 95,
          divisions: 9,
          onChanged: (v) => onChanged(v.round()),
        ),
        Row(
          children: [
            Expanded(child: Text('50% broad', style: text.labelSmall)),
            Text('$value% curated', style: text.labelSmall),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Text('95% exact', style: text.labelSmall),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _CompensationSection extends StatelessWidget {
  const _CompensationSection({
    required this.profile,
    required this.onEditSalary,
    required this.onWorldwideChanged,
    required this.onEditLocation,
  });

  final Profile profile;
  final VoidCallback onEditSalary;
  final ValueChanged<bool> onWorldwideChanged;
  final VoidCallback onEditLocation;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    final worldwide = profile.preferredCountries.contains('worldwide');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ScoutSectionHeader(
          title: 'Compensation & location',
          icon: Icons.payments_outlined,
        ),
        const SizedBox(height: ScoutSpace.sm),
        const ScoutSectionLabel('Minimum base salary'),
        const SizedBox(height: ScoutSpace.xs),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 40,
                padding: const EdgeInsets.symmetric(horizontal: ScoutSpace.sm),
                alignment: Alignment.centerLeft,
                decoration: BoxDecoration(
                  color: colors.surfaceLow,
                  borderRadius: BorderRadius.circular(ScoutRadius.md),
                ),
                child: Text(
                  profile.minimumSalary == null
                      ? 'Not set'
                      : '\$${profile.minimumSalary!.round()} / year',
                  style: text.labelLarge,
                ),
              ),
            ),
            const SizedBox(width: ScoutSpace.sm),
            ScoutButton(
              label: 'Edit',
              dense: true,
              expand: false,
              onPressed: onEditSalary,
            ),
          ],
        ),
        const SizedBox(height: ScoutSpace.sm),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Worldwide remote only', style: text.labelLarge),
                  Text(
                    worldwide
                        ? 'Excludes region and country-only listings'
                        : 'Region and country-restricted listings stay eligible',
                    style: text.labelSmall,
                  ),
                ],
              ),
            ),
            ScoutSwitch(value: worldwide, onChanged: onWorldwideChanged),
          ],
        ),
        const SizedBox(height: ScoutSpace.xs),
        InkWell(
          onTap: onEditLocation,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ScoutSpace.sm,
              vertical: ScoutSpace.xs + 2,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceLow,
              borderRadius: BorderRadius.circular(ScoutRadius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.public, size: 18, color: colors.primary),
                const SizedBox(width: ScoutSpace.sm),
                Expanded(
                  child: Text(
                    profile.preferredTimezones.isEmpty
                        ? 'Any timezone'
                        : profile.preferredTimezones.join(' · '),
                    style: text.labelLarge,
                  ),
                ),
                Icon(Icons.edit, size: 15, color: colors.muted),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SourcesSection extends StatelessWidget {
  const _SourcesSection({
    required this.sources,
    required this.live,
    required this.onRefresh,
  });

  final Map<String, int> sources;
  final bool live;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ScoutSectionHeader(
          title: 'Sources & crawlers',
          icon: Icons.hub_outlined,
          trailing: Text('${sources.length} connected', style: text.labelSmall),
        ),
        const SizedBox(height: ScoutSpace.sm),
        if (sources.isEmpty)
          Text('No listings ingested yet.', style: text.bodySmall)
        else
          for (final entry in sources.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: ScoutSpace.xs + 1),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: ScoutSpace.sm,
                  vertical: ScoutSpace.xs + 2,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceLow,
                  borderRadius: BorderRadius.circular(ScoutRadius.md),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(entry.key, style: text.labelLarge),
                          Text(
                            '${entry.value} ${entry.value == 1 ? 'listing' : 'listings'} ingested',
                            style: text.labelSmall,
                          ),
                        ],
                      ),
                    ),
                    const ScoutBadge(
                      label: 'on',
                      tone: ScoutBadgeTone.soft,
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: ScoutSpace.sm),
        Row(
          children: [
            Expanded(
              child: Text(
                live
                    ? 'Crawl frequency managed by the scheduled worker'
                    : 'Refresh cadence: on demand (local build)',
                style: text.labelSmall,
              ),
            ),
            ScoutButton(
              label: 'Refresh feed',
              icon: Icons.refresh,
              dense: true,
              expand: false,
              onPressed: () => onRefresh(),
            ),
          ],
        ),
      ],
    );
  }
}

class _NotificationSection extends StatelessWidget {
  const _NotificationSection({
    required this.prefs,
    required this.onDigestTime,
    required this.onThresholdChanged,
    required this.onWeekendChanged,
  });

  final NotificationPrefs prefs;
  final VoidCallback onDigestTime;
  final ValueChanged<int> onThresholdChanged;
  final ValueChanged<bool> onWeekendChanged;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ScoutSectionHeader(
          title: 'Notification hygiene',
          icon: Icons.notifications_none,
        ),
        const SizedBox(height: ScoutSpace.sm),
        InkWell(
          key: const ValueKey('digest-time'),
          onTap: onDigestTime,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: ScoutSpace.sm,
              vertical: ScoutSpace.xs + 2,
            ),
            decoration: BoxDecoration(
              color: colors.surfaceLow,
              borderRadius: BorderRadius.circular(ScoutRadius.md),
            ),
            child: Row(
              children: [
                Icon(Icons.mail_outline, size: 16, color: colors.muted),
                const SizedBox(width: ScoutSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Daily digest email', style: text.labelLarge),
                      Text(
                        '${formatTimeOfDay(prefs.digestTime)} single digest · no instant pings',
                        style: text.labelSmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.schedule, size: 16, color: colors.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: ScoutSpace.sm),
        Row(
          children: [
            Expanded(
              child: Text('Shortlist size per day', style: text.labelLarge),
            ),
            ScoutIconButton(
              icon: Icons.remove,
              size: 32,
              tooltip: 'Fewer jobs',
              onPressed: prefs.maxJobsPerDay > 1
                  ? () => onThresholdChanged(prefs.maxJobsPerDay - 1)
                  : null,
            ),
            SizedBox(
              width: 34,
              child: Text(
                '${prefs.maxJobsPerDay}',
                textAlign: TextAlign.center,
                style: text.labelLarge,
              ),
            ),
            ScoutIconButton(
              icon: Icons.add,
              size: 32,
              tooltip: 'More jobs',
              onPressed: prefs.maxJobsPerDay < 15
                  ? () => onThresholdChanged(prefs.maxJobsPerDay + 1)
                  : null,
            ),
          ],
        ),
        const SizedBox(height: ScoutSpace.xs),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Weekend digests', style: text.labelLarge),
                  Text('Off by default — keep weekends quiet',
                      style: text.labelSmall),
                ],
              ),
            ),
            ScoutSwitch(
              value: prefs.weekendEnabled,
              onChanged: onWeekendChanged,
            ),
          ],
        ),
      ],
    );
  }
}

class _AppearanceSection extends StatelessWidget {
  const _AppearanceSection({required this.mode, required this.onChanged});

  final ThemeMode mode;
  final ValueChanged<ThemeMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ScoutSectionHeader(
          title: 'Appearance',
          icon: Icons.contrast,
        ),
        const SizedBox(height: ScoutSpace.sm),
        Row(
          children: [
            for (final entry in const [
              (ThemeMode.system, 'System'),
              (ThemeMode.light, 'Light'),
              (ThemeMode.dark, 'Dark'),
            ]) ...[
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: entry.$1 == ThemeMode.dark ? 0 : ScoutSpace.xs + 2,
                  ),
                  child: ScoutFilterPill(
                    label: entry.$2,
                    selected: mode == entry.$1,
                    compact: true,
                    onTap: () => onChanged(entry.$1),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: ScoutSpace.xs),
        Text(
          'Night mode inverts the canvas but keeps every tone pair intact.',
          style: text.labelSmall,
        ),
      ],
    );
  }
}
