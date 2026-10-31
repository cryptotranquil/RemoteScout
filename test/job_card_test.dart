import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remotescout/features/discover/job_card.dart';
import 'package:remotescout/data/providers.dart';
import 'package:remotescout/models/models.dart';

void main() {
  final job = Job(
    id: 'mock-01',
    externalId: 'ext-1',
    source: 'remotive',
    title: 'Junior Data Analyst',
    company: 'Example Labs',
    description: 'SQL and Excel.',
    applyUrl: 'https://remotive.com/remote-jobs/data/analyst-1',
    sourceUrl: 'https://remotive.com/remote-jobs/data/analyst-1',
    locationText: 'Worldwide',
    locationScope: LocationScope.worldwide,
    salaryMin: 28000,
    salaryMax: 38000,
    currency: 'USD',
    employmentType: 'full_time',
    publishedAt: DateTime.now().subtract(const Duration(days: 2)),
    collectedAt: DateTime.now(),
  );

  final match = JobMatch(
    id: 'm1',
    userId: 'u1',
    jobId: job.id,
    matchScore: 88,
    matchedSkills: const ['SQL', 'Excel'],
    missingSkills: const [],
    matchReason: 'Matches SQL and Excel · Worldwide eligible',
    breakdown: const ['✓ Matches SQL, Excel'],
    createdAt: DateTime.now(),
  );

  testWidgets('job card shows title, company, score, source and location',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: JobCard(model: JobCardModel(job: job, match: match)),
      ),
    ));

    expect(find.text('Junior Data Analyst'), findsOneWidget);
    expect(find.text('Example Labs'), findsOneWidget);
    expect(find.text('88% Match • Strong Fit'), findsOneWidget);
    expect(find.text('Worldwide'), findsOneWidget);
    expect(find.text('via Remotive'), findsOneWidget);
    expect(find.text('\$28,000 – \$38,000 USD'), findsOneWidget);
  });

  testWidgets('Save and Reject buttons fire their callbacks',
      (tester) async {
    var saved = 0;
    var rejected = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: JobCard(
          model: JobCardModel(job: job, match: match),
          onSave: () => saved++,
          onReject: () => rejected++,
        ),
      ),
    ));

    await tester.tap(find.byKey(const ValueKey('save-mock-01')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('reject-mock-01')));
    await tester.pump();

    expect(saved, 1);
    expect(rejected, 1);
  });
}
