import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remotescout/core/ui/scout_ui.dart';

void main() {
  testWidgets('reports zero eligible jobs instead of success', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showFeedRefreshFeedback(
                context,
                isLive: true,
                fetched: 0,
                inserted: 0,
                duplicatesDiscarded: 0,
                storedJobs: 0,
                visibleJobs: 0,
                errors: const [],
              ),
              child: const Text('Refresh'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Refresh'));
    await tester.pump();

    expect(find.text('Supabase returned 0 eligible jobs.'), findsOneWidget);
  });

  testWidgets('shows local-only startup failures to the user', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showFeedRefreshFeedback(
                context,
                isLive: false,
                fetched: 0,
                inserted: 0,
                duplicatesDiscarded: 0,
                storedJobs: 0,
                visibleJobs: 0,
                errors: const [
                  'This APK was built without Supabase configuration.',
                ],
              ),
              child: const Text('Refresh'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Refresh'));
    await tester.pump();

    expect(find.text('Job sources were not contacted.'), findsOneWidget);
    expect(find.text('Details'), findsOneWidget);
  });

  testWidgets('reports when Supabase jobs are hidden from the app',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showFeedRefreshFeedback(
                context,
                isLive: true,
                fetched: 90,
                inserted: 0,
                duplicatesDiscarded: 90,
                storedJobs: 90,
                visibleJobs: 0,
                errors: const [],
              ),
              child: const Text('Refresh'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Refresh'));
    await tester.pump();

    expect(
      find.text(
        'Supabase has 90 jobs, but this app can read only 0. '
        'Check the sign-in and read policy.',
      ),
      findsOneWidget,
    );
  });
}
