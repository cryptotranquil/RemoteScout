import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:remotescout/features/applications/application_form_screen.dart';
import 'package:remotescout/models/models.dart';

void main() {
  testWidgets('status stepper transitions the application pipeline',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/application/new',
      routes: [
        GoRoute(
          path: '/application/new',
          builder: (_, __) => const ApplicationFormScreen(),
        ),
        GoRoute(
          path: '/application/:id',
          builder: (_, __) => const Scaffold(body: Text('detail')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    // Both date fields start unset.
    expect(find.text('—'), findsNWidgets(2));

    // Move the pipeline to "Applied".
    await tester.tap(find.byKey(ValueKey(
        'status-${ApplicationStatus.values[3].label}'))); // Applied
    await tester.pumpAndSettle();

    // Applied date is auto-filled with today; follow-up stays unset.
    expect(find.text('—'), findsOneWidget);

    // And on to "Interview".
    await tester.tap(find.byKey(ValueKey(
        'status-${ApplicationStatus.values[4].label}'))); // Interview
    await tester.pumpAndSettle();
    expect(find.text('Interview'), findsWidgets);
  });

  testWidgets('manual create shows job fields and required labels',
      (tester) async {
    final router = GoRouter(
      initialLocation: '/application/new',
      routes: [
        GoRoute(
          path: '/application/new',
          builder: (_, __) => const ApplicationFormScreen(),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Add manually'), findsOneWidget);
    // Section labels render uppercased (NeuSectionLabel).
    expect(find.text('COVER LETTER'), findsOneWidget);
    expect(find.text('NOTES & INTERVIEW DETAILS'), findsOneWidget);
    expect(find.text('Add to tracker'), findsOneWidget);
    expect(find.byKey(const ValueKey('follow-up-field')), findsOneWidget);
  });
}
