import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/scout_ui.dart';
import '../../core/utils/formatters.dart';
import '../../data/providers.dart';
import '../../models/models.dart';
import '../discover/job_card.dart';

/// Saved tab — explicitly saved jobs (03_App_Flow.md §5).
class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

enum _SavedFilter { all, readyToApply, highMatch, expiringSoon }

class _SavedScreenState extends ConsumerState<SavedScreen> {
  String _query = '';
  bool _sortByScore = true;
  _SavedFilter _filter = _SavedFilter.all;

  bool _matchesFilter(JobCardModel model) {
    final application = ref.read(storeProvider).applicationForJob(model.job.id);
    switch (_filter) {
      case _SavedFilter.all:
        return true;
      case _SavedFilter.readyToApply:
        return application == null ||
            application.status == ApplicationStatus.saved ||
            application.status == ApplicationStatus.planToApply;
      case _SavedFilter.highMatch:
        return model.match.matchScore >= 90;
      case _SavedFilter.expiringSoon:
        final days = daysUntilExpiry(model.job);
        return days != null && days <= 7;
    }
  }

  List<JobCardModel> _visible(List<JobCardModel> items) {
    final query = _query.trim().toLowerCase();
    final filtered = items.where((model) {
      final matchesQuery = query.isEmpty ||
          model.job.title.toLowerCase().contains(query) ||
          model.job.company.toLowerCase().contains(query) ||
          model.match.matchedSkills.any((s) => s.toLowerCase().contains(query));
      return matchesQuery && _matchesFilter(model);
    }).toList();
    filtered.sort((a, b) => _sortByScore
        ? b.match.matchScore.compareTo(a.match.matchScore)
        : b.job.publishedAt.compareTo(a.job.publishedAt));
    return filtered;
  }

