import 'package:flutter_test/flutter_test.dart';
import 'package:remotescout/data/supabase/mappers.dart';
import 'package:remotescout/models/models.dart';

/// Contract tests: row ↔ model mapping must match backend/supabase/schema.sql
/// (and the Edge Function payloads) exactly — Phase 3's straight translation.
void main() {
  final published = DateTime.utc(2026, 9, 23, 8);
  final collected = DateTime.utc(2026, 9, 25, 8);

  Map<String, dynamic> jobRow() => {
        'id': '8b1c2f70-0000-4000-8000-000000000001',
        'external_id': 'remotive-881201',
        'source': 'remotive',
        'title': 'Junior Data Analyst',
        'company': 'Example Labs',
        'description': 'SQL and Excel.',
        'apply_url':
            'https://remotive.com/remote-jobs/data/junior-data-analyst-881201',
        'source_url':
            'https://remotive.com/remote-jobs/data/junior-data-analyst-881201',
        'location_text': 'Worldwide',
        'location_scope': 'worldwide',
        'salary_min': 28000,
        'salary_max': 38000,
        'currency': 'USD',
        'employment_type': 'full_time',
        'published_at': published.toIso8601String(),
        'collected_at': collected.toIso8601String(),
        'expires_at': null,
        'is_expired_reported': false,
      };

  test('job rows map with wire-accurate enums and money', () {
    final job = jobFromRow(jobRow());
    expect(job.locationScope, LocationScope.worldwide);
    expect(job.salaryMin, 28000);
    expect(job.publishedAt, published);
    expect(job.ingestKey, 'remotive|remotive-881201');
    // Apply and source URLs stay distinct fields (attribution compliance).
    expect(job.applyUrl, job.sourceUrl);
  });

  test('job manual insert payload keeps source = manual for RLS', () {
    final job = Job(
      id: 'manual-1',
      externalId: 'manual-1',
      source: 'manual',
      title: 'Ops Analyst',
      company: 'Acme',
      description: '',
      applyUrl: 'https://example.com/apply',
      sourceUrl: 'https://example.com/apply',
      locationText: 'Unspecified',
      locationScope: LocationScope.worldwide,
      employmentType: 'full_time',
      publishedAt: published,
      collectedAt: collected,
    );
    final row = jobToRow(job);
    expect(row['source'], 'manual');
    expect(row['location_scope'], 'worldwide');
  });

  test('match rows split summary from the why-matched checklist', () {
    final row = {
      'id': 'm1',
      'user_id': 'u1',
      'job_id': 'j1',
      'match_score': 82,
      'matched_skills': ['SQL', 'Excel'],
      'missing_skills': ['Looker'],
      'match_reason':
          'Matches SQL and Excel · Worldwide eligible · Posted 2 days ago\n'
              '\n'
              '✓ Matches SQL, Excel\n'
              '✓ Junior-friendly\n'
              '— Region-restricted (Europe)\n'
              '✓ Posted 2 days ago',
      'is_seen': true,
      'is_saved': false,
      'is_rejected': false,
      'created_at': collected.toIso8601String(),
    };
    final match = matchFromRow(row);
    expect(match.matchScore, 82);
    expect(match.matchReason,
        'Matches SQL and Excel · Worldwide eligible · Posted 2 days ago');
    expect(match.breakdown, [
      '✓ Matches SQL, Excel',
      '✓ Junior-friendly',
      '— Region-restricted (Europe)',
      '✓ Posted 2 days ago',
    ]);
    expect(match.isSeen, isTrue);
  });

  test('match payload embeds the checklist in match_reason (no breakdown col)',
      () {
    final match = JobMatch(
      id: 'm1',
      userId: 'u1',
      jobId: 'j1',
      matchScore: 82,
      matchedSkills: const ['SQL'],
      missingSkills: const [],
      matchReason: 'Matches SQL · Worldwide eligible',
      breakdown: const ['✓ Matches SQL', '✓ Worldwide eligible'],
      isSaved: true,
      createdAt: collected,
    );
    final row = matchToRow(match);
    expect(row.containsKey('breakdown'), isFalse);
    expect(row['match_reason'],
        'Matches SQL · Worldwide eligible\n\n✓ Matches SQL\n✓ Worldwide eligible');
    expect(row['is_saved'], isTrue);
    expect(row['match_score'], 82);
  });

  test('profile rows carry notification_prefs JSONB', () {
    const prefs = NotificationPrefs(
      digestTime: '07:30',
      timeZone: 'America/Los_Angeles',
      minMatchScore: 75,
      maxJobsPerDay: 3,
      weekendEnabled: true,
    );
    final profile = Profile(
      id: 'auth-uid-1',
      name: 'Scout',
      email: 's@example.com',
      skills: const ['SQL'],
      targetRoles: const ['Junior Data Analyst'],
      preferredCountries: const ['worldwide'],
      experienceLevel: 'junior',
      createdAt: DateTime.utc(2026, 9, 1),
    );

    final row = profileToRow(profile, prefs);
    expect(row['id'], 'auth-uid-1');
    expect(row['preferred_countries'], ['worldwide']);
    expect(row['notification_prefs'], prefs.toJson());

    // …and back out of a PostgREST select().
    final merged = {
      ...row,
      'minimum_salary': null,
      'preferred_timezones': <String>[],
      'cv_url': null,
      'portfolio_url': null,
    };
    expect(profileFromRow(merged).name, 'Scout');
    expect(prefsFromRow(merged).digestTime, '07:30');
    expect(prefsFromRow(merged).timeZone, 'America/Los_Angeles');
    expect(prefsFromRow(merged).weekendEnabled, isTrue);
  });

  test('application rows round-trip status wire names', () {
    final app = Application(
      id: 'a1',
      userId: 'u1',
      jobId: 'j1',
      status: ApplicationStatus.planToApply,
      followUpAt: DateTime.utc(2026, 10, 3),
      createdAt: collected,
      updatedAt: collected,
    );
    final row = applicationToRow(app);
    expect(row['status'], 'plan_to_apply');
    final back = applicationFromRow({
      ...row,
      'applied_at': null,
      'cv_version': null,
      'cover_letter': null,
      'notes': null
    });
    expect(back.status, ApplicationStatus.planToApply);
    expect(back.followUpAt, DateTime.utc(2026, 10, 3));
  });
}
