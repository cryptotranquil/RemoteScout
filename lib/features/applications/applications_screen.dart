import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/ui/scout_ui.dart';
import '../../core/utils/formatters.dart';
import '../../data/providers.dart';
import '../../models/models.dart';

/// Applications tab — the tracker (03_App_Flow.md §6).
class ApplicationsScreen extends ConsumerStatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  ConsumerState<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends ConsumerState<ApplicationsScreen> {
  ApplicationStatus? _filter; // null = All

  static const List<ApplicationStatus> _tabs = [
    ApplicationStatus.planToApply,
    ApplicationStatus.applied,
    ApplicationStatus.interview,
    ApplicationStatus.offer,
    ApplicationStatus.rejected,
    ApplicationStatus.closed,
  ];

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    final cards = ref.watch(applicationCardsProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final lastSync = ref.watch(lastSyncProvider);
    final store = ref.read(storeProvider);

    return Scaffold(
      body: Column(
        children: [
          ScoutAppHeader(
            subtitle: formatSyncStamp(lastSync),
            avatarName: profile?.name,
            onAvatarTap: () => context.go('/profile'),
          ),
          Expanded(
            child: cards.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  ScoutEmptyState(message: 'Something went wrong: $error'),
              data: (items) {
                final followUps = items
                    .where((card) =>
                        card.application.followUpAt != null &&
                        card.application.status != ApplicationStatus.closed &&
                        card.application.status != ApplicationStatus.rejected)
                    .toList()
                  ..sort((a, b) => a.application.followUpAt!
                      .compareTo(b.application.followUpAt!));
                final filtered = _filter == null
                    ? items
                    : items
                        .where((card) => card.application.status == _filter)
                        .toList();

                final counts = <ApplicationStatus, int>{
                  for (final status in ApplicationStatus.values)
                    status: items
                        .where((card) => card.application.status == status)
                        .length,
                };

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    ScoutSpace.lg,
                    ScoutSpace.sm,
                    ScoutSpace.lg,
                    ScoutSpace.xl,
                  ),
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('Tracker', style: text.titleLarge),
                        const SizedBox(width: ScoutSpace.xs + 2),
                        Expanded(
                          child: Text(
                            '${items.length} active tracks',
                            style: text.labelSmall,
                          ),
                        ),
                        ScoutButton(
                          key: const ValueKey('add-manually'),
                          label: 'Log manually',
                          icon: Icons.add,
                          variant: ScoutButtonVariant.primary,
                          dense: true,
                          expand: false,
                          onPressed: () => context.push('/application/new'),
                        ),
                      ],
                    ),
                    const SizedBox(height: ScoutSpace.sm),
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ScoutFilterPill(
                            label: 'All (${items.length})',
                            compact: true,
                            selected: _filter == null,
                            onTap: () => setState(() => _filter = null),
                          ),
                          for (final status in _tabs) ...[
                            const SizedBox(width: ScoutSpace.xs + 2),
                            ScoutFilterPill(
                              label: '${status.label} (${counts[status] ?? 0})',
                              compact: true,
                              selected: _filter == status,
                              onTap: () => setState(() => _filter = status),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (followUps.isNotEmpty) ...[
                      const SizedBox(height: ScoutSpace.md),
                      _FollowUpPanel(
                        cards: followUps,
                        onReschedule: (card) async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate:
                                card.application.followUpAt ?? DateTime.now(),
                            firstDate: DateTime.now()
                                .subtract(const Duration(days: 30)),
                            lastDate: DateTime.now()
                                .add(const Duration(days: 120)),
                          );
                          if (picked == null) return;
                          await store.updateApplication(
                            card.application.copyWith(followUpAt: picked),
                          );
                        },
                        onMarkSent: (card) async {
                          final next = DateTime.now()
                              .add(const Duration(days: 7));
                          await store.updateApplication(
                            card.application.copyWith(followUpAt: next),
                          );
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Follow-up logged — next check-in in 7 days.',
                              ),
                            ),
                          );
                        },
                        onOpen: (card) =>
                            context.push('/application/${card.application.id}'),
                      ),
                    ],
                    const SizedBox(height: ScoutSpace.md),
                    _FunnelPanel(counts: counts, total: items.length),
                    const SizedBox(height: ScoutSpace.md),
                    Row(
                      children: [
                        Expanded(
                          child: Text('Applications', style: text.titleSmall),
                        ),
                        Text('Sorted by next milestone', style: text.labelSmall),
                      ],
                    ),
                    const SizedBox(height: ScoutSpace.sm),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: ScoutSpace.lg),
                        child: ScoutEmptyState(
                          icon: Icons.work_outline,
                          message: items.isEmpty
                              ? 'Nothing here yet.\nSave a job, plan to apply, or log one manually.'
                              : 'No applications in "${_filter?.label ?? 'this'}" yet.',
                        ),
                      )
                    else
                      for (final card in filtered) ...[
                        _ApplicationCard(
                          key: ValueKey('app-${card.application.id}'),
                          card: card,
                          onOpen: () =>
                              context.push('/application/${card.application.id}'),
                          onPrimaryAction: () => _primaryAction(card, store),
                        ),
                        const SizedBox(height: ScoutSpace.sm),
                      ],
                    const SizedBox(height: ScoutSpace.sm),
                    Column(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: colors.surfaceLow,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle_outline,
                            size: 18,
                            color: colors.muted,
                          ),
                        ),
                        const SizedBox(height: ScoutSpace.xs),
                        Text(
                          'All pipeline events stay on this device',
                          style: text.bodySmall,
                        ),
                        Text(
                          'RemoteScout never submits an application for you',
                          style: text.labelSmall,
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _primaryAction(ApplicationCardModel card, dynamic store) async {
    final application = card.application;
    switch (application.status) {
      case ApplicationStatus.planToApply:
        final job = card.job;
        if (job == null) return;
        final uri = Uri.tryParse(job.applyUrl);
        if (uri == null) return;
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      case ApplicationStatus.offer:
        await store.updateApplication(
          application.copyWith(
            status: ApplicationStatus.closed,
            notes: '${application.notes ?? ''}${application.notes == null ? '' : ' · '}Offer accepted',
          ),
        );
      case ApplicationStatus.rejected:
      case ApplicationStatus.closed:
        await store.updateApplication(
          application.copyWith(status: ApplicationStatus.applied),
        );
      case ApplicationStatus.neu:
      case ApplicationStatus.saved:
      case ApplicationStatus.applied:
      case ApplicationStatus.interview:
        if (mounted) {
          await context.push('/application/${application.id}');
        }
    }
  }
}

