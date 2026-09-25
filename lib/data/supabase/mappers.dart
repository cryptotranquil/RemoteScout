import '../../models/models.dart';

/// Pure row ↔ model mappers for the Supabase tables (05_Backend_Schema.md).
///
/// Kept free of any client/network types so the SQL contract is unit-testable
/// (`test/mappers_test.dart`). Column names match `Profile/Job/JobMatch/
/// Application.toJson` 1:1, with two documented bridges:
///  - `job_matches.breakdown` exists only locally; the backend embeds the
///    "Why this matched" checklist as extra lines in `match_reason`.
///  - `profiles.notification_prefs` is a JSONB column (documented deviation).
Map<String, dynamic> _row(Map<dynamic, dynamic> row) =>
    Map<String, dynamic>.from(row);

Job jobFromRow(Map<dynamic, dynamic> row) => Job.fromJson(_row(row));

Map<String, dynamic> jobToRow(Job job) => job.toJson();

Profile profileFromRow(Map<dynamic, dynamic> row) => Profile.fromJson(_row(row));

/// Row payload for upsert into `profiles` (includes the prefs JSONB).
Map<String, dynamic> profileToRow(Profile profile, NotificationPrefs prefs) =>
    {...profile.toJson(), 'notification_prefs': prefs.toJson()};

NotificationPrefs prefsFromRow(Map<dynamic, dynamic> row) {
  final raw = row['notification_prefs'];
  if (raw is Map) return NotificationPrefs.fromJson(_row(raw));
  return const NotificationPrefs();
}

JobMatch matchFromRow(Map<dynamic, dynamic> row) {
  final map = _row(row);
  final reason = (map['match_reason'] as String?) ?? '';
  final lines = reason.split('\n');
  final summary = lines.isEmpty ? '' : lines.first;
  final breakdown = lines
      .skip(1)
      .map((l) => l.trim())
      .where((l) => l.startsWith('✓') || l.startsWith('—') || l.startsWith('- '))
      .toList();
  return JobMatch(
    id: map['id'] as String,
    userId: map['user_id'] as String,
    jobId: map['job_id'] as String,
    matchScore: (map['match_score'] as num).toInt(),
    matchedSkills: _strings(map['matched_skills']),
    missingSkills: _strings(map['missing_skills']),
    matchReason: summary,
    breakdown: breakdown,
    isSeen: map['is_seen'] as bool? ?? false,
    isSaved: map['is_saved'] as bool? ?? false,
    isRejected: map['is_rejected'] as bool? ?? false,
    createdAt: DateTime.parse(map['created_at'] as String),
  );
}

/// Row payload for `job_matches`: the checklist rides inside `match_reason`.
Map<String, dynamic> matchToRow(JobMatch match) {
  final json = match.toJson();
  json['match_reason'] = [
    match.matchReason,
    if (match.breakdown.isNotEmpty) '',
    ...match.breakdown,
  ].join('\n');
  json.remove('breakdown');
  return json;
}

Application applicationFromRow(Map<dynamic, dynamic> row) =>
    Application.fromJson(_row(row));

Map<String, dynamic> applicationToRow(Application application) =>
    application.toJson();

List<String> _strings(dynamic value) =>
    value is List ? value.map((e) => e.toString()).toList() : <String>[];
