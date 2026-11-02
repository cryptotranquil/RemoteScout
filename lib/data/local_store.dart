import 'package:hive_flutter/hive_flutter.dart';

import '../core/scoring/match_scorer.dart';
import '../core/utils/dedup.dart';
import '../models/models.dart';
import 'app_store.dart';

/// Local persistence (Phase 2) built on Hive — and the offline-first cache
/// under the Phase 3 [SyncedStore].
///
/// Models are stored as JSON maps (no codegen adapters needed). Every box
/// change is exposed as a stream so Riverpod `StreamProvider`s rebuild the
/// UI automatically. The shape deliberately mirrors the Supabase schema so
/// swapping in the remote store is a straight translation (see
/// `supabase/mappers.dart`).
class LocalStore implements AppStore {
  LocalStore._(this._meta, this._profile, this._prefs, this._jobs,
      this._matches, this._applications) {
    _dedup.seed(_jobs.values.map((raw) {
      final job = Job.fromJson(_decode(raw));
      return (job.ingestKey, job.crossSourceKey);
    }));
  }

  static const String metaBoxName = 'rs_meta';
  static const String profileBoxName = 'rs_profile';
  static const String prefsBoxName = 'rs_prefs';
  static const String jobsBoxName = 'rs_jobs';
  static const String matchesBoxName = 'rs_matches';
  static const String applicationsBoxName = 'rs_applications';

  final Box<dynamic> _meta;
  final Box<dynamic> _profile;
  final Box<dynamic> _prefs;
  final Box<dynamic> _jobs;
  final Box<dynamic> _matches;
  final Box<dynamic> _applications;
  final DedupIndex _dedup = DedupIndex();

  String refreshUnavailableReason =
      'This build is using local storage; job sources were not contacted.';

  /// Opens (and migrates if needed) all boxes.
  static Future<LocalStore> open() async {
    return LocalStore._(
      await Hive.openBox<dynamic>(metaBoxName),
      await Hive.openBox<dynamic>(profileBoxName),
      await Hive.openBox<dynamic>(prefsBoxName),
      await Hive.openBox<dynamic>(jobsBoxName),
      await Hive.openBox<dynamic>(matchesBoxName),
      await Hive.openBox<dynamic>(applicationsBoxName),
    );
  }

  /// Removes demo listings left behind by earlier app versions.
  Future<void> removeBundledMockData() async {
    final mockJobIds = allJobs
        .where((job) => job.id.startsWith('mock-'))
        .map((job) => job.id)
        .toSet();
    if (mockJobIds.isEmpty) return;

    await _jobs.deleteAll(mockJobIds);

    final mockMatchIds = allMatches
        .where((match) => mockJobIds.contains(match.jobId))
        .map((match) => match.id)
        .toList();
    await _matches.deleteAll(mockMatchIds);

    final mockApplicationIds = allApplications
        .where((application) =>
            application.jobId != null && mockJobIds.contains(application.jobId))
        .map((application) => application.id)
        .toList();
    await _applications.deleteAll(mockApplicationIds);

    _dedup.clear();
    _dedup.seed(_jobs.values.map((raw) {
      final job = Job.fromJson(_decode(raw));
      return (job.ingestKey, job.crossSourceKey);
    }));
  }

  static Map<String, dynamic> _decode(dynamic raw) =>
      Map<String, dynamic>.from(raw as Map);

  // ---------------------------------------------------------------- meta

  @override
  bool get isOnboarded => _meta.get('onboarded', defaultValue: false) as bool;

  @override
  Stream<void> watchMeta() async* {
    yield null;
    yield* _meta.watch();
  }

  @override
  Future<void> setOnboarded() => _meta.put('onboarded', true);

  // -------------------------------------------------------------- profile

  @override
  Profile? get profile {
    final raw = _profile.get('me');
    return raw == null ? null : Profile.fromJson(_decode(raw));
  }

  @override
  Stream<Profile?> watchProfile() async* {
    yield profile;
    yield* _profile.watch().map((_) => profile);
  }

  @override
  Future<void> saveProfile(Profile value) async {
    await _profile.put('me', value.toJson());
    await rescore();
  }

  // ---------------------------------------------------------------- prefs

