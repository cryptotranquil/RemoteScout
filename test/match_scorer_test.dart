import 'package:flutter_test/flutter_test.dart';
import 'package:remotescout/core/scoring/match_scorer.dart';
import 'package:remotescout/models/models.dart';

Job _job({
  String title = 'Junior Data Analyst',
  String description = '',
  LocationScope scope = LocationScope.worldwide,
  DateTime? publishedAt,
}) {
  final now = DateTime(2026, 9, 25, 9);
  return Job(
    id: 't1',
    externalId: 'ext-1',
    source: 'remotive',
    title: title,
    company: 'Example Labs',
    description: description,
    applyUrl: 'https://remotive.com/remote-jobs/data/junior-data-analyst-1',
    sourceUrl: 'https://remotive.com/remote-jobs/data/junior-data-analyst-1',
    locationText: scope == LocationScope.worldwide ? 'Worldwide' : 'Europe',
    locationScope: scope,
    employmentType: 'full_time',
    publishedAt: publishedAt ?? now.subtract(const Duration(days: 2)),
    collectedAt: now,
  );
}

final _createdAt = DateTime(2026, 9, 1);

final _profile = Profile(
  id: 'u1',
  name: 'Scout',
  email: 'scout@example.com',
  skills: ['SQL', 'Excel', 'Tableau', 'Python', 'Statistics'],
  targetRoles: ['Junior Data Analyst'],
  preferredCountries: ['worldwide'],
  experienceLevel: 'junior',
  createdAt: _createdAt,
);

void main() {
  final clock = DateTime(2026, 9, 25, 9);

  test('exact weighted score for a strong junior-analyst match', () {
    final job = _job(
      description:
          'Entry-level Junior Data Analyst. Write SQL queries, maintain Excel '
          'and Google Sheets reports, build Tableau dashboards. Basic statistics '
          'and data cleaning are part of the weekly routine. 0-2 years.',
    );
    final result = scoreJob(job: job, profile: _profile, now: clock);

    // skill 23 (4 of 7 named tools) + title 25 + location 20
    // + experience 10 + freshness 4 (2 days old) = 82
    expect(result.score, 82);
    expect(result.breakdown.skill, 23);
    expect(result.breakdown.title, 25);
    expect(result.breakdown.location, 20);
    expect(result.breakdown.experience, 10);
    expect(result.breakdown.freshness, 4);
    expect(
      result.breakdown.skill +
          result.breakdown.title +
          result.breakdown.location +
          result.breakdown.experience +
          result.breakdown.freshness,
      result.score,
    );
  });

  test('every score ships with a human-readable reason', () {
    final job = _job(
      description: 'SQL and Tableau dashboards for a junior analyst.',
    );
    final result = scoreJob(job: job, profile: _profile, now: clock);

    expect(result.matchReason, isNotEmpty);
    expect(result.matchReason, contains('Matches'));
    expect(result.matchReason, contains('Worldwide eligible'));
    expect(result.matchReason, contains('Posted 2 days ago'));
    expect(result.reasons, isNotEmpty);
    expect(result.reasons.any((r) => r.contains('Worldwide')), isTrue);
    expect(result.breakdown, isNotNull);
  });

  test('location scoring: worldwide 20, region 6, country 2', () {
    MatchResult score(LocationScope scope) => scoreJob(
          job: _job(scope: scope),
          profile: _profile,
          now: clock,
        );
    expect(score(LocationScope.worldwide).breakdown.location, 20);
    expect(score(LocationScope.regionRestricted).breakdown.location, 6);
    expect(score(LocationScope.countryRestricted).breakdown.location, 2);
  });

  test('matched vs missing skills are split correctly', () {
    final job = _job(
      description: 'SQL and Power BI. Python helpful.',
    );
    final result = scoreJob(job: job, profile: _profile, now: clock);
    expect(result.matchedSkills, containsAll(['SQL', 'Python']));
    expect(result.missingSkills, contains('Power BI'));
    expect(result.matchedSkills, isNot(contains('Power BI')));
  });

  test('freshness decays in documented steps', () {
    int fresh(Duration age) => scoreJob(
          job: _job(
            publishedAt: clock.subtract(age),
            description: 'SQL role.',
          ),
          profile: _profile,
          now: clock,
        ).breakdown.freshness;

    expect(fresh(const Duration(hours: 12)), 5);
    expect(fresh(const Duration(days: 2)), 4);
    expect(fresh(const Duration(days: 5)), 3);
    expect(fresh(const Duration(days: 10)), 2);
    expect(fresh(const Duration(days: 20)), 1);
    expect(fresh(const Duration(days: 45)), 0);
  });

  test('senior-only listings score zero on experience', () {
    final job = _job(
      title: 'Senior Data Analyst',
      description: 'Senior role. 5+ years required. Lead the team.',
    );
    final result = scoreJob(job: job, profile: _profile, now: clock);
    expect(result.breakdown.experience, 0);
  });

  test('score is always within 0–100', () {
    final worst = scoreJob(
      job: _job(
        title: 'Principal Surgeon',
        description: 'Lead staff. 10+ years.',
        scope: LocationScope.countryRestricted,
        publishedAt: clock.subtract(const Duration(days: 90)),
      ),
      profile: _profile,
      now: clock,
    );
    expect(worst.score, inInclusiveRange(0, 100));
  });

  test('canonicalSkill maps aliases to vocabulary', () {
    expect(canonicalSkill('powerbi'), 'Power BI');
    expect(canonicalSkill('postgres'), 'SQL');
    expect(canonicalSkill('SQL'), 'SQL');
    expect(canonicalSkill('my custom thing'), 'my custom thing');
  });
}