  Future<void> _exportCsv(List<JobCardModel> items) async {
    final buffer = StringBuffer('company,title,score,salary,location,url\n');
    for (final model in items) {
      final job = model.job;
      buffer.writeln(
        '"${job.company}","${job.title}",${model.match.matchScore},'
        '"${formatSalaryFull(job)}","${job.locationText}","${job.applyUrl}"',
      );
    }
    await Clipboard.setData(ClipboardData(text: buffer.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${items.length} saved ${items.length == 1 ? 'job' : 'jobs'} copied as CSV.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    final saved = ref.watch(savedProvider);
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
            child: saved.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  ScoutEmptyState(message: 'Something went wrong: $error'),
              data: (items) {
                final visible = _visible(items);
                final average = items.isEmpty
                    ? 0
                    : (items
                                .map((m) => m.match.matchScore)
                                .reduce((a, b) => a + b) /
                            items.length)
                        .round();
                final counts = <_SavedFilter, int>{
                  _SavedFilter.all: items.length,
                  _SavedFilter.readyToApply:
                      items.where((m) => _matchesFilter(m)).length,
                  _SavedFilter.highMatch:
                      items.where((m) => m.match.matchScore >= 90).length,
                  _SavedFilter.expiringSoon: items.where((m) {
                    final days = daysUntilExpiry(m.job);
                    return days != null && days <= 7;
                  }).length,
                };

                return ListView(
                  padding: const EdgeInsets.fromLTRB(
                    ScoutSpace.lg,
                    ScoutSpace.sm,
                    ScoutSpace.lg,
                    ScoutSpace.xl,
                  ),
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: ScoutSpace.xs,
                      spacing: ScoutSpace.sm,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: ScoutSpace.sm,
                          runSpacing: ScoutSpace.xs,
                          children: [
                            Text('Saved jobs', style: text.titleLarge),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: ScoutSpace.sm,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surfaceContainer,
                                borderRadius:
                                    BorderRadius.circular(ScoutRadius.md),
                              ),
                              child: Text(
                                '${items.length} saved',
                                style: text.labelMedium!
                                    .copyWith(color: colors.muted),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 15,
                              color: colors.primary,
                            ),
                            const SizedBox(width: 4),
                            Text('Live tracking', style: text.labelSmall),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: ScoutSpace.md),
                    ScoutInput(
                      key: const ValueKey('saved-search'),
                      hint: 'Search by role, company, or skill…',
                      prefixIcon: Icons.search,
                      onChanged: (value) => setState(() => _query = value),
                      suffix: _query.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.close, size: 16),
                              color: colors.muted,
                              onPressed: () => setState(() => _query = ''),
                            ),
                    ),
                    const SizedBox(height: ScoutSpace.sm),
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      runSpacing: ScoutSpace.xs,
                      spacing: ScoutSpace.sm,
                      children: [
                        ScoutButton(
                          key: const ValueKey('saved-sort'),
                          label: _sortByScore
                              ? 'Sort: Highest match'
                              : 'Sort: Newest posted',
                          icon: Icons.swap_vert,
                          dense: true,
                          expand: false,
                          onPressed: () => setState(
                            () => _sortByScore = !_sortByScore,
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Avg match: ',
                              style: text.labelSmall,
                            ),
                            Text(
                              '$average%',
                              style: text.labelMedium!.copyWith(
                                color: colors.primary,
                              ),
                            ),
                          ],
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
                            label: 'All (${counts[_SavedFilter.all]})',
                            compact: true,
                            selected: _filter == _SavedFilter.all,
                            onTap: () =>
                                setState(() => _filter = _SavedFilter.all),
                          ),
                          for (final entry in const [
                            _SavedFilter.readyToApply,
                            _SavedFilter.highMatch,
                            _SavedFilter.expiringSoon,
                          ]) ...[
                            const SizedBox(width: ScoutSpace.xs + 2),
                            ScoutFilterPill(
                              label: switch (entry) {
                                _SavedFilter.readyToApply =>
                                  'Ready to apply (${counts[entry]})',
                                _SavedFilter.highMatch =>
                                  'High match ≥90% (${counts[entry]})',
                                _SavedFilter.expiringSoon =>
                                  'Expiring soon (${counts[entry]})',
                                _SavedFilter.all => 'All',
                              },
                              compact: true,
                              selected: _filter == entry,
                              onTap: () => setState(() => _filter = entry),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: ScoutSpace.md),
                    if (visible.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: ScoutSpace.xl),
                        child: ScoutEmptyState(
                          icon: Icons.bookmark_outline,
                          message: items.isEmpty
                              ? 'Nothing saved yet.\nSave a job from Discover to find it here.'
                              : 'No saved jobs match this view.\nClear the search or filter to see all ${items.length}.',
                        ),
                      )
                    else
                      for (final model in visible) ...[
                        _SavedJobCard(
                          model: model,
                          onPlanToApply: () async {
                            await store.trackJob(
                              model.job.id,
                              ApplicationStatus.planToApply,
                            );
                            final application =
                                store.applicationForJob(model.job.id);
                            if (context.mounted && application != null) {
                              await context
                                  .push('/application/${application.id}');
                            }
                          },
                          onRemove: () => store.rejectMatch(model.match.id),
                          onOpen: () => context.push('/job/${model.job.id}'),
                          onReportExpired: () =>
                              confirmReportExpired(context, store, model.job),
                        ),
                        const SizedBox(height: ScoutSpace.sm),
                      ],
                    const SizedBox(height: ScoutSpace.sm),
                    Container(
                      padding: const EdgeInsets.all(ScoutSpace.md),
                      decoration: BoxDecoration(
                        color: colors.surfaceLow,
                        borderRadius: BorderRadius.circular(ScoutRadius.lg),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        runSpacing: ScoutSpace.sm,
                        spacing: ScoutSpace.sm,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.folder_open,
                                size: 18,
                                color: colors.muted,
                              ),
                              const SizedBox(width: ScoutSpace.sm),
                              Text('Batch actions', style: text.labelMedium),
                            ],
                          ),
                          Wrap(
                            spacing: ScoutSpace.xs + 2,
                            runSpacing: ScoutSpace.xs + 2,
                            children: [
                              ScoutButton(
                                label: 'Export CSV',
                                icon: Icons.file_download_outlined,
                                dense: true,
                                expand: false,
                                onPressed: items.isEmpty
                                    ? null
                                    : () => _exportCsv(items),
                              ),
                              ScoutButton(
                                label: 'Re-score',
                                icon: Icons.refresh,
                                dense: true,
                                expand: false,
                                onPressed: () async {
                                  final errors = await refreshScout(ref);
                                  if (!context.mounted) return;
                                  showFeedRefreshFeedback(context, errors);
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
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
}

class _SavedJobCard extends ConsumerWidget {
  const _SavedJobCard({
    required this.model,
    required this.onPlanToApply,
    required this.onRemove,
    required this.onOpen,
    required this.onReportExpired,
  });

  final JobCardModel model;
  final VoidCallback onPlanToApply;
  final VoidCallback onRemove;
  final VoidCallback onOpen;
  final VoidCallback onReportExpired;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    final job = model.job;
    final match = model.match;
    final application = ref.watch(storeProvider).applicationForJob(job.id);
    final daysLeft = daysUntilExpiry(job);

    return GestureDetector(
      onLongPress: onReportExpired,
      child: ScoutCard(
        onTap: onOpen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ScoutMonogram(label: job.company),
                const SizedBox(width: ScoutSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        job.company,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodySmall,
                      ),
                      Text(
                        job.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.titleSmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: ScoutSpace.xs),
                Icon(Icons.bookmark, size: 20, color: colors.primary),
              ],
            ),
            const SizedBox(height: ScoutSpace.sm),
            ScoutBadgeWrap(
              children: [
                ScoutBadge(
                  label: '${match.matchScore}% Match',
                  tone: ScoutBadgeTone.soft,
                  icon: Icons.bolt,
                ),
                ScoutBadge(
                  label: _compactSalary(job),
                  tone: ScoutBadgeTone.tonal,
                ),
                ScoutBadge(label: job.locationText, tone: ScoutBadgeTone.tonal),
                ScoutBadge(
                  label: 'Saved ${formatShortAgo(match.createdAt)}',
                  tone: ScoutBadgeTone.outline,
                ),
              ],
            ),
            if (daysLeft != null) ...[
              const SizedBox(height: ScoutSpace.xs + 2),
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: colors.outline),
                  const SizedBox(width: 4),
                  Text(
                    daysLeft >= 0
                        ? 'Closes ${formatShortDate(job.expiresAt!)} ($daysLeft days left)'
                        : 'Listing expired ${formatShortDate(job.expiresAt!)}',
                    style: text.labelSmall,
                  ),
                ],
              ),
            ],
            if (application?.notes?.isNotEmpty == true) ...[
              const SizedBox(height: ScoutSpace.sm),
              ScoutNotice(
                icon: Icons.edit_note,
                child: Text(
                  'Note: ${application!.notes}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: ScoutSpace.sm),
            Row(
              children: [
                ScoutButton(
                  key: ValueKey('plan-${job.id}'),
                  label: 'Plan to apply',
                  trailingIcon: Icons.arrow_forward,
                  variant: ScoutButtonVariant.primary,
                  dense: true,
                  expand: false,
                  onPressed: onPlanToApply,
                ),
                const Spacer(),
                ScoutButton(
                  label: 'Details',
                  dense: true,
                  expand: false,
                  onPressed: onOpen,
                ),
                const SizedBox(width: ScoutSpace.xs),
                ScoutIconButton(
                  key: ValueKey('remove-${job.id}'),
                  icon: Icons.delete_outline,
                  tooltip: 'Remove from saved',
                  size: 32,
                  ghost: true,
                  onPressed: onRemove,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _compactSalary(Job job) {
  if (!job.hasSalary) return 'No salary';
  String k(double value) {
    final thousands = value / 1000;
    return thousands == thousands.roundToDouble()
        ? '\$${thousands.round()}k'
        : '\$${thousands.toStringAsFixed(1)}k';
  }

  if (job.salaryMin != null && job.salaryMax != null) {
    return '${k(job.salaryMin!)} – ${k(job.salaryMax!)}';
  }
  return k(job.salaryMin ?? job.salaryMax!);
}
