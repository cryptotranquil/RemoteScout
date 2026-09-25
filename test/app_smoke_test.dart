import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:remotescout/app.dart';
import 'package:remotescout/data/app_store.dart';
import 'package:remotescout/data/local_store.dart';
import 'package:remotescout/data/mock_data.dart';
import 'package:remotescout/data/providers.dart';
import 'package:remotescout/models/models.dart';

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

    expect(find.text('RemoteScout'), findsOneWidget);
    expect(find.text('Get started'), findsOneWidget);

    await tester.tap(find.text('Get started'));
    await _settle(tester);
    expect(find.text('Who are you scouting as?'), findsOneWidget);
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

    expect(find.text("Today's best opportunities"), findsOneWidget);
    // High-match mock (Junior Data Analyst @ Example Labs) is recommended.
    expect(find.text('Junior Data Analyst'), findsWidgets);
    expect(find.text('Example Labs'), findsWidgets);
    // Low-match mocks are held back — this is a shortlist, not a feed.
    expect(find.text('Junior BI Analyst'), findsNothing);
  });
}
