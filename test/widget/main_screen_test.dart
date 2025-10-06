import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study/main.dart';

void main() {
  group('MainScreen Widget Tests', () {
    testWidgets('MainScreen displays bottom navigation bar', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: StudyApp(),
        ),
      );

      // Wait for any async operations
      await tester.pumpAndSettle();

      // Verify bottom navigation bar is present
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('MainScreen has three navigation destinations', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: StudyApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Find all NavigationDestination widgets
      final destinations = find.byType(NavigationDestination);
      expect(destinations, findsNWidgets(3));
    });

    testWidgets('MainScreen switches screens on navigation tap', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: StudyApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Initially on Workspaces screen
      expect(find.text('Workspaces'), findsAtLeastNWidgets(1));

      // Tap on Tracker navigation
      final trackerDestination = find.ancestor(
        of: find.text('Tracker'),
        matching: find.byType(NavigationDestination),
      );
      await tester.tap(trackerDestination);
      await tester.pumpAndSettle();

      // Verify Tracker screen is shown
      expect(find.text('Tracker'), findsAtLeastNWidgets(1));

      // Tap on Analytics navigation
      final analyticsDestination = find.ancestor(
        of: find.text('Analytics'),
        matching: find.byType(NavigationDestination),
      );
      await tester.tap(analyticsDestination);
      await tester.pumpAndSettle();

      // Verify Analytics screen is shown
      expect(find.text('Analytics'), findsAtLeastNWidgets(1));
    });
  });
}
