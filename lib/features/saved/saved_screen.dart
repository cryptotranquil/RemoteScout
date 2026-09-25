import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/neumorphic.dart';
import '../../data/providers.dart';
import '../../models/models.dart';
import '../discover/job_card.dart';

/// Saved tab — explicitly saved jobs (03_App_Flow.md §5).
class SavedScreen extends ConsumerStatefulWidget {
  const SavedScreen({super.key});

  @override
  ConsumerState<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends ConsumerState<SavedScreen> {
  String _query = '';
  bool _sortByScore = true;

  @override
  Widget build(BuildContext context) {
    final saved = ref.watch(savedProvider);
    final store = ref.read(storeProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: saved.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => EmptyState(message: 'Something went wrong: $e'),
          data: (items) {
            final filtered = items.where((m) {
              if (_query.isEmpty) return true;
              final q = _query.toLowerCase();
              return m.job.title.toLowerCase().contains(q) ||
                  m.job.company.toLowerCase().contains(q) ||
                  m.match.matchScore.toString().contains(q);
            }).toList()
              ..sort((a, b) => _sortByScore
                  ? b.match.matchScore.compareTo(a.match.matchScore)
                  : b.job.publishedAt.compareTo(a.job.publishedAt));

            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              children: [
                const ScreenHeader(
                  title: 'Saved',
                  subtitle: 'Jobs you set aside — move them forward or reject them.',
                ),
                NeuInput(
                  key: const ValueKey('saved-search'),
                  hint: 'Search title, company, or score…',
                  onChanged: (v) => setState(() => _query = v),
                  suffix: Icon(Icons.search,
                      size: 20,
                      color: NeuPalette.of(context).textSecondary),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    NeuPill(
                      label: 'Match score',
                      selected: _sortByScore,
                      onTap: () => setState(() => _sortByScore = true),
                    ),
                    NeuPill(
                      label: 'Newest posted',
                      selected: !_sortByScore,
                      onTap: () => setState(() => _sortByScore = false),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (filtered.isEmpty)
                  EmptyState(
                    icon: Icons.bookmark_outline,
                    message: _query.isEmpty
                        ? 'Nothing saved yet.\nSave a job from Discover to find it here.'
                        : 'No saved jobs match "$_query".',
                  )
                else
                  ...filtered.map(
                    (model) => JobCard(
                      model: model,
                      onPlanToApply: () => store.trackJob(
                        model.job.id,
                        ApplicationStatus.planToApply,
                      ),
                      onReject: () => store.rejectMatch(model.match.id),
                      onReportExpired: () =>
                          confirmReportExpired(context, store, model.job),
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
