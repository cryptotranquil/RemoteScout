import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/formatters.dart';
import '../../data/providers.dart';
import 'job_card.dart';

/// "Today's Recommendations" — a short ranked list, not a feed (PRD §6.2).
class DiscoverScreen extends ConsumerWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: today.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(message: 'Something went wrong: $e'),
          data: (picks) => RefreshIndicator(
            onRefresh: () async => ref.read(storeProvider).refresh(),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                ScreenHeader(
                  title: "Today's best opportunities",
                  subtitle: formatDayHeader(DateTime.now()),
                ),
                if (picks.isEmpty)
                  const EmptyState(
                    icon: Icons.checklist,
                    message: 'No more high-match jobs today.\n'
                        'Come back after the next digest — we only surface '
                        'genuinely high-match roles.',
                  )
                else
                  ...picks.map(
                    (model) => JobCard(
                      model: model,
                      onSave: () => ref.read(storeProvider).saveMatch(model.match.id),
                      onReject: () =>
                          ref.read(storeProvider).rejectMatch(model.match.id),
                      onReportExpired: () => confirmReportExpired(
                        context,
                        ref.read(storeProvider),
                        model.job,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
