import 'package:flutter_test/flutter_test.dart';
import 'package:study/data/models.dart';
import 'package:study/domain/helpers.dart';

void main() {
  group('calcProgress', () {
    test('returns 0 for empty entries', () {
      const workspace = Workspace(
        id: 1,
        name: 'Test',
        startDate: '2025-01-01',
        endDate: '2025-01-31',
      );

      final progress = calcProgress([], workspace);
      expect(progress, 0.0);
    });

    test('calculates progress correctly', () {
      const workspace = Workspace(
        id: 1,
        name: 'Test',
        startDate: '2025-01-01',
        endDate: '2025-01-10',
      );

      // 10 days × 4 hours = 40 expected hours
      // 20 actual hours = 50% progress
      final entries = [
        const StudyEntry(
          id: 1,
          workspaceId: 1,
          entryDate: '2025-01-01',
          title: 'Math',
          hours: 10.0,
        ),
        const StudyEntry(
          id: 2,
          workspaceId: 1,
          entryDate: '2025-01-02',
          title: 'Physics',
          hours: 10.0,
        ),
      ];

      final progress = calcProgress(entries, workspace);
      expect(progress, 50.0);
    });

    test('caps progress at 100%', () {
      const workspace = Workspace(
        id: 1,
        name: 'Test',
        startDate: '2025-01-01',
        endDate: '2025-01-01',
      );

      // 1 day × 4 hours = 4 expected hours
      // 10 actual hours = 250%, but should cap at 100%
      final entries = [
        const StudyEntry(
          id: 1,
          workspaceId: 1,
          entryDate: '2025-01-01',
          title: 'Math',
          hours: 10.0,
        ),
      ];

      final progress = calcProgress(entries, workspace);
      expect(progress, 100.0);
    });
  });

  group('buildTimeline', () {
    test('creates timeline for all days in range', () {
      const workspace = Workspace(
        id: 1,
        name: 'Test',
        startDate: '2025-01-01',
        endDate: '2025-01-03',
      );

      final timeline = buildTimeline([], workspace);

      expect(timeline.length, 3);
      expect(timeline[0].date, '2025-01-01');
      expect(timeline[1].date, '2025-01-02');
      expect(timeline[2].date, '2025-01-03');
      expect(timeline[0].hours, 0.0);
      expect(timeline[1].hours, 0.0);
      expect(timeline[2].hours, 0.0);
    });

    test('fills in actual hours from entries', () {
      const workspace = Workspace(
        id: 1,
        name: 'Test',
        startDate: '2025-01-01',
        endDate: '2025-01-03',
      );

      final entries = [
        const StudyEntry(
          id: 1,
          workspaceId: 1,
          entryDate: '2025-01-01',
          title: 'Math',
          hours: 2.0,
        ),
        const StudyEntry(
          id: 2,
          workspaceId: 1,
          entryDate: '2025-01-01',
          title: 'Physics',
          hours: 3.0,
        ),
        const StudyEntry(
          id: 3,
          workspaceId: 1,
          entryDate: '2025-01-03',
          title: 'Chemistry',
          hours: 1.5,
        ),
      ];

      final timeline = buildTimeline(entries, workspace);

      expect(timeline.length, 3);
      expect(timeline[0].hours, 5.0); // 2 + 3
      expect(timeline[1].hours, 0.0);
      expect(timeline[2].hours, 1.5);
    });
  });

  group('aggHoursByTitle', () {
    test('returns empty map for empty entries', () {
      final result = aggHoursByTitle([]);
      expect(result, isEmpty);
    });

    test('aggregates hours by title', () {
      final entries = [
        const StudyEntry(
          id: 1,
          workspaceId: 1,
          entryDate: '2025-01-01',
          title: 'Math',
          hours: 2.0,
        ),
        const StudyEntry(
          id: 2,
          workspaceId: 1,
          entryDate: '2025-01-02',
          title: 'Math',
          hours: 3.0,
        ),
        const StudyEntry(
          id: 3,
          workspaceId: 1,
          entryDate: '2025-01-01',
          title: 'Physics',
          hours: 1.5,
        ),
      ];

      final result = aggHoursByTitle(entries);

      expect(result.length, 2);
      expect(result['Math'], 5.0);
      expect(result['Physics'], 1.5);
    });

    test('sorts by hours descending', () {
      final entries = [
        const StudyEntry(
          id: 1,
          workspaceId: 1,
          entryDate: '2025-01-01',
          title: 'Math',
          hours: 2.0,
        ),
        const StudyEntry(
          id: 2,
          workspaceId: 1,
          entryDate: '2025-01-02',
          title: 'Physics',
          hours: 5.0,
        ),
        const StudyEntry(
          id: 3,
          workspaceId: 1,
          entryDate: '2025-01-03',
          title: 'Chemistry',
          hours: 3.0,
        ),
      ];

      final result = aggHoursByTitle(entries);
      final titles = result.keys.toList();

      expect(titles[0], 'Physics'); // 5.0
      expect(titles[1], 'Chemistry'); // 3.0
      expect(titles[2], 'Math'); // 2.0
    });
  });
}
