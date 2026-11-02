import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remotescout/core/ui/animated_notch_nav_bar.dart';

void main() {
  testWidgets('keeps all destinations tappable and retargets while animating',
      (tester) async {
    var currentIndex = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            bottomNavigationBar: AnimatedNotchNavBar(
              items: const [
                AnimatedNotchNavBarItem(
                  icon: Icons.explore_outlined,
                  label: 'Discover',
                ),
                AnimatedNotchNavBarItem(
                  icon: Icons.bookmark_outline,
                  label: 'Saved',
                ),
                AnimatedNotchNavBarItem(
                  icon: Icons.work_outline,
                  label: 'Applications',
                ),
                AnimatedNotchNavBarItem(
                  icon: Icons.tune,
                  label: 'Profile',
                ),
              ],
              currentIndex: currentIndex,
              onTap: (index) => setState(() => currentIndex = index),
              accentColor: const Color(0xFF005454),
              backgroundColor: Colors.white,
              inactiveColor: const Color(0xFF3E4948),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Saved'));
    await tester.pump(const Duration(milliseconds: 180));
    await tester.tap(find.text('Profile'));
    await tester.pump(const Duration(milliseconds: 700));

    expect(currentIndex, 3);
    expect(find.text('Discover'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
    expect(find.text('Applications'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
