import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui/scout_ui.dart';
import '../../core/utils/formatters.dart';
import '../../data/app_store.dart';
import '../../data/providers.dart';
import '../../models/models.dart';

/// Scannable job row used by Discover and Saved.
///
/// Reading order matches the design: who/where at the top, the role in the
/// largest type, then match + eligibility, money, and finally the reason the
/// matcher surfaced it.
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

  /// Long-press action — "report expired" is available on every job row.
  final VoidCallback? onReportExpired;

  Job get job => model.job;
  JobMatch get match => model.match;

  @override
  Widget build(BuildContext context) {
    final colors = ScoutColors.of(context);
    final text = Theme.of(context).textTheme;
    final saved = match.isSaved;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onLongPress: onReportExpired,
      child: ScoutCard(
        onTap: () => context.push('/job/${job.id}'),
        padding: const EdgeInsets.all(ScoutSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ScoutMonogram(label: job.company, size: 24),
                const SizedBox(width: ScoutSpace.xs),
                Flexible(
                  child: Text(
                    job.company,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text('•', style: text.labelSmall),
                ),
                Flexible(child: ScoutSourceBadge(source: job.source)),
                const Spacer(),
                Text(
                  formatShortAgo(job.publishedAt),
                  style: text.labelSmall,
                ),
              ],
            ),
            const SizedBox(height: ScoutSpace.sm),
            Text(
              job.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.titleLarge,
            ),
            const SizedBox(height: ScoutSpace.xs + 2),
            ScoutBadgeWrap(
              children: [
                ScoutBadge(
                  label:
                      '${match.matchScore}% Match • ${formatFitLabel(match.matchScore)}',
                  tone: ScoutBadgeTone.solid,
                ),
                ScoutLocationBadge(
                  scope: job.locationScope.wire,
                  detail: job.locationText,
                ),
              ],
            ),
            const SizedBox(height: ScoutSpace.sm),
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatSalaryFull(job),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleSmall!.copyWith(color: colors.primary),
                  ),
                ),
                const SizedBox(width: ScoutSpace.sm),
                Text(job.employmentLabel, style: text.labelSmall),
              ],
            ),
            if (match.matchReason.isNotEmpty) ...[
              const SizedBox(height: ScoutSpace.sm),
              ScoutNotice(
                icon: Icons.auto_awesome,
                child: Text(
                  match.matchReason,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
            const SizedBox(height: ScoutSpace.sm),
            Row(
              children: [
                ScoutButton(
                  key: ValueKey('save-${job.id}'),
                  label: saved ? 'Saved' : 'Save',
                  icon: saved ? Icons.bookmark : Icons.bookmark_outline,
                  onPressed: saved ? null : onSave,
                  dense: true,
                  expand: false,
                ),
                const SizedBox(width: ScoutSpace.xs + 2),
                ScoutButton(
                  key: ValueKey('reject-${job.id}'),
                  label: 'Pass',
                  icon: Icons.close,
                  variant: ScoutButtonVariant.text,
                  onPressed: onReject,
                  dense: true,
                  expand: false,
                ),
                const SizedBox(width: ScoutSpace.sm),
                Flexible(
                  child: ScoutButton(
                    key: ValueKey('open-${job.id}'),
                    label: 'View details',
                    trailingIcon: Icons.arrow_forward,
                    variant: ScoutButtonVariant.primary,
                    onPressed: () => context.push('/job/${job.id}'),
                    dense: true,
                    expand: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared "report expired" confirmation (available on every job row).
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
