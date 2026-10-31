import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/scoring/match_scorer.dart';
import '../models/models.dart';
import 'app_store.dart';

/// The concrete store instance, assigned in `main()` (and in tests).
late final AppStore appStore;

final storeProvider = Provider<AppStore>((ref) => appStore);

/// Timestamp of the last feed refresh — drives the "Sync: …" app-bar stamp.
final lastSyncProvider = StateProvider<DateTime?>((ref) => null);

/// Refreshes the store and stamps the sync time.
Future<void> refreshScout(WidgetRef ref) async {
  await ref.read(storeProvider).refresh();
  ref.read(lastSyncProvider.notifier).state = DateTime.now();
}

final profileProvider = StreamProvider<Profile?>(
  (ref) => ref.watch(storeProvider).watchProfile(),
);

final prefsProvider = StreamProvider<NotificationPrefs>(
  (ref) => ref.watch(storeProvider).watchPrefs(),
);

final jobsProvider = StreamProvider<List<Job>>(
  (ref) => ref.watch(storeProvider).watchJobs(),
);

final matchesProvider = StreamProvider<List<JobMatch>>(
  (ref) => ref.watch(storeProvider).watchMatches(),
);

final applicationsProvider = StreamProvider<List<Application>>(
  (ref) => ref.watch(storeProvider).watchApplications(),
);

/// A job paired with its match — the unit shown in cards.
class JobCardModel {
  const JobCardModel({required this.job, required this.match});

  final Job job;
  final JobMatch match;
}

/// "Today's Recommendations" — unseen matches at/above the user's minimum
/// score, ranked best-first and capped at max-jobs-per-day (PRD §6.2).
final todayProvider = Provider<AsyncValue<List<JobCardModel>>>((ref) {
  final jobs = ref.watch(jobsProvider);
  final matches = ref.watch(matchesProvider);
  final prefs = ref.watch(prefsProvider);
  if (jobs.hasError) return AsyncError(jobs.error!, StackTrace.current);
  if (matches.hasError) return AsyncError(matches.error!, StackTrace.current);
  final jobList = jobs.valueOrNull;
  final matchList = matches.valueOrNull;
  final settings = prefs.valueOrNull ?? const NotificationPrefs();
  if (jobList == null || matchList == null) return const AsyncLoading();

  final byId = {for (final j in jobList) j.id: j};
  final picks = <JobCardModel>[];
  for (final match in matchList) {
    if (match.isSeen || match.isRejected) continue;
    if (match.matchScore < settings.minMatchScore) continue;
    final job = byId[match.jobId];
    if (job == null || job.isExpiredReported) continue;
    picks.add(JobCardModel(job: job, match: match));
  }
  picks.sort((a, b) => b.match.matchScore.compareTo(a.match.matchScore));
  return AsyncData(picks.take(settings.maxJobsPerDay).toList());
});

/// Explicitly saved jobs (Saved tab).
final savedProvider = Provider<AsyncValue<List<JobCardModel>>>((ref) {
  final jobs = ref.watch(jobsProvider);
  final matches = ref.watch(matchesProvider);
  final jobList = jobs.valueOrNull;
  final matchList = matches.valueOrNull;
  if (jobList == null || matchList == null) return const AsyncLoading();
  final byId = {for (final j in jobList) j.id: j};
  final saved = <JobCardModel>[];
  for (final match in matchList) {
    if (!match.isSaved || match.isRejected) continue;
    final job = byId[match.jobId];
    if (job == null) continue;
    saved.add(JobCardModel(job: job, match: match));
  }
  saved.sort((a, b) => b.match.matchScore.compareTo(a.match.matchScore));
  return AsyncData(saved);
});

/// Applications joined with their job rows (for the tracker UI).
class ApplicationCardModel {
  const ApplicationCardModel({required this.application, required this.job});

  final Application application;
  final Job? job;

  String get title => job?.title ?? 'Untitled role';
  String get company => job?.company ?? '—';
}

final applicationCardsProvider = Provider<AsyncValue<List<ApplicationCardModel>>>((ref) {
  final apps = ref.watch(applicationsProvider);
  final jobs = ref.watch(jobsProvider);
  final appList = apps.valueOrNull;
  final jobList = jobs.valueOrNull;
  if (appList == null || jobList == null) return const AsyncLoading();
  final byId = {for (final j in jobList) j.id: j};
  return AsyncData([
    for (final app in appList)
      ApplicationCardModel(application: app, job: byId[app.jobId]),
  ]);
});

/// Live score for a job against the current profile (Job Details header).
MatchResult? liveScore(Job job, Profile? profile) =>
    profile == null ? null : scoreJob(job: job, profile: profile);
