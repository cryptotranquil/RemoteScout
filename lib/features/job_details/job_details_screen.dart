import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/neumorphic.dart';
import '../../core/utils/formatters.dart';
import '../../data/providers.dart';
import '../../models/models.dart';
import '../discover/job_card.dart';

/// Full job detail (03_App_Flow.md §4): why it matched, skills, attribution,
/// and a sticky action bar that always links to the original listing.
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
    final palette = NeuPalette.of(context);

    if (job == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const EmptyState(message: 'This job is no longer available.'),
      );
    }

    final match = store.matchForJob(jobId);
    final profile = ref.watch(profileProvider).valueOrNull;
    final result = match == null ? liveScore(job, profile) : null;
    final score = match?.matchScore ?? result?.score ?? 0;
    final reasons = match?.breakdown ??
        result?.reasons ??
        const ['— No scoring data yet'];
    final matchedSkills = match?.matchedSkills ?? result?.matchedSkills ?? const <String>[];
    final missingSkills = match?.missingSkills ?? result?.missingSkills ?? const <String>[];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  Row(
                    children: [
                      NeuIconButton(
                        icon: Icons.arrow_back,
                        onPressed: () => context.pop(),
                        size: 46,
                        tooltip: 'Back',
                      ),
                      const Spacer(),
                      SourceBadge(source: job.source),
                    ],
                  ),
                  const SizedBox(height: 16),
                  NeuCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(job.title,
                                  style:
                                      Theme.of(context).textTheme.headlineSmall),
                            ),
                            ScoreRing(score: score, size: 64),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(job.company,
                            style: Theme.of(context).textTheme.titleSmall!.copyWith(
                                color: palette.textSecondary)),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            LocationBadge(
                              scope: job.locationScope.wire,
                              detail: job.locationText,
                            ),
                            _MetaChip(label: job.employmentLabel),
                            if (job.hasSalary) _MetaChip(label: job.salaryLabel),
                            _MetaChip(
                                label: 'Posted ${formatPostedAgo(job.publishedAt)}'),
                          ],
                        ),
                        if (job.isExpiredReported) ...[
                          const SizedBox(height: 12),
                          Text(
                            'You reported this listing as expired — it is kept '
                            'out of future recommendations.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _WhyMatchedCard(reasons: reasons, score: score),
                  const SizedBox(height: 18),
                  NeuCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const NeuSectionLabel('Required skills'),
                        if (matchedSkills.isEmpty && missingSkills.isEmpty)
                          Text('No specific tools named in this listing.',
                              style: Theme.of(context).textTheme.bodyMedium)
                        else ...[
                          Wrap(
                            children: [
                              for (final s in matchedSkills) SkillChip(label: s, matched: true),
                            ],
                          ),
                          if (missingSkills.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text('Not on your profile:',
                                style: Theme.of(context).textTheme.bodySmall),
                            const SizedBox(height: 8),
                            Wrap(
                              children: [
                                for (final s in missingSkills)
                                  SkillChip(label: s, matched: false),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  NeuCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const NeuSectionLabel('Source & attribution'),
                        AttributionLine(job: job),
                        const SizedBox(height: 12),
                        Text(
                          job.description.isEmpty
                              ? 'No description supplied by the source.'
                              : job.description,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              decoration: BoxDecoration(
                color: palette.base,
                boxShadow: [
                  BoxShadow(
                    color: palette.shadow,
                    blurRadius: 14,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  NeuButton(
                    key: const ValueKey('view-listing'),
                    filled: true,
                    onPressed: () => _openListing(job),
                    child: const Text('View Original Listing ↗'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: NeuButton(
                          key: const ValueKey('plan-to-apply'),
                          onPressed: () async {
                            final app = await store.trackJob(
                                job.id, ApplicationStatus.planToApply);
                            await store.saveMatch(
                                match?.id ?? 'match-${job.id}');
                            if (context.mounted) {
                              await context.push('/application/${app.id}');
                            }
                          },
                          child: const Text('Plan to apply'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      NeuIconButton(
                        key: const ValueKey('details-save'),
                        icon: Icons.bookmark_outline,
                        tooltip: 'Save',
                        onPressed: match?.isSaved == true
                            ? null
                            : () => store.saveMatch(match?.id ?? 'match-${job.id}'),
                      ),
                      const SizedBox(width: 8),
                      NeuIconButton(
                        key: const ValueKey('details-reject'),
                        icon: Icons.close,
                        tooltip: 'Reject',
                        onPressed: () {
                          store
                              .rejectMatch(match?.id ?? 'match-${job.id}')
                              .then((_) {
                            if (context.mounted) context.pop();
                          });
                        },
                      ),
                      const SizedBox(width: 8),
                      NeuIconButton(
                        key: const ValueKey('details-report'),
                        icon: Icons.flag_outlined,
                        tooltip: 'Report expired',
                        onPressed: () =>
                            confirmReportExpired(context, store, job),
                      ),
                    ],
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

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: palette.base,
        borderRadius: BorderRadius.circular(14),
        boxShadow: palette.raised(blur: 6, distance: 2),
      ),
      child: Text(label,
          style: Theme.of(context)
              .textTheme
              .labelSmall!
              .copyWith(fontWeight: FontWeight.w600)),
    );
  }
}

class _WhyMatchedCard extends StatelessWidget {
  const _WhyMatchedCard({required this.reasons, required this.score});

  final List<String> reasons;
  final int score;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    return NeuCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: NeuSectionLabel('Why this matched')),
              Text('$score%',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall!
                      .copyWith(color: palette.accent)),
            ],
          ),
          for (final reason in reasons)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(reason,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
            'Scoring: skills 40 · title 25 · location 20 · experience 10 · freshness 5',
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}
