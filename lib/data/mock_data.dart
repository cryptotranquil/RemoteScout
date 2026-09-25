import '../models/models.dart';
import 'app_store.dart';

/// Five realistic junior data-analytics mock listings (Phase 1).
///
/// They exercise every UI state the first release must handle: high/medium
/// match scores, all three location scopes, missing skills, salary present
/// and absent, and both attributed sources.
Future<void> seedMockJobs(AppStore store) async {
  if (store.allJobs.isNotEmpty) return;
  final now = DateTime.now();

  final jobs = <Job>[
    Job(
      id: 'mock-01',
      externalId: 'remotive-881201',
      source: 'remotive',
      title: 'Junior Data Analyst',
      company: 'Example Labs',
      description:
          'Entry-level Junior Data Analyst supporting the growth team. You will '
          'write SQL queries, maintain Excel and Google Sheets reports, and build '
          'Tableau dashboards. Basic statistics and data cleaning are part of the '
          'weekly routine. 0-2 years of experience. Fully remote, worldwide.',
      applyUrl: 'https://remotive.com/remote-jobs/data/junior-data-analyst-881201',
      sourceUrl: 'https://remotive.com/remote-jobs/data/junior-data-analyst-881201',
      locationText: 'Worldwide',
      locationScope: LocationScope.worldwide,
      salaryMin: 28000,
      salaryMax: 38000,
      currency: 'USD',
      employmentType: 'full_time',
      publishedAt: now.subtract(const Duration(days: 2)),
      collectedAt: now,
    ),
    Job(
      id: 'mock-02',
      externalId: 'remotive-881344',
      source: 'remotive',
      title: 'Data Analyst Intern — Analytics',
      company: 'BrightMetrics',
      description:
          'Analytics internship for a current student or recent graduate. '
          'Work with Python and SQL to clean data, support reporting, and '
          'learn dashboarding with Looker. Strong communication skills '
          'welcome. Remote, worldwide candidates considered.',
      applyUrl: 'https://remotive.com/remote-jobs/data/data-analyst-intern-881344',
      sourceUrl: 'https://remotive.com/remote-jobs/data/data-analyst-intern-881344',
      locationText: 'Worldwide',
      locationScope: LocationScope.worldwide,
      employmentType: 'internship',
      publishedAt: now.subtract(const Duration(hours: 5)),
      collectedAt: now,
    ),
    Job(
      id: 'mock-03',
      externalId: 'remoteok-1882310',
      source: 'remoteok',
      title: 'Junior BI Analyst',
      company: 'Northwind Retail',
      description:
          'Junior BI Analyst building Power BI dashboards and SQL extracts for '
          'retail operations. Excel required. Hybrid-friendly remote role open '
          'to candidates in Europe only (CET overlap expected).',
      applyUrl: 'https://remoteok.com/remote-jobs/1882310-junior-bi-analyst',
      sourceUrl: 'https://remoteok.com/remote-jobs/1882310-junior-bi-analyst',
      locationText: 'Europe (CET)',
      locationScope: LocationScope.regionRestricted,
      salaryMin: 24000,
      salaryMax: 32000,
      currency: 'EUR',
      employmentType: 'full_time',
      publishedAt: now.subtract(const Duration(days: 6)),
      collectedAt: now,
    ),
    Job(
      id: 'mock-04',
      externalId: 'remotive-880914',
      source: 'remotive',
      title: 'Reporting Analyst',
      company: 'HealthData Co',
      description:
          'Reporting Analyst producing weekly and monthly KPI reports from SQL '
          'and spreadsheet sources. Looker dashboards, data quality checks, and '
          'hypothesis testing for the research team. Entry-level friendly, '
          'worldwide remote.',
      applyUrl: 'https://remotive.com/remote-jobs/data/reporting-analyst-880914',
      sourceUrl: 'https://remotive.com/remote-jobs/data/reporting-analyst-880914',
      locationText: 'Worldwide',
      locationScope: LocationScope.worldwide,
      salaryMin: 30000,
      salaryMax: 42000,
      currency: 'USD',
      employmentType: 'contract',
      publishedAt: now.subtract(const Duration(days: 1, hours: 6)),
      collectedAt: now,
    ),
    Job(
      id: 'mock-05',
      externalId: 'remoteok-1881900',
      source: 'remoteok',
      title: 'Junior Business Analyst',
      company: 'Finlio',
      description:
          'Junior Business Analyst partnering with product on requirements, '
          'spreadsheet modelling, and SQL reporting. 1+ year of exposure to '
          'analytics preferred. US-only remote (United States).',
      applyUrl: 'https://remoteok.com/remote-jobs/1881900-junior-business-analyst',
      sourceUrl: 'https://remoteok.com/remote-jobs/1881900-junior-business-analyst',
      locationText: 'United States only',
      locationScope: LocationScope.countryRestricted,
      salaryMin: 45000,
      salaryMax: 60000,
      currency: 'USD',
      employmentType: 'full_time',
      publishedAt: now.subtract(const Duration(days: 3)),
      collectedAt: now,
    ),
  ];

  for (final job in jobs) {
    await store.addJob(job);
  }
}
