import 'package:flutter_test/flutter_test.dart';
import 'package:remotescout/models/models.dart';

void main() {
  test('Profile JSON round-trip', () {
    final profile = Profile(
      id: 'u1',
      name: 'Scout',
      email: 'scout@example.com',
      skills: ['SQL', 'Excel'],
      targetRoles: ['Junior Data Analyst'],
      minimumSalary: 24000,
      preferredCountries: ['worldwide'],
      preferredTimezones: ['UTC+2'],
      experienceLevel: 'junior',
      cvUrl: 'https://example.com/cv.pdf',
      portfolioUrl: 'https://example.com',
      createdAt: DateTime(2026, 9, 1, 8),
    );
    final copy = Profile.fromJson(profile.toJson());
    expect(copy.name, profile.name);
    expect(copy.skills, profile.skills);
    expect(copy.targetRoles, profile.targetRoles);
    expect(copy.minimumSalary, 24000);
    expect(copy.preferredCountries, ['worldwide']);
    expect(copy.createdAt, profile.createdAt);
    expect(copy.cvUrl, profile.cvUrl);
  });

  test('Job JSON round-trip preserves wire enums and money', () {
    final job = Job(
      id: 'j1',
      externalId: 'ext-1',
      source: 'remotive',
      title: 'Junior Data Analyst',
      company: 'Example Labs',
      description: 'desc',
      applyUrl: 'https://example.com/apply',
      sourceUrl: 'https://example.com/listing',
      locationText: 'Worldwide',
      locationScope: LocationScope.worldwide,
      salaryMin: 28000,
      salaryMax: 38000,
      currency: 'USD',
      employmentType: 'full_time',
      publishedAt: DateTime(2026, 9, 23),
      collectedAt: DateTime(2026, 9, 25),
    );
    final copy = Job.fromJson(job.toJson());
    expect(copy.locationScope, LocationScope.worldwide);
    expect(copy.locationScope.wire, 'worldwide');
    expect(copy.salaryMin, 28000);
    expect(copy.ingestKey, 'remotive|ext-1');
    expect(copy.salaryLabel, 'USD 28k–38k');
  });

  test('status enum wire names match the backend schema', () {
    expect(ApplicationStatus.applied.wire, 'applied');
    expect(ApplicationStatus.planToApply.wire, 'plan_to_apply');
    expect(ApplicationStatus.fromWire('interview'), ApplicationStatus.interview);
    expect(ApplicationStatus.fromWire('nonsense'), ApplicationStatus.neu);
  });

  test('JobMatch and Application round-trip', () {
    final match = JobMatch(
      id: 'm1',
      userId: 'u1',
      jobId: 'j1',
      matchScore: 88,
      matchedSkills: ['SQL'],
      missingSkills: ['Looker'],
      matchReason: 'Matches SQL · Worldwide eligible',
      breakdown: const ['✓ Matches SQL'],
      isSeen: true,
      createdAt: DateTime(2026, 9, 25),
    );
    final matchCopy = JobMatch.fromJson(match.toJson());
    expect(matchCopy.matchScore, 88);
    expect(matchCopy.isSeen, isTrue);
    expect(matchCopy.breakdown, ['✓ Matches SQL']);

    final app = Application(
      id: 'a1',
      userId: 'u1',
      jobId: 'j1',
      status: ApplicationStatus.applied,
      appliedAt: DateTime(2026, 9, 26),
      followUpAt: DateTime(2026, 10, 3),
      cvVersion: 'v2',
      createdAt: DateTime(2026, 9, 25),
      updatedAt: DateTime(2026, 9, 26),
    );
    final appCopy = Application.fromJson(app.toJson());
    expect(appCopy.status, ApplicationStatus.applied);
    expect(appCopy.cvVersion, 'v2');
    expect(appCopy.followUpAt, DateTime(2026, 10, 3));
  });

  test('NotificationPrefs defaults are digest-safe', () {
    const prefs = NotificationPrefs();
    expect(prefs.digestTime, '08:00');
    expect(prefs.minMatchScore, 70);
    expect(prefs.maxJobsPerDay, 5);
    expect(prefs.weekendEnabled, isFalse);
  });
}
