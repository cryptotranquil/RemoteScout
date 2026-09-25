import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/neumorphic.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_store.dart';
import '../../data/providers.dart';
import '../../models/models.dart';

/// Raised soft job card — Discover and Saved lists (04_UIUX_Design.md §4.2).
class JobCard extends StatelessWidget {
  const JobCard({
    super.key,
    required this.model,
    this.onSave,
    this.onReject,
    this.onPlanToApply,
    this.onReportExpired,
  });

  final JobCardModel model;
  final VoidCallback? onSave;
  final VoidCallback? onReject;
  final VoidCallback? onPlanToApply;

  /// Long-press action — "report expired" is available on every job card.
  final VoidCallback? onReportExpired;

  Job get job => model.job;
  JobMatch get match => model.match;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: NeuCard(
        onTap: () => context.push('/job/${job.id}'),
        onLongPress:
            onReportExpired == null ? null : () => onReportExpired!(),
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
                      Text(
                        job.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              job.company,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                                    color: palette.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ScoreRing(score: match.matchScore, size: 44),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                LocationBadge(
                  scope: job.locationScope.wire,
                  detail: job.locationText,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${formatPostedAgo(job.publishedAt)} · ${job.employmentLabel}',
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SourceBadge(source: job.source),
                if (job.hasSalary) ...[
                  Text('  ·  ', style: Theme.of(context).textTheme.bodySmall),
                  Text(
                    job.salaryLabel,
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                          color: palette.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: NeuButton(
                    key: ValueKey('save-${job.id}'),
                    onPressed: onSave,
                    expand: true,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: const Text('Save'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: NeuButton(
                    key: ValueKey('reject-${job.id}'),
                    onPressed: onReject,
                    expand: true,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: const Text('Reject'),
                  ),
                ),
                if (onPlanToApply != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: NeuButton(
                      onPressed: onPlanToApply,
                      expand: true,
                      filled: true,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: const Text('Plan to apply'),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Muted centered empty state (e.g. "No more high-match jobs today.").
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: palette.base,
                  shape: BoxShape.circle,
                  boxShadow: palette.inset(blur: 10, distance: 4),
                ),
                child: Icon(icon, size: 30, color: palette.textSecondary),
              ),
              const SizedBox(height: 18),
            ],
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium!
                  .copyWith(color: palette.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared screen heading ("Today's best opportunities" + date).
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Small accent highlight used for matched skills.
class SkillChip extends StatelessWidget {
  const SkillChip({super.key, required this.label, required this.matched});

  final String label;
  final bool matched;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    return Container(
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: palette.base,
        borderRadius: BorderRadius.circular(14),
        boxShadow:
            matched ? palette.inset(blur: 6, distance: 2) : palette.raised(blur: 6, distance: 2),
      ),
      child: Text(
        matched ? '✓ $label' : label,
        style: Theme.of(context).textTheme.labelSmall!.copyWith(
              color: matched ? palette.accent : palette.textSecondary,
              fontWeight: matched ? FontWeight.w700 : FontWeight.w500,
            ),
      ),
    );
  }
}

/// Quiet "Posted on [Source]" attribution line (attribution compliance).
class AttributionLine extends StatelessWidget {
  const AttributionLine({super.key, required this.job});

  final Job job;

  String get _sourceName {
    switch (job.source) {
      case 'remotive':
        return 'Remotive';
      case 'remoteok':
        return 'Remote OK';
      case 'manual':
        return 'a manual entry';
      default:
        return job.source;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          job.source == 'manual'
              ? 'Added manually by you'
              : 'Posted on $_sourceName — always linked back to the original listing.',
          style: Theme.of(context)
              .textTheme
              .bodySmall!
              .copyWith(color: palette.textSecondary),
        ),
        const SizedBox(height: 4),
        Text(
          'Collected ${formatShortDate(job.collectedAt)}',
          style: Theme.of(context)
              .textTheme
              .labelSmall!
              .copyWith(color: palette.textSecondary),
        ),
      ],
    );
  }
}

/// Band color helper re-export for screens.
Color matchBandColor(int score) => scoreBandColor(score);

/// Shared "report expired" confirmation (available on every job card).
Future<void> confirmReportExpired(
    BuildContext context, AppStore store, Job job) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Report expired job?'),
      content: Text(
        '"${job.title}" at ${job.company} will be flagged as expired and kept '
        'out of future recommendations. This never auto-applies or contacts '
        'the employer.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          key: const ValueKey('confirm-report-expired'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Report expired'),
        ),
      ],
    ),
  );
  if (confirmed == true) {
    await store.reportExpired(job.id);
  }
}
