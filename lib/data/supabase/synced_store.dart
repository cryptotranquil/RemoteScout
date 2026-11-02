import 'dart:async';
import 'dart:developer' as developer;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';
import '../app_store.dart';
import '../local_store.dart';
import 'mappers.dart';

/// Phase 3 store: Supabase as remote truth, [LocalStore] as the
/// offline-first cache the UI reads from (TRD §7 — feed renders from local
/// cache well under 1s; offline data stays viewable).
///
/// Every mutation updates the local cache first (instant UI) and then pushes
/// to Postgres under RLS; pulls run at startup, after refresh, and after
/// mutations to converge. Server-side fetch/normalize/dedup/score happens in
/// the Edge Functions — the app never calls job-source APIs.
class SyncedStore implements AppStore {
  SyncedStore(this.local, this._client);

  final LocalStore local;
  final SupabaseClient _client;

  String? get _uid => _client.auth.currentUser?.id;

  void _logError(String op, Object e) {
    developer.log('SyncedStore.$op failed: $e', name: 'remotescout.sync');
  }

  // ------------------------------------------------------------------ sync

  /// Pulls the user's rows into the local cache (idempotent).
  Future<void> initialSync() async {
    await _pullProfile();
    await _pullJobs();
    await _pullMatches();
    await _pullApplications();
  }

  /// Background convergence after a mutation — never throws.
  Future<void> _pullQuietly() async {
    try {
      await initialSync();
    } catch (e) {
      _logError('pull', e);
    }
  }

  Future<void> _pullProfile() async {
    final uid = _uid;
    if (uid == null) return;
    final row =
        await _client.from('profiles').select().eq('id', uid).maybeSingle();
    if (row == null) return;
    await local.putProfileRow(profileFromRow(row));
    await local.putPrefsRow(prefsFromRow(row));
  }

  Future<void> _pullJobs() async {
    final rows = await _client.from('jobs').select().order('published_at');
    for (final row in rows) {
      final job = jobFromRow(row);
      await local.putJobRow(job);
    }
  }

  Future<void> _pullMatches() async {
    final uid = _uid;
    if (uid == null) return;
    final rows = await _client.from('job_matches').select().eq('user_id', uid);
    for (final row in rows) {
      await local.putMatchRow(matchFromRow(row));
    }
  }

  Future<void> _pullApplications() async {
    final uid = _uid;
    if (uid == null) return;
    final rows = await _client.from('applications').select().eq('user_id', uid);
    for (final row in rows) {
      await local.putApplicationRow(applicationFromRow(row));
    }
  }

  /// Invokes a backend worker Edge Function and returns any reported errors.
  Future<List<String>> _invokeWorker(String name) async {
    try {
      final response = await _client.functions.invoke(name);
      final data = response.data;
      if (name == 'fetch-jobs' && data is Map && data['errors'] is List) {
        return (data['errors'] as List).whereType<String>().toList();
      }
    } catch (e) {
      _logError('invoke:$name', e);
      return ['$name worker request failed'];
    }
    return const [];
  }

  /// Pushes a match-flag update (is_seen / is_saved / is_rejected).
  Future<void> _pushMatchFlags(JobMatch match) async {
    try {
      await _client.from('job_matches').upsert(
            matchToRow(match),
            onConflict: 'user_id,job_id',
          );
    } catch (e) {
      _logError('pushMatch', e);
    }
  }

  JobMatch? _matchById(String matchId) {
    for (final m in local.allMatches) {
      if (m.id == matchId) return m;
    }
    return null;
  }

  // ------------------------------------------------------------------ meta

  @override
  bool get isOnboarded => local.isOnboarded;

  @override
  Stream<void> watchMeta() => local.watchMeta();

  @override
  Future<void> setOnboarded() => local.setOnboarded();

  // -------------------------------------------------------------- profile

  @override
  Profile? get profile => local.profile;

  @override
  Stream<Profile?> watchProfile() => local.watchProfile();

  @override
  Future<void> saveProfile(Profile value) async {
    final uid = _uid;
    final toStore =
        uid == null ? value : Profile.fromJson({...value.toJson(), 'id': uid});
    await local.saveProfile(toStore); // triggers local rescore
    try {
      await _client.from('profiles').upsert(profileToRow(toStore, local.prefs));
      // Server-side re-score against the new profile (fire and forget).
      unawaited(_invokeWorker('score-jobs'));
      unawaited(_pullQuietly());
    } catch (e) {
      _logError('saveProfile', e);
    }
  }

  // ---------------------------------------------------------------- prefs

  @override
  NotificationPrefs get prefs => local.prefs;

  @override
  Stream<NotificationPrefs> watchPrefs() => local.watchPrefs();

  @override
  Future<void> savePrefs(NotificationPrefs value) async {
    await local.savePrefs(value);
    final p = local.profile;
    if (p != null) {
      try {
        await _client.from('profiles').upsert(profileToRow(p, value));
      } catch (e) {
        _logError('savePrefs', e);
      }
    }
  }

