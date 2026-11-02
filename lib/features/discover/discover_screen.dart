import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/scout_ui.dart';
import '../../core/utils/formatters.dart';
import '../../data/providers.dart';
import '../../models/models.dart';
import 'job_card.dart';
import 'search_on_sites.dart';

/// "Today's Recommendations" — a short ranked list, not a feed (PRD §6.2).
class DiscoverScreen extends ConsumerStatefulWidget {
  const DiscoverScreen({super.key});

  @override
  ConsumerState<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends ConsumerState<DiscoverScreen> {
  /// null = all roles. Otherwise 'role:<title>', 'salary' or 'worldwide'.
  String? _filter;
  bool _refreshing = false;

  List<JobCardModel> _apply(List<JobCardModel> picks) {
    final filter = _filter;
    if (filter == null) return picks;
    return picks.where((model) {
      if (filter == 'salary') return model.job.hasSalary;
      if (filter == 'worldwide') {
        return model.job.locationScope == LocationScope.worldwide;
      }
      if (filter.startsWith('role:')) {
        final role = filter.substring(5).toLowerCase();
        return model.job.title.toLowerCase().contains(role) ||
            model.match.matchReason.toLowerCase().contains(role);
      }
      return true;
    }).toList();
  }

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      final errors = await refreshScout(ref);
      if (mounted && errors.isNotEmpty) {
        showFeedRefreshFeedback(context, errors);
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    final today = ref.watch(todayProvider);
    final profile = ref.watch(profileProvider).valueOrNull;
    final prefs =
        ref.watch(prefsProvider).valueOrNull ?? const NotificationPrefs();
    final jobs = ref.watch(jobsProvider).valueOrNull ?? const <Job>[];
    final matches =
        ref.watch(matchesProvider).valueOrNull ?? const <JobMatch>[];
    final lastSync = ref.watch(lastSyncProvider);
    final store = ref.read(storeProvider);

    final picks = today.valueOrNull ?? const <JobCardModel>[];
    final visible = _apply(picks);

    final metThreshold =
        matches.where((m) => m.matchScore >= prefs.minMatchScore).length;
    final sourceNames = <String>{
      for (final job in jobs) _sourceName(job.source),
    }.toList()
      ..sort();

    final roles = (profile?.targetRoles ?? const <String>[]).take(2).toList();
    final initialSearchKeywords = profile?.targetRoles.isNotEmpty == true
        ? profile!.targetRoles.first
        : '';

    return Scaffold(
      body: Column(
        children: [
          ScoutAppHeader(
            subtitle: formatSyncStamp(lastSync),
            avatarName: profile?.name,
            onAvatarTap: () => context.go('/profile'),
          ),
          Expanded(
            child: today.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) =>
                  ScoutEmptyState(message: 'Something went wrong: $error'),
              data: (_) => RefreshIndicator(
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    ScoutSpace.lg,
                    ScoutSpace.sm,
                    ScoutSpace.lg,
                    ScoutSpace.xl,
                  ),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            "Today's Recommendations",
                            style: text.labelLarge,
                          ),
                        ),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: colors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: ScoutSpace.xs + 1),
                        Text(
                          'Curated for you',
                          style: text.labelMedium!.copyWith(
                            color: colors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatDayHeader(DateTime.now())} • '
                      '${picks.length} qualified ${picks.length == 1 ? 'match' : 'matches'}',
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: ScoutSpace.md),
                    SearchOnSites(initialKeywords: initialSearchKeywords),
                    SizedBox(
                      height: 34,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          ScoutFilterPill(
                            label: 'All roles',
                            selected: _filter == null,
                            compact: true,
                            onTap: () => setState(() => _filter = null),
                          ),
                          for (final role in roles) ...[
                            const SizedBox(width: ScoutSpace.xs + 2),
                            ScoutFilterPill(
                              label: role,
                              compact: true,
                              selected: _filter == 'role:$role',
                              onTap: () => setState(
                                () => _filter = _filter == 'role:$role'
                                    ? null
                                    : 'role:$role',
                              ),
                            ),
                          ],
                          const SizedBox(width: ScoutSpace.xs + 2),
                          ScoutFilterPill(
                            label: 'Salary listed',
                            compact: true,
                            selected: _filter == 'salary',
                            onTap: () => setState(
                              () => _filter =
                                  _filter == 'salary' ? null : 'salary',
                            ),
                          ),
                          const SizedBox(width: ScoutSpace.xs + 2),
                          ScoutFilterPill(
                            label: 'Worldwide',
                            compact: true,
                            selected: _filter == 'worldwide',
                            onTap: () => setState(
                              () => _filter =
                                  _filter == 'worldwide' ? null : 'worldwide',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: ScoutSpace.md),
                    if (visible.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: ScoutSpace.xl),
                        child: ScoutEmptyState(
                          icon: _filter == null
                              ? Icons.checklist
                              : Icons.filter_alt_off_outlined,
                          message: _filter == null
                              ? 'No more high-match jobs today.\n'
                                  'The next digest runs at '
                                  '${formatTimeOfDay(prefs.digestTime)}.'
                              : 'No recommendations match this filter.\n'
                                  'Clear it to see the full shortlist.',
                        ),
                      )
                    else
                      for (final model in visible) ...[
                        JobCard(
                          model: model,
                          onSave: () => store.saveMatch(model.match.id),
                          onReject: () => store.rejectMatch(model.match.id),
                          onReportExpired: () =>
                              confirmReportExpired(context, store, model.job),
                        ),
                        const SizedBox(height: ScoutSpace.sm),
                      ],
                    const SizedBox(height: ScoutSpace.xs),
                    _SyncPanel(
                      crawled: jobs.length,
                      sources: sourceNames,
                      metThreshold: metThreshold,
                      threshold: prefs.minMatchScore,
                      digestTime: prefs.digestTime,
                      refreshing: _refreshing,
                      onRefresh: _refresh,
                    ),
                  ],
                ),
              ),
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
      return 'Manual';
    default:
      return source;
  }
}

