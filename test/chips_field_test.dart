import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remotescout/features/onboarding/profile_form.dart';

void main() {
  testWidgets('chips field selects and deselects suggestions', (tester) async {
    List<String> selected = [];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => ChipsField(
            selected: selected,
            onChanged: (v) => setState(() => selected = v),
            suggestions: const ['SQL', 'Excel'],
          ),
        ),
      ),
    ));

    expect(find.byKey(const ValueKey('suggestion-SQL')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('suggestion-SQL')));
    await tester.pump();
    expect(find.byKey(const ValueKey('chip-SQL')), findsOneWidget);
    expect(selected, ['SQL']);

    // Tapping the selected chip removes it.
    await tester.tap(find.byKey(const ValueKey('chip-SQL')));
    await tester.pump();
    expect(find.byKey(const ValueKey('chip-SQL')), findsNothing);
    expect(selected, isEmpty);
  });

  testWidgets('chips field accepts free-text entries', (tester) async {
    List<String> selected = [];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => ChipsField(
            selected: selected,
            onChanged: (v) => setState(() => selected = v),
            suggestions: const [],
          ),
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField), 'LookML');
    await tester.tap(find.byKey(const ValueKey('chip-add')));
    await tester.pump();
    expect(find.byKey(const ValueKey('chip-LookML')), findsOneWidget);
    expect(selected, ['LookML']);
  });
}