  // ----------------------------------------------------------------- jobs

  @override
  List<Job> get allJobs => local.allJobs;

  @override
  Job? jobById(String id) => local.jobById(id);

  @override
  Stream<List<Job>> watchJobs() => local.watchJobs();

  @override
  Future<bool> addJob(Job job) => local.addJob(job);

  @override
  Future<void> reportExpired(String jobId) async {
    await local.reportExpired(jobId);
    try {
      await _client
          .rpc<void>('report_expired_job', params: {'p_job_id': jobId});
    } catch (e) {
      _logError('reportExpired', e);
    }
  }

  // -------------------------------------------------------------- matches

  @override
  List<JobMatch> get allMatches => local.allMatches;

  @override
  JobMatch? matchForJob(String jobId) => local.matchForJob(jobId);

  @override
  Stream<List<JobMatch>> watchMatches() => local.watchMatches();

  @override
  Future<void> rescore() => local.rescore();

  @override
  Future<List<String>> refresh() async {
    // Ask the worker for a fresh fetch + score, then converge on the result.
    final errors = await _invokeWorker('fetch-jobs');
    errors.addAll(await _invokeWorker('score-jobs'));
    await _pullQuietly();
    await local.rescore();
    return errors;
  }

  @override
  Future<void> markSeen(String matchId) async {
    await local.markSeen(matchId);
    final match = _matchById(matchId);
    if (match != null) await _pushMatchFlags(match);
  }

  @override
  Future<void> saveMatch(String matchId) async {
    await local.saveMatch(matchId);
    final match = _matchById(matchId);
    if (match != null) {
      await _pushMatchFlags(match);
      final app = local.applicationForJob(match.jobId);
      if (app != null) await _pushApplication(app);
      unawaited(_pullQuietly());
    }
  }

  @override
  Future<void> rejectMatch(String matchId) async {
    final match = _matchById(matchId);
    final previousApp =
        match == null ? null : local.applicationForJob(match.jobId);
    await local.rejectMatch(matchId);
    if (match != null) {
      await _pushMatchFlags(local.matchForJob(match.jobId) ?? match);
      if (previousApp != null) {
        final now = local.applicationById(previousApp.id);
        if (now == null) {
          try {
            await _client
                .from('applications')
                .delete()
                .eq('id', previousApp.id);
          } catch (e) {
            _logError('deleteApplication', e);
          }
        } else {
          await _pushApplication(now);
        }
      }
      unawaited(_pullQuietly());
    }
  }

  // --------------------------------------------------------- applications

  @override
  List<Application> get allApplications => local.allApplications;

  @override
  Application? applicationById(String id) => local.applicationById(id);

  @override
  Application? applicationForJob(String jobId) =>
      local.applicationForJob(jobId);

  @override
  Stream<List<Application>> watchApplications() => local.watchApplications();

  @override
  Future<Application> trackJob(String jobId, ApplicationStatus status) async {
    final app = await local.trackJob(jobId, status);
    await _pushApplication(app);
    unawaited(_pullQuietly());
    return app;
  }

  @override
  Future<Application> updateApplication(Application value) async {
    final app = await local.updateApplication(value);
    await _pushApplication(app);
    unawaited(_pullQuietly());
    return app;
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
    await local.addJob(job);
    try {
      // RLS allows authenticated inserts only with source = 'manual'.
      await _client.from('jobs').upsert(jobToRow(job));
    } catch (e) {
      _logError('manualJob', e);
    }

    final app = Application(
      id: 'app-${local.allApplications.length}-${now.microsecondsSinceEpoch}',
      userId: _uid ?? AppStore.userId,
      jobId: job.id,
      status: status,
      notes: notes,
      createdAt: now,
      updatedAt: now,
    );
    await local.putApplicationRow(app);
    await _pushApplication(app);
    unawaited(_pullQuietly());
    return app;
  }

  @override
  Future<void> deleteApplication(String id) async {
    await local.deleteApplication(id);
    try {
      await _client.from('applications').delete().eq('id', id);
    } catch (e) {
      _logError('deleteApplication', e);
    }
    unawaited(_pullQuietly());
  }

  Future<void> _pushApplication(Application app) async {
    try {
      await _client.from('applications').upsert(applicationToRow(app));
    } catch (e) {
      _logError('pushApplication', e);
    }
  }
}

/// Signs in anonymously so RLS (`user_id = auth.uid()`) has a subject.
/// Falls back to unauthenticated operation (local cache still works).
Future<void> ensureSignedIn(SupabaseClient client) async {
  if (client.auth.currentSession != null) return;
  try {
    await client.auth.signInAnonymously();
  } catch (_) {
    // Anonymous sign-in may be disabled — degrade to local-only writes.
  }
}