/// Flat "Sync summary" footer: what the scout crawled and when it runs next.
class _SyncPanel extends StatelessWidget {
  const _SyncPanel({
    required this.crawled,
    required this.sources,
    required this.metThreshold,
    required this.threshold,
    required this.digestTime,
    required this.refreshing,
    required this.onRefresh,
  });

  final int crawled;
  final List<String> sources;
  final int metThreshold;
  final int threshold;
  final String digestTime;
  final bool refreshing;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(ScoutSpace.md),
      decoration: BoxDecoration(
        color: colors.surfaceLow,
        borderRadius: BorderRadius.circular(ScoutRadius.md),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.sync, size: 18, color: colors.primary),
              const SizedBox(width: ScoutSpace.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Sync summary', style: text.titleSmall),
                    const SizedBox(height: 2),
                    Text(
                      '$crawled crawled across ${sources.length} '
                      '${sources.length == 1 ? 'source' : 'sources'}, '
                      '$metThreshold met your threshold (≥$threshold%). '
                      'Next digest at ${formatTimeOfDay(digestTime)}.',
                      style: text.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: ScoutSpace.sm),
          Container(height: 1, color: colors.surfaceHigh),
          const SizedBox(height: ScoutSpace.xs),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Sources: ${sources.isEmpty ? '—' : sources.join(', ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.labelSmall,
                ),
              ),
              const SizedBox(width: ScoutSpace.sm),
              InkWell(
                onTap: refreshing ? null : () => onRefresh(),
                borderRadius: BorderRadius.circular(ScoutRadius.sm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: ScoutSpace.xs,
                    vertical: ScoutSpace.xs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: refreshing
                            ? CircularProgressIndicator(
                                strokeWidth: 1.6,
                                color: colors.primary,
                              )
                            : Icon(
                                Icons.refresh,
                                size: 14,
                                color: colors.primary,
                              ),
                      ),
                      const SizedBox(width: ScoutSpace.xs),
                      Text(
                        'Force refresh feed',
                        style:
                            text.labelMedium!.copyWith(color: colors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
