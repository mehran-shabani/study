import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study/main.dart';
import 'package:study/data/models.dart';
import 'package:study/data/providers.dart';
import 'package:study/data/study_timer_provider.dart';
import '../support/memory_timer_dao.dart';

void main() {
  group('MainScreen Widget Tests', () {
    testWidgets('MainScreen displays bottom navigation bar', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyTimerDaoProvider.overrideWithValue(MemoryTimerDao()),
            workspacesProvider
                .overrideWith((ref) => Stream.value(<Workspace>[])),
            studyEntriesProvider
                .overrideWith((ref) => Stream.value(<StudyEntry>[])),
          ],
          child: const StudyApp(),
        ),
      );

      // Wait for any async operations
      await tester.pumpAndSettle();

      // Verify bottom navigation bar is present
      expect(find.byType(NavigationBar), findsOneWidget);
    });

    testWidgets('MainScreen has five navigation destinations', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyTimerDaoProvider.overrideWithValue(MemoryTimerDao()),
            workspacesProvider
                .overrideWith((ref) => Stream.value(<Workspace>[])),
            studyEntriesProvider
                .overrideWith((ref) => Stream.value(<StudyEntry>[])),
          ],
          child: const StudyApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Find all NavigationDestination widgets
      final destinations = find.byType(NavigationDestination);
      expect(destinations, findsNWidgets(5));
    });

    testWidgets('MainScreen switches screens on navigation tap',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyTimerDaoProvider.overrideWithValue(MemoryTimerDao()),
            workspacesProvider
                .overrideWith((ref) => Stream.value(<Workspace>[])),
            studyEntriesProvider
                .overrideWith((ref) => Stream.value(<StudyEntry>[])),
          ],
          child: const StudyApp(),
        ),
      );

      await tester.pumpAndSettle();

      // Initially on Workspaces screen
      expect(find.text('Plans'), findsAtLeastNWidgets(1));

      // Tap on Tracker navigation
      final trackerDestination = find.ancestor(
        of: find.text('Study'),
        matching: find.byType(NavigationDestination),
      );
      await tester.tap(trackerDestination);
      await tester.pumpAndSettle();

      // Verify Tracker screen is shown
      expect(find.text('Study'), findsAtLeastNWidgets(1));

      // Tap on Analytics navigation
      final analyticsDestination = find.ancestor(
        of: find.text('Reports'),
        matching: find.byType(NavigationDestination),
      );
      await tester.tap(analyticsDestination);
      await tester.pumpAndSettle();

      // Verify Analytics screen is shown
      expect(find.text('Reports'), findsAtLeastNWidgets(1));
    });
  });
}
