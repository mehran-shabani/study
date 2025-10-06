import 'package:flutter_test/flutter_test.dart';
import 'package:study/data/models.dart';

void main() {
  group('Workspace', () {
    test('creates workspace with all fields', () {
      const workspace = Workspace(
        id: 1,
        name: 'Test Workspace',
        startDate: '2025-01-01',
        endDate: '2025-12-31',
      );

      expect(workspace.id, 1);
      expect(workspace.name, 'Test Workspace');
      expect(workspace.startDate, '2025-01-01');
      expect(workspace.endDate, '2025-12-31');
    });

    test('converts to map correctly', () {
      const workspace = Workspace(
        id: 1,
        name: 'Test',
        startDate: '2025-01-01',
        endDate: '2025-12-31',
      );

      final map = workspace.toMap();

      expect(map['id'], 1);
      expect(map['name'], 'Test');
      expect(map['start_date'], '2025-01-01');
      expect(map['end_date'], '2025-12-31');
    });

    test('creates from map correctly', () {
      final map = {
        'id': 1,
        'name': 'Test',
        'start_date': '2025-01-01',
        'end_date': '2025-12-31',
      };

      final workspace = Workspace.fromMap(map);

      expect(workspace.id, 1);
      expect(workspace.name, 'Test');
      expect(workspace.startDate, '2025-01-01');
      expect(workspace.endDate, '2025-12-31');
    });

    test('copyWith updates specified fields', () {
      const workspace = Workspace(
        id: 1,
        name: 'Test',
        startDate: '2025-01-01',
        endDate: '2025-12-31',
      );

      final updated = workspace.copyWith(name: 'Updated');

      expect(updated.id, 1);
      expect(updated.name, 'Updated');
      expect(updated.startDate, '2025-01-01');
      expect(updated.endDate, '2025-12-31');
    });

    test('equality works correctly', () {
      const workspace1 = Workspace(
        id: 1,
        name: 'Test',
        startDate: '2025-01-01',
        endDate: '2025-12-31',
      );

      const workspace2 = Workspace(
        id: 1,
        name: 'Test',
        startDate: '2025-01-01',
        endDate: '2025-12-31',
      );

      const workspace3 = Workspace(
        id: 2,
        name: 'Test',
        startDate: '2025-01-01',
        endDate: '2025-12-31',
      );

      expect(workspace1, equals(workspace2));
      expect(workspace1, isNot(equals(workspace3)));
    });
  });

  group('StudyEntry', () {
    test('creates entry with all fields', () {
      const entry = StudyEntry(
        id: 1,
        workspaceId: 10,
        entryDate: '2025-01-01',
        title: 'Math',
        hours: 2.5,
      );

      expect(entry.id, 1);
      expect(entry.workspaceId, 10);
      expect(entry.entryDate, '2025-01-01');
      expect(entry.title, 'Math');
      expect(entry.hours, 2.5);
    });

    test('converts to map correctly', () {
      const entry = StudyEntry(
        id: 1,
        workspaceId: 10,
        entryDate: '2025-01-01',
        title: 'Math',
        hours: 2.5,
      );

      final map = entry.toMap();

      expect(map['id'], 1);
      expect(map['workspace_id'], 10);
      expect(map['entry_date'], '2025-01-01');
      expect(map['title'], 'Math');
      expect(map['hours'], 2.5);
    });

    test('creates from map correctly', () {
      final map = {
        'id': 1,
        'workspace_id': 10,
        'entry_date': '2025-01-01',
        'title': 'Math',
        'hours': 2.5,
      };

      final entry = StudyEntry.fromMap(map);

      expect(entry.id, 1);
      expect(entry.workspaceId, 10);
      expect(entry.entryDate, '2025-01-01');
      expect(entry.title, 'Math');
      expect(entry.hours, 2.5);
    });

    test('copyWith updates specified fields', () {
      const entry = StudyEntry(
        id: 1,
        workspaceId: 10,
        entryDate: '2025-01-01',
        title: 'Math',
        hours: 2.5,
      );

      final updated = entry.copyWith(title: 'Physics', hours: 3.0);

      expect(updated.id, 1);
      expect(updated.workspaceId, 10);
      expect(updated.entryDate, '2025-01-01');
      expect(updated.title, 'Physics');
      expect(updated.hours, 3.0);
    });

    test('equality works correctly', () {
      const entry1 = StudyEntry(
        id: 1,
        workspaceId: 10,
        entryDate: '2025-01-01',
        title: 'Math',
        hours: 2.5,
      );

      const entry2 = StudyEntry(
        id: 1,
        workspaceId: 10,
        entryDate: '2025-01-01',
        title: 'Math',
        hours: 2.5,
      );

      const entry3 = StudyEntry(
        id: 2,
        workspaceId: 10,
        entryDate: '2025-01-01',
        title: 'Math',
        hours: 2.5,
      );

      expect(entry1, equals(entry2));
      expect(entry1, isNot(equals(entry3)));
    });
  });
}