  @override
  NotificationPrefs get prefs {
    final raw = _prefs.get('settings');
    return raw == null
        ? const NotificationPrefs()
        : NotificationPrefs.fromJson(_decode(raw));
  }

  @override
  Stream<NotificationPrefs> watchPrefs() async* {
    yield prefs;
    yield* _prefs.watch().map((_) => prefs);
  }

  @override
  Future<void> savePrefs(NotificationPrefs value) =>
      _prefs.put('settings', value.toJson());

  // ----------------------------------------------------------------- jobs

  @override
  List<Job> get allJobs =>
      _jobs.values.map((raw) => Job.fromJson(_decode(raw))).toList()
        ..sort((a, b) => b.publishedAt.compareTo(a.publishedAt));

  @override
  Job? jobById(String id) {
    final raw = _jobs.get(id);
    return raw == null ? null : Job.fromJson(_decode(raw));
  }

  @override
  Stream<List<Job>> watchJobs() async* {
    yield allJobs;
    yield* _jobs.watch().map((_) => allJobs);
  }

  /// Ingests a job with deterministic dedup (both keys).
  /// Returns false when the listing is a duplicate and was discarded.
  @override
  Future<bool> addJob(Job job) async {
    if (!_dedup.tryAdd(job.ingestKey, job.crossSourceKey)) {
      // Already known by key — allow an update of the same stored row.
      if (_jobs.get(job.id) == null) return false;
    }
    await _jobs.put(job.id, job.toJson());
    return true;
  }

  @override
  Future<void> reportExpired(String jobId) async {
    final job = jobById(jobId);
    if (job == null) return;
    await _jobs.put(jobId, job.copyWith(isExpiredReported: true).toJson());
    await rescore();
  }

  // -------------------------------------------------------------- matches

  @override
  List<JobMatch> get allMatches =>
      _matches.values.map((raw) => JobMatch.fromJson(_decode(raw))).toList();

  @override
  JobMatch? matchForJob(String jobId) {
    for (final raw in _matches.values) {
      final match = JobMatch.fromJson(_decode(raw));
      if (match.jobId == jobId) return match;
    }
    return null;
  }

  @override
  Stream<List<JobMatch>> watchMatches() async* {
    yield allMatches;
    yield* _matches.watch().map((_) => allMatches);
  }

  /// Recomputes every job's match against the current profile, preserving
  /// the user's seen/saved/rejected flags.
  @override
  Future<void> rescore() async {
    final profile = this.profile;
    if (profile == null) return;
    final now = DateTime.now();
    for (final job in allJobs) {
      final existing = matchForJob(job.id);
      final result = scoreJob(job: job, profile: profile, now: now);
      final match = (existing ??
              JobMatch(
                id: 'match-${job.id}',
                userId: AppStore.userId,
                jobId: job.id,
                matchScore: 0,
                matchedSkills: const [],
                missingSkills: const [],
                matchReason: '',
                breakdown: const [],
                createdAt: now,
              ))
          .copyWith(
        matchScore: result.score,
        matchedSkills: result.matchedSkills,
        missingSkills: result.missingSkills,
        matchReason: result.matchReason,
        breakdown: result.reasons,
      );
      await _matches.put(match.id, match.toJson());
    }
  }

  @override
  Future<FeedRefreshResult> refresh() async {
    await rescore();
    return FeedRefreshResult(
      isLive: false,
      errors: [refreshUnavailableReason],
    );
  }

  @override
  Future<void> markSeen(String matchId) async {
    final raw = _matches.get(matchId);
    if (raw == null) return;
    final match = JobMatch.fromJson(_decode(raw));
    await _matches.put(matchId, match.copyWith(isSeen: true).toJson());
  }

  @override
  Future<void> saveMatch(String matchId) async {
    final raw = _matches.get(matchId);
    if (raw == null) return;
    final match = JobMatch.fromJson(_decode(raw));
    await _matches.put(
        matchId, match.copyWith(isSeen: true, isSaved: true).toJson());
    await _ensureApplication(match.jobId, ApplicationStatus.saved);
  }

