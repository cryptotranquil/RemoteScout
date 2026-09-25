import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/neumorphic.dart';
import '../../core/utils/formatters.dart';
import '../../data/providers.dart';
import '../../models/models.dart';
import '../discover/job_card.dart';

/// Applications tab — the tracker (03_App_Flow.md §6).
class ApplicationsScreen extends ConsumerStatefulWidget {
  const ApplicationsScreen({super.key});

  @override
  ConsumerState<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends ConsumerState<ApplicationsScreen> {
  ApplicationStatus? _filter; // null = All
  bool _followUpsView = false;

  @override
  Widget build(BuildContext context) {
    final cards = ref.watch(applicationCardsProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: cards.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(message: 'Something went wrong: $e'),
          data: (items) {
            final followUps = items
                .where((c) =>
                    c.application.followUpAt != null &&
                    c.application.status != ApplicationStatus.closed &&
                    c.application.status != ApplicationStatus.rejected)
                .toList()
              ..sort((a, b) => a.application.followUpAt!
                  .compareTo(b.application.followUpAt!));

            final filtered = _followUpsView
                ? followUps
                : items
                    .where((c) =>
                        _filter == null || c.application.status == _filter)
                    .toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                ScreenHeader(
                  title: 'Applications',
                  subtitle: _followUpsView
                      ? 'Upcoming follow-ups — never lose track of one.'
                      : 'Your pipeline: New → Saved → Plan to apply → Applied → …',
                  trailing: NeuIconButton(
                    key: const ValueKey('add-manually'),
                    icon: Icons.add,
                    tooltip: 'Add manually',
                    size: 48,
                    onPressed: () => context.push('/application/new'),
                  ),
                ),
                Row(
                  children: [
                    NeuPill(
                      label: 'Pipeline',
                      selected: !_followUpsView,
                      onTap: () => setState(() => _followUpsView = false),
                    ),
                    NeuPill(
                      label: 'Follow-ups',
                      selected: _followUpsView,
                      icon: Icons.notifications_active_outlined,
                      onTap: () => setState(() => _followUpsView = true),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (!_followUpsView)
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        NeuPill(
                          label: 'All',
                          selected: _filter == null,
                          onTap: () => setState(() => _filter = null),
                        ),
                        for (final status in ApplicationStatus.values)
                          NeuPill(
                            label: status.label,
                            selected: _filter == status,
                            onTap: () => setState(() => _filter = status),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                if (filtered.isEmpty)
                  EmptyState(
                    icon: Icons.work_outline,
                    message: _followUpsView
                        ? 'No follow-ups scheduled.\nSet one from any application.'
                        : 'Nothing here yet.\nSave a job, plan to apply, or add one manually.',
                  )
                else
                  ...filtered.map(
                    (c) => _ApplicationCard(
                      key: ValueKey('app-${c.application.id}'),
                      model: c,
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({super.key, required this.model});

  final ApplicationCardModel model;

  @override
  Widget build(BuildContext context) {
    final palette = NeuPalette.of(context);
    final app = model.application;
    final overdue = app.followUpAt != null && app.followUpAt!.isBefore(DateTime.now());

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: NeuCard(
        onTap: () => context.push('/application/${app.id}'),
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
                      Text(model.title,
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(model.company,
                          style:
                              Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: palette.base,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: palette.inset(blur: 6, distance: 2),
                  ),
                  child: Text(
                    app.status.label,
                    style: Theme.of(context).textTheme.labelSmall!.copyWith(
                          color: palette.accent,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (app.appliedAt != null) ...[
                  Text(
                    'Applied ${formatShortDate(app.appliedAt!)}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                  const SizedBox(width: 12),
                ],
                if (app.followUpAt != null)
                  Expanded(
                    child: Text(
                      '${overdue ? 'Follow-up overdue' : 'Follow up'} ${formatShortDate(app.followUpAt!)}',
                      style: Theme.of(context).textTheme.labelSmall!.copyWith(
                            color: overdue ? palette.accent : palette.textSecondary,
                            fontWeight:
                                overdue ? FontWeight.w700 : FontWeight.w500,
                          ),
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