class _FollowUpPanel extends StatelessWidget {
  const _FollowUpPanel({
    required this.cards,
    required this.onReschedule,
    required this.onMarkSent,
    required this.onOpen,
  });

  final List<ApplicationCardModel> cards;
  final Future<void> Function(ApplicationCardModel) onReschedule;
  final Future<void> Function(ApplicationCardModel) onMarkSent;
  final void Function(ApplicationCardModel) onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    final now = DateTime.now();

    return Container(
      padding: const EdgeInsets.all(ScoutSpace.md),
      decoration: BoxDecoration(
        color: colors.surfaceLow,
        borderRadius: BorderRadius.circular(ScoutRadius.lg),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.schedule_send, size: 16, color: colors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Upcoming follow-ups', style: text.titleSmall),
              ),
              ScoutBadge(
                label: '${cards.length} pending',
                tone: ScoutBadgeTone.tonal,
              ),
            ],
          ),
          const SizedBox(height: ScoutSpace.sm),
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: ScoutSpace.sm),
            _FollowUpRow(
              card: cards[i],
              now: now,
              onReschedule: () => onReschedule(cards[i]),
              onMarkSent: () => onMarkSent(cards[i]),
              onOpen: () => onOpen(cards[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _FollowUpRow extends StatelessWidget {
  const _FollowUpRow({
    required this.card,
    required this.now,
    required this.onReschedule,
    required this.onMarkSent,
    required this.onOpen,
  });

  final ApplicationCardModel card;
  final DateTime now;
  final VoidCallback onReschedule;
  final VoidCallback onMarkSent;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final application = card.application;
    final due = application.followUpAt!;
    final overdue = due.isBefore(now);
    final days = due.difference(now).inDays;

    return Container(
      padding: const EdgeInsets.all(ScoutSpace.sm),
      decoration: BoxDecoration(
        color: ScoutColors.of(context).card,
        borderRadius: BorderRadius.circular(ScoutRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: onOpen,
                      child: Text(
                        card.company,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelLarge,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      overdue
                          ? 'Overdue since ${formatShortDate(due)}'
                          : days <= 1
                              ? 'Follow-up due tomorrow'
                              : 'Follow-up in $days days (${formatShortDate(due)})',
                      style: text.bodySmall!.copyWith(
                        color: overdue
                            ? ScoutColors.of(context).error
                            : ScoutColors.of(context).primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (overdue)
                ScoutBadge(
                  label: '${now.difference(due).inDays}d late',
                  tone: ScoutBadgeTone.warning,
                )
              else
                ScoutBadge(
                  label: formatShortDate(due),
                  tone: ScoutBadgeTone.tonal,
                ),
            ],
          ),
          const SizedBox(height: ScoutSpace.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ScoutButton(
                label: 'Reschedule',
                dense: true,
                expand: false,
                onPressed: onReschedule,
              ),
              const SizedBox(width: ScoutSpace.xs + 2),
              ScoutButton(
                label: 'Mark sent',
                icon: Icons.done,
                dense: true,
                expand: false,
                variant: ScoutButtonVariant.primary,
                onPressed: onMarkSent,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FunnelPanel extends StatelessWidget {
  const _FunnelPanel({required this.counts, required this.total});

  final Map<ApplicationStatus, int> counts;
  final int total;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;

    final segments = <(String, int, Color)>[
      ('Plan', counts[ApplicationStatus.planToApply] ?? 0, colors.tertiary),
      (
        'Applied',
        (counts[ApplicationStatus.applied] ?? 0) +
            (counts[ApplicationStatus.saved] ?? 0),
        colors.surfaceHighest,
      ),
      ('Interview', counts[ApplicationStatus.interview] ?? 0, colors.primary),
      ('Offer', counts[ApplicationStatus.offer] ?? 0, colors.secondary),
    ];
    final sum = segments.fold<int>(0, (acc, item) => acc + item.$2);
    final interviewRate = total == 0
        ? 0
        : (((counts[ApplicationStatus.interview] ?? 0) +
                        (counts[ApplicationStatus.offer] ?? 0)) /
                    total *
                    100)
                .round();

    return ScoutCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Funnel velocity', style: text.labelLarge)),
              Text('$interviewRate% interview conversion',
                  style: text.labelSmall),
            ],
          ),
          const SizedBox(height: ScoutSpace.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(ScoutRadius.pill),
            child: SizedBox(
              height: 8,
              child: sum == 0
                  ? ColoredBox(color: colors.track)
                  : Row(
                      children: [
                        for (final segment in segments)
                          if (segment.$2 > 0)
                            Expanded(
                              flex: segment.$2,
                              child: ColoredBox(color: segment.$3),
                            ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: ScoutSpace.sm),
          Wrap(
            spacing: ScoutSpace.md,
            runSpacing: ScoutSpace.xs,
            children: [
              for (final segment in segments)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: segment.$3,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${segment.$2} ${segment.$1}',
                      style: text.labelSmall,
                    ),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({
    super.key,
    required this.card,
    required this.onOpen,
    required this.onPrimaryAction,
  });

  final ApplicationCardModel card;
  final VoidCallback onOpen;
  final VoidCallback onPrimaryAction;

  ScoutBadgeTone _toneFor(ApplicationStatus status) => switch (status) {
        ApplicationStatus.interview => ScoutBadgeTone.info,
        ApplicationStatus.offer => ScoutBadgeTone.soft,
        ApplicationStatus.rejected => ScoutBadgeTone.warning,
        ApplicationStatus.closed => ScoutBadgeTone.tonal,
        _ => ScoutBadgeTone.tonal,
      };

  String _primaryLabel(ApplicationStatus status) => switch (status) {
        ApplicationStatus.planToApply => 'Submit now',
        ApplicationStatus.offer => 'Accept offer',
        ApplicationStatus.rejected => 'Reopen',
        ApplicationStatus.closed => 'Reopen',
        _ => 'Open application',
      };

  IconData _primaryIcon(ApplicationStatus status) => switch (status) {
        ApplicationStatus.planToApply => Icons.send,
        ApplicationStatus.offer => Icons.done_all,
        ApplicationStatus.rejected => Icons.refresh,
        ApplicationStatus.closed => Icons.refresh,
        _ => Icons.arrow_forward,
      };

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    final application = card.application;
    final job = card.job;

    final milestone = application.followUpAt;
    final applied = application.appliedAt;

    return ScoutCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ScoutMonogram(label: card.company),
              const SizedBox(width: ScoutSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.company,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                    Text(
                      card.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleSmall,
                    ),
                  ],
                ),
              ),
              ScoutIconButton(
                icon: Icons.more_horiz,
                tooltip: 'Open application',
                size: 32,
                ghost: true,
                onPressed: onOpen,
              ),
            ],
          ),
          const SizedBox(height: ScoutSpace.sm),
          ScoutBadge(
            label: application.status.label,
            tone: _toneFor(application.status),
            icon: Icons.circle,
          ),
          const SizedBox(height: ScoutSpace.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ScoutSpace.sm),
            decoration: BoxDecoration(
              color: colors.surfaceLow,
              borderRadius: BorderRadius.circular(ScoutRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      milestone != null ? Icons.event : Icons.calendar_today,
                      size: 15,
                      color: colors.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        milestone != null
                            ? 'Follow-up scheduled ${formatShortDate(milestone)}'
                            : applied != null
                                ? 'Applied ${formatShortDate(applied)}'
                                : 'Not submitted yet',
                        style: text.labelMedium!.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  job == null
                      ? 'Manual entry'
                      : '${job.employmentLabel} · ${job.locationText}',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          if (job != null) ...[
            const SizedBox(height: ScoutSpace.sm),
            Row(
              children: [
                Icon(Icons.payments_outlined,
                    size: 15, color: colors.muted),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    job.salaryLabel,
                    style: text.bodySmall,
                  ),
                ),
                if (application.cvVersion != null &&
                    application.cvVersion!.isNotEmpty) ...[
                  Icon(Icons.attach_file, size: 15, color: colors.muted),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      application.cvVersion!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall,
                    ),
                  ),
                ],
              ],
            ),
          ],
          if (application.notes?.isNotEmpty == true) ...[
            const SizedBox(height: ScoutSpace.sm),
            ScoutNotice(
              icon: Icons.forum_outlined,
              child: Text(
                '“${application.notes}”',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          const SizedBox(height: ScoutSpace.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Updated ${formatShortAgo(application.updatedAt)}',
                  style: text.labelSmall,
                ),
              ),
              ScoutButton(
                label: _primaryLabel(application.status),
                icon: _primaryIcon(application.status),
                dense: true,
                expand: false,
                variant: application.status == ApplicationStatus.offer
                    ? ScoutButtonVariant.primary
                    : ScoutButtonVariant.tonal,
                onPressed: onPrimaryAction,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