  @override
  Future<void> rejectMatch(String matchId) async {
    final raw = _matches.get(matchId);
    if (raw == null) return;
    final match = JobMatch.fromJson(_decode(raw));
    await _matches.put(
        matchId,
        match
            .copyWith(isSeen: true, isSaved: false, isRejected: true)
            .toJson());

    // A never-applied application row is removed; anything further along
    // in the pipeline moves to `rejected` instead (the application happened).
    final existing = applicationForJob(match.jobId);
    if (existing != null) {
      final appliedLike = existing.status == ApplicationStatus.applied ||
          existing.status == ApplicationStatus.interview ||
          existing.status == ApplicationStatus.offer ||
          existing.status == ApplicationStatus.rejected ||
          existing.status == ApplicationStatus.closed;
      if (appliedLike) {
        await updateApplication(
            existing.copyWith(status: ApplicationStatus.rejected));
      } else {
        await deleteApplication(existing.id);
      }
    }
  }

  // --------------------------------------------------------- applications

  @override
  List<Application> get allApplications => _applications.values
      .map((raw) => Application.fromJson(_decode(raw)))
      .toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Application? applicationById(String id) {
    final raw = _applications.get(id);
    return raw == null ? null : Application.fromJson(_decode(raw));
  }

  @override
  Application? applicationForJob(String jobId) {
    for (final raw in _applications.values) {
      final app = Application.fromJson(_decode(raw));
      if (app.jobId == jobId) return app;
    }
    return null;
  }

  @override
  Stream<List<Application>> watchApplications() async* {
    yield allApplications;
    yield* _applications.watch().map((_) => allApplications);
  }

  Future<Application> _ensureApplication(
      String jobId, ApplicationStatus status) async {
    final existing = applicationForJob(jobId);
    if (existing != null) return existing;
    final now = DateTime.now();
    final app = Application(
      id: 'app-${_applications.length}-${now.microsecondsSinceEpoch}',
      userId: AppStore.userId,
      jobId: jobId,
      status: status,
      createdAt: now,
      updatedAt: now,
    );
    await _applications.put(app.id, app.toJson());
    return app;
  }

  /// "Plan to apply" (and stronger) routes a job into the tracker.
  @override
  Future<Application> trackJob(String jobId, ApplicationStatus status) async {
    final existing = applicationForJob(jobId);
    if (existing == null) return _ensureApplication(jobId, status);
    return updateApplication(existing.copyWith(status: status));
  }

  @override
  Future<Application> updateApplication(Application value) async {
    final next = value.copyWith(updatedAt: DateTime.now());
    await _applications.put(next.id, next.toJson());
    return next;
  }

  @override
  Future<Application> addManualApplication({
    required String title,
    required String company,
    required String applyUrl,
    ApplicationStatus status = ApplicationStatus.planToApply,
    String? notes,
  }) async {
    final now = DateTime.now();
    final job = Job(
      id: 'manual-${now.microsecondsSinceEpoch}',
      externalId: 'manual-${now.microsecondsSinceEpoch}',
      source: 'manual',
      title: title,
      company: company,
      description: '',
      applyUrl: applyUrl.isEmpty ? AppStore.sourceUrlFallback : applyUrl,
      sourceUrl: applyUrl.isEmpty ? AppStore.sourceUrlFallback : applyUrl,
      locationText: 'Unspecified',
      locationScope: LocationScope.worldwide,
      employmentType: 'full_time',
      publishedAt: now,
      collectedAt: now,
    );
    await addJob(job);
    final app = Application(
      id: 'app-${_applications.length}-${now.microsecondsSinceEpoch}',
      userId: AppStore.userId,
      jobId: job.id,
      status: status,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
    await _applications.put(app.id, app.toJson());
    return app;
  }

  @override
  Future<void> deleteApplication(String id) => _applications.delete(id);

  /// Applies a row pulled from the remote backend (SyncedStore).
  Future<void> putProfileRow(Profile value) =>
      _profile.put('me', value.toJson());

  Future<void> putPrefsRow(NotificationPrefs value) =>
      _prefs.put('settings', value.toJson());

  /// Upserts pulled remote rows without local dedup interference: remote ids
  /// are authoritative and were already deduped server-side.
  Future<void> putJobRow(Job job) async {
    _dedup.seed([(job.ingestKey, job.crossSourceKey)]);
    await _jobs.put(job.id, job.toJson());
  }

  Future<void> putMatchRow(JobMatch match) =>
      _matches.put(match.id, match.toJson());

  Future<void> putApplicationRow(Application application) =>
      _applications.put(application.id, application.toJson());
}
