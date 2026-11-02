import '../models/models.dart';

class FeedRefreshResult {
  const FeedRefreshResult({
    required this.isLive,
    this.fetched = 0,
    this.inserted = 0,
    this.duplicatesDiscarded = 0,
    this.storedJobs = 0,
    this.visibleJobs = 0,
    this.errors = const [],
  });

  final bool isLive;
  final int fetched;
  final int inserted;
  final int duplicatesDiscarded;
  final int storedJobs;
  final int visibleJobs;
  final List<String> errors;
}

/// The app's storage surface (Phase 2 local / Phase 3 Supabase both conform).
///
/// Screens and providers depend only on this interface, so wiring the live
/// backend is a matter of constructing a [SyncedStore]-style implementation
/// in `main()` — no UI change required.
abstract class AppStore {
  /// User id used by the single-user local build. The Supabase build rewrites
  /// this to `auth.uid()` at the repository boundary (RLS: `id = auth.uid()`).
  static const String userId = 'local-user';

  static const String sourceUrlFallback = 'https://example.com/manual-entry';

  // ---------------------------------------------------------------- meta

  bool get isOnboarded;

  Stream<void> watchMeta();

  Future<void> setOnboarded();

  // -------------------------------------------------------------- profile

  Profile? get profile;

  Stream<Profile?> watchProfile();

  Future<void> saveProfile(Profile value);

  // ---------------------------------------------------------------- prefs

  NotificationPrefs get prefs;

  Stream<NotificationPrefs> watchPrefs();

  Future<void> savePrefs(NotificationPrefs value);

  // ----------------------------------------------------------------- jobs

  List<Job> get allJobs;

  Job? jobById(String id);

  Stream<List<Job>> watchJobs();

  /// Ingests a job with deterministic dedup. False when discarded as duplicate.
  Future<bool> addJob(Job job);

  Future<void> reportExpired(String jobId);

  // -------------------------------------------------------------- matches

  List<JobMatch> get allMatches;

  JobMatch? matchForJob(String jobId);

  Stream<List<JobMatch>> watchMatches();

  /// Re-scores every job against the current profile (local rule engine).
  Future<void> rescore();

  /// Refresh pipeline: local re-score; live builds also re-pull from the
  /// backend worker (fetch-jobs / score-jobs).
  Future<FeedRefreshResult> refresh();

  Future<void> markSeen(String matchId);

  Future<void> saveMatch(String matchId);

  Future<void> rejectMatch(String matchId);

  // --------------------------------------------------------- applications

  List<Application> get allApplications;

  Application? applicationById(String id);

  Application? applicationForJob(String jobId);

  Stream<List<Application>> watchApplications();

  Future<Application> trackJob(String jobId, ApplicationStatus status);

  Future<Application> updateApplication(Application value);

  Future<Application> addManualApplication({
    required String title,
    required String company,
    required String applyUrl,
    ApplicationStatus status = ApplicationStatus.planToApply,
    String? notes,
  });

  Future<void> deleteApplication(String id);
}
