import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:remotescout/app.dart';
import 'package:remotescout/data/app_store.dart';
import 'package:remotescout/data/local_store.dart';
import 'package:remotescout/data/providers.dart';
import 'package:remotescout/features/onboarding/welcome_screen.dart';
import 'package:remotescout/models/models.dart';
import 'fixtures/mock_data.dart';

/// End-to-end smoke: real store + mock jobs + real router/theme/providers.
///
/// Uses bounded settling so a forever-animating widget (e.g. a loading
/// spinner) fails fast with a useful error instead of hanging the suite.
Future<void> _settle(WidgetTester tester) async {
  await tester.pumpAndSettle(
    const Duration(milliseconds: 60),
    EnginePhase.sendSemanticsUpdate,
    const Duration(seconds: 8),
  );
}

void main() {
  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;
    final dir = await Directory.systemTemp.createTemp('rs_smoke');
    Hive.init(dir.path);
    final store = await LocalStore.open();
    await seedMockJobs(store);
    await store.saveProfile(
      Profile(
        id: AppStore.userId,
        name: 'Scout',
        email: 'scout@example.com',
        skills: const ['SQL', 'Excel', 'Tableau', 'Python', 'Statistics'],
        targetRoles: const ['Junior Data Analyst'],
        preferredCountries: const ['worldwide'],
        experienceLevel: 'junior',
        createdAt: DateTime(2026, 9, 1),
      ),
    );
    await store.rescore();
    appStore = store;
  });

  testWidgets('first run lands on the welcome screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RemoteScoutApp()));
    await _settle(tester);

    expect(find.text('JobRadar'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await _settle(tester);
    expect(find.text('Who are you scouting as?'), findsOneWidget);
  });

  testWidgets('welcome content scrolls on a constrained viewport',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(234, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(home: WelcomeScreen()),
    );
    await tester.pump();

    expect(find.text('JobRadar'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(find.text('Get started'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('onboarded users land on Discover with scored mock jobs',
      (tester) async {
    // Hive writes are real async — outside the FakeAsync test zone.
    await tester.runAsync(() => appStore.setOnboarded());
    await tester.pumpWidget(const ProviderScope(child: RemoteScoutApp()));
    // Streams need a few frames to deliver; bounded pumps, no settle loop.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(find.text("Today's Recommendations"), findsOneWidget);
    // High-match mock (Junior Data Analyst @ Example Labs) is recommended.
    expect(find.text('Junior Data Analyst'), findsWidgets);
    expect(find.text('Example Labs'), findsWidgets);
    // Low-match mocks are held back — this is a shortlist, not a feed.
    expect(find.text('Junior BI Analyst'), findsNothing);
  });

  testWidgets('bottom navigation reaches every tab', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: RemoteScoutApp()));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    await tester.tap(find.text('Saved').last);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.text('Saved jobs'), findsOneWidget);

    await tester.tap(find.text('Applications').last);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.text('Tracker'), findsOneWidget);

    await tester.tap(find.text('Profile').last);
    for (var i = 0; i < 4; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
    expect(find.text('Scout preferences'), findsOneWidget);
  });

  testWidgets('saved tab stays stable on a narrow phone width', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.runAsync(() => appStore.setOnboarded());
    await tester.pumpWidget(const ProviderScope(child: RemoteScoutApp()));
    for (var i = 0; i < 8; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    await tester.tap(find.text('Saved').last);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    expect(find.text('Saved jobs'), findsOneWidget);
    expect(find.text('Batch actions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('job details render HTML descriptions', (tester) async {
    final original = appStore.jobById('mock-01')!;
    final htmlJob = Job(
      id: original.id,
      externalId: original.externalId,
      source: original.source,
      title: original.title,
      company: original.company,
      description: '<h2>Responsibilities</h2>'
          '<p>Build <strong>useful</strong> reports.</p>'
          '<ul><li>Analyze data</li></ul>',
      applyUrl: original.applyUrl,
      sourceUrl: original.sourceUrl,
      locationText: original.locationText,
      locationScope: original.locationScope,
      salaryMin: original.salaryMin,
      salaryMax: original.salaryMax,
      currency: original.currency,
      employmentType: original.employmentType,
      publishedAt: original.publishedAt,
      collectedAt: original.collectedAt,
      expiresAt: original.expiresAt,
      isExpiredReported: original.isExpiredReported,
    );
    await tester.runAsync(() async {
      await appStore.addJob(htmlJob);
      await appStore.setOnboarded();
    });
    addTearDown(() async {
      await tester.runAsync(() => appStore.addJob(original));
    });

    await tester.pumpWidget(const ProviderScope(child: RemoteScoutApp()));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    final detailsButton = find.byKey(const ValueKey('open-mock-01'));
    await tester.ensureVisible(detailsButton);
    await tester.tap(detailsButton);
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }

    await tester.scrollUntilVisible(
      find.text('About the listing'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.text('Responsibilities', findRichText: true), findsOneWidget);
    expect(
      find.text('Build useful reports.', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Analyze data', findRichText: true), findsOneWidget);
    expect(find.text('<h2>Responsibilities</h2>'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
