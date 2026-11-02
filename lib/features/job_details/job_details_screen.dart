import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/scoring/match_scorer.dart';
import '../../core/ui/scout_ui.dart';
import '../../core/utils/formatters.dart';
import '../../data/providers.dart';
import '../../models/models.dart';
import '../discover/job_card.dart';

/// Full job detail (03_App_Flow.md §4): why it matched, skills, attribution,
/// and a pinned action bar that always links to the original listing.
class JobDetailsScreen extends ConsumerWidget {
  const JobDetailsScreen({super.key, required this.jobId});

  final String jobId;

  Future<void> _openListing(Job job) async {
    final uri = Uri.tryParse(job.applyUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(storeProvider);
    final job = store.jobById(jobId);
    final profile = ref.watch(profileProvider).valueOrNull;

    if (job == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const ScoutEmptyState(
          icon: Icons.search_off,
          message: 'This job is no longer available.',
        ),
      );
    }

    final match = store.matchForJob(jobId);
    final live = match == null ? liveScore(job, profile) : null;
    final score = match?.matchScore ?? live?.score ?? 0;
    final reasons = match?.breakdown ?? live?.reasons ?? const <String>[];
    final matchedSkills =
        match?.matchedSkills ?? live?.matchedSkills ?? const <String>[];
    final missingSkills =
        match?.missingSkills ?? live?.missingSkills ?? const <String>[];
    final application = store.applicationForJob(job.id);

    return Scaffold(
      body: Column(
        children: [
          ScoutAppHeader(
            title: 'Job details',
            onBack: () => context.pop(),
            avatarName: profile?.name,
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                ScoutSpace.lg,
                0,
                ScoutSpace.lg,
                ScoutSpace.lg,
              ),
              children: [
                _RoleCard(job: job),
                const SizedBox(height: ScoutSpace.md),
                _WhyMatchedCard(
                  score: score,
                  reasons: reasons,
                  breakdown: live?.breakdown,
                ),
                const SizedBox(height: ScoutSpace.md),
                _SkillsCard(
                  matched: matchedSkills,
                  missing: missingSkills,
                ),
                const SizedBox(height: ScoutSpace.md),
                _SourceCard(job: job),
                if (job.description.isNotEmpty) ...[
                  const SizedBox(height: ScoutSpace.md),
                  _DescriptionCard(description: job.description),
                ],
                const SizedBox(height: ScoutSpace.md),
                ScoutNotice(
                  icon: Icons.privacy_tip_outlined,
                  child: Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(
                          text: 'JobRadar direct guarantee: ',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        TextSpan(
                          text: job.isExpiredReported
                              ? 'you reported this listing as expired, so it is '
                                  'kept out of future recommendations.'
                              : 'we are strictly your personal filter and '
                                  'strategy tracker. We never submit applications '
                                  'on your behalf — you apply directly with the '
                                  'employer.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _ActionBar(
        saved: match?.isSaved ?? false,
        planned: application != null,
        onPlanToApply: () async {
          final app = await store.trackJob(
            job.id,
            ApplicationStatus.planToApply,
          );
          if (match != null) {
            await store.saveMatch(match.id);
          }
          if (context.mounted) {
            await context.push('/application/${app.id}');
          }
        },
        onSave: match == null || match.isSaved
            ? null
            : () => store.saveMatch(match.id),
        onReportExpired: () => confirmReportExpired(context, store, job),
        onOpenListing: () => _openListing(job),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.job});

  final Job job;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    return ScoutCard(
      border: true,
      padding: const EdgeInsets.all(ScoutSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: ScoutSpace.xs + 2,
            runSpacing: ScoutSpace.xs,
            children: [
              ScoutBadge(
                label: job.isExpiredReported
                    ? 'Reported expired'
                    : 'Verified active',
                tone: job.isExpiredReported
                    ? ScoutBadgeTone.warning
                    : ScoutBadgeTone.tonal,
                icon: job.isExpiredReported ? Icons.flag_outlined : null,
              ),
              ScoutSourceBadge(source: job.source),
              Text(
                'Discovered ${formatShortAgo(job.collectedAt)}',
                style: text.labelSmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          const SizedBox(height: ScoutSpace.sm),
          Text(job.title, style: text.titleLarge),
          const SizedBox(height: ScoutSpace.xs),
          Wrap(
            spacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(job.company, style: text.titleSmall),
              Text('•', style: text.bodySmall),
              Text(job.employmentLabel, style: text.bodySmall),
              Text('•', style: text.bodySmall),
              Text(job.locationText, style: text.bodySmall),
            ],
          ),
          const SizedBox(height: ScoutSpace.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(ScoutSpace.md),
            decoration: BoxDecoration(
              color: colors.surfaceLow,
              borderRadius: BorderRadius.circular(ScoutRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.payments_outlined,
                        size: 18, color: colors.primary),
                    const SizedBox(width: ScoutSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ScoutSectionLabel('Target compensation'),
                          Text(
                            formatSalaryFull(job),
                            style: text.titleSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: ScoutSpace.sm),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.public, size: 18, color: colors.primary),
                    const SizedBox(width: ScoutSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ScoutSectionLabel('Location policy'),
                          Text(
                            switch (job.locationScope) {
                              LocationScope.worldwide =>
                                '${job.locationText} • any timezone',
                              LocationScope.regionRestricted =>
                                '${job.locationText} • region restricted',
                              LocationScope.countryRestricted =>
                                '${job.locationText} • country restricted',
                            },
                            style: text.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WhyMatchedCard extends StatelessWidget {
  const _WhyMatchedCard({
    required this.score,
    required this.reasons,
    this.breakdown,
  });

  final int score;
  final List<String> reasons;
  final ScoreBreakdown? breakdown;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    return ScoutCard(
      border: true,
      padding: const EdgeInsets.all(ScoutSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 20, color: colors.primary),
              const SizedBox(width: ScoutSpace.sm),
              Expanded(
                child: Text('Why this matched', style: text.titleMedium),
              ),
              ScoutBadge(
                label: '$score% Match',
                tone: ScoutBadgeTone.info,
                icon: Icons.verified_outlined,
              ),
            ],
          ),
          const SizedBox(height: ScoutSpace.md),
          for (final reason in reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: ScoutSpace.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    reason.startsWith('✓')
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_rounded,
                    size: 17,
                    color: reason.startsWith('✓')
                        ? colors.primary
                        : colors.tertiary,
                  ),
                  const SizedBox(width: ScoutSpace.sm),
                  Expanded(
                    child: Text(
                      reason.replaceFirst(RegExp(r'^(✓|—)\s*'), ''),
                      style: text.bodySmall!.copyWith(
                        color: reason.startsWith('✓')
                            ? colors.onSurface
                            : colors.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (breakdown != null) ...[
            const SizedBox(height: ScoutSpace.xs),
            Text(
              'Scoring: skills ${breakdown!.skill}/40 · title ${breakdown!.title}/25 '
              '· location ${breakdown!.location}/20 · experience '
              '${breakdown!.experience}/10 · freshness ${breakdown!.freshness}/5',
              style: text.labelSmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _SkillsCard extends StatelessWidget {
  const _SkillsCard({required this.matched, required this.missing});

  final List<String> matched;
  final List<String> missing;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    return ScoutCard(
      border: true,
      padding: const EdgeInsets.all(ScoutSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics_outlined, size: 20, color: colors.primary),
              const SizedBox(width: ScoutSpace.sm),
              Expanded(
                child: Text('Skills assessment', style: text.titleMedium),
              ),
              Text('Profile sync', style: text.labelSmall),
            ],
          ),
          const SizedBox(height: ScoutSpace.md),
          ScoutSectionLabel('Validated in your profile (${matched.length})'),
          const SizedBox(height: ScoutSpace.sm),
          if (matched.isEmpty)
            Text('No listed tools on your profile matched.',
                style: text.bodySmall)
          else
            Wrap(
              children: [
                for (final skill in matched)
                  ScoutSkillChip(label: skill, matched: true),
              ],
            ),
          const SizedBox(height: ScoutSpace.md),
          ScoutSectionLabel(
            'Unverified or missing mentions (${missing.length})',
          ),
          const SizedBox(height: ScoutSpace.sm),
          if (missing.isEmpty)
            Text('The listing names no tools missing from your profile.',
                style: text.bodySmall)
          else
            Wrap(
              children: [
                for (final skill in missing)
                  ScoutSkillChip(label: skill, matched: false),
              ],
            ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  const _SourceCard({required this.job});

  final Job job;

  String get _attribution {
    switch (job.source) {
      case 'remotive':
        return 'Remotive job board';
      case 'remoteok':
        return 'Remote OK feed';
      case 'himalayas':
        return 'Himalayas job listing';
      case 'jobicy':
        return 'Jobicy job listing';
      case 'arbeitnow':
        return 'Arbeitnow job listing';
      case 'adzuna':
        return 'Adzuna job listing';
      case 'jooble':
        return 'Jooble job listing';
      case 'themuse':
        return 'The Muse job listing';
      case 'findwork':
        return 'Findwork job listing';
      case 'weworkremotely':
        return 'We Work Remotely job listing';
      case 'manual':
        return 'Added manually by you';
      default:
        return job.source;
    }
  }

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: job.source == 'manual' ? null : () => _openSource(context),
            child: Row(
              children: [
                Icon(Icons.open_in_new, size: 16, color: colors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _attribution,
                    style: text.labelMedium!.copyWith(
                      color: job.source == 'manual'
                          ? colors.onSurface
                          : colors.primary,
                      decoration: job.source == 'manual'
                          ? TextDecoration.none
                          : TextDecoration.underline,
                    ),
                  ),
                ),
                Text(
                  job.source == 'manual' ? 'no intermediary' : 'view source',
                  style: text.labelMedium!.copyWith(color: colors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: ScoutSpace.xs),
          Text(
            'Last checked ${formatShortAgo(job.collectedAt)}. Always linked '
            'back to the original listing — JobRadar never proxies your '
            'application.',
            style: text.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> _openSource(BuildContext context) async {
    final uri = Uri.tryParse(job.sourceUrl);
    if (uri == null ||
        !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the original listing.')),
        );
      }
    }
  }
}

class _DescriptionCard extends StatelessWidget {
  const _DescriptionCard({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    return ScoutCard(
      border: true,
      padding: const EdgeInsets.all(ScoutSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('About the listing', style: text.titleMedium),
          const SizedBox(height: ScoutSpace.sm),
          Html(
            data: description,
            style: {
              'body': Style(
                color: colors.muted,
                fontFamily: text.bodyMedium!.fontFamily,
                fontSize: FontSize(text.bodyMedium!.fontSize!),
                lineHeight: LineHeight(text.bodyMedium!.height ?? 1.5),
              ),
              'a': Style(
                color: colors.primary,
                textDecoration: TextDecoration.underline,
              ),
            },
            onLinkTap: (url, _, __) async {
              final uri = Uri.tryParse(url ?? '');
              if (uri == null ||
                  (uri.scheme != 'http' && uri.scheme != 'https')) {
                return;
              }
              if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
                  context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not open the description link.'),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.saved,
    required this.planned,
    required this.onPlanToApply,
    required this.onSave,
    required this.onReportExpired,
    required this.onOpenListing,
  });

  final bool saved;
  final bool planned;
  final VoidCallback onPlanToApply;
  final VoidCallback? onSave;
  final VoidCallback onReportExpired;
  final VoidCallback onOpenListing;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.card,
        border: Border(top: BorderSide(color: colors.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            ScoutSpace.lg,
            ScoutSpace.sm,
            ScoutSpace.lg,
            ScoutSpace.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ScoutButton(
                      key: const ValueKey('plan-to-apply'),
                      label: planned ? 'In your tracker' : 'Plan to apply',
                      icon: Icons.event_available,
                      expand: true,
                      onPressed: onPlanToApply,
                    ),
                  ),
                  const SizedBox(width: ScoutSpace.sm),
                  ScoutIconButton(
                    key: const ValueKey('details-save'),
                    icon: saved ? Icons.bookmark : Icons.bookmark_outline,
                    tooltip: saved ? 'Saved' : 'Save',
                    filled: saved,
                    onPressed: onSave,
                  ),
                  const SizedBox(width: ScoutSpace.sm),
                  ScoutIconButton(
                    key: const ValueKey('details-report'),
                    icon: Icons.flag_outlined,
                    tooltip: 'Report expired',
                    onPressed: onReportExpired,
                  ),
                ],
              ),
              const SizedBox(height: ScoutSpace.sm),
              SizedBox(
                width: double.infinity,
                height: 36,
                child: TextButton(
                  key: const ValueKey('view-listing'),
                  onPressed: onOpenListing,
                  style: TextButton.styleFrom(
                    backgroundColor: colors.surfaceLow,
                    foregroundColor: colors.onSurface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ScoutRadius.md),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          'View original listing',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.north_east, size: 14, color: colors.muted),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
