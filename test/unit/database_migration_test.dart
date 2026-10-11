import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study/core/constants.dart';
import 'package:study/data/database.dart';
import 'package:study/data/study_entry_dao.dart';
import 'package:study/data/workspace_dao.dart';
import 'package:study/data/models.dart';
import 'package:study/data/study_timer.dart';
import 'package:study/data/study_timer_dao.dart';

void main() {
  test('version 1 upgrade retains sessions and persists editable daily targets',
      () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final directory = await Directory.systemTemp.createTemp('study_migration_');
    await databaseFactory.setDatabasesPath(directory.path);
    try {
      final oldDb = await openDatabase(
          path.join(directory.path, AppConstants.dbName),
          version: 1, onCreate: (db, _) async {
        await db.execute(
            'CREATE TABLE workspaces (id INTEGER PRIMARY KEY, name TEXT NOT NULL, start_date TEXT NOT NULL, end_date TEXT NOT NULL)');
        await db.execute(
            'CREATE TABLE study_entries (id INTEGER PRIMARY KEY, workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE, entry_date TEXT NOT NULL, title TEXT NOT NULL, hours REAL NOT NULL)');
        await db.insert('workspaces', {
          'id': 1,
          'name': 'قلب',
          'start_date': '2025-03-21',
          'end_date': '2025-03-22'
        });
        await db.insert('study_entries', {
          'id': 1,
          'workspace_id': 1,
          'entry_date': '2025-03-21',
          'title': 'مرور',
          'hours': 3.5
        });
      });
      await oldDb.close();
      final dao = WorkspaceDao();
      final workspace = (await dao.getById(1))!;
      expect(workspace.dailyTargetHours, 4);
      expect((await StudyEntryDao().getByWorkspace(1)).single.hours, 3.5);
      await dao.update(workspace.copyWith(dailyTargetHours: 7.5));
      await DatabaseService.close();
      expect((await dao.getById(1))!.dailyTargetHours, 7.5);
      expect(await (await DatabaseService.database).getVersion(), 3);
    } finally {
      await DatabaseService.close();
      await directory.delete(recursive: true);
    }
  });

  test('version 2 upgrade restores timer and saves all days atomically',
      () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final directory = await Directory.systemTemp.createTemp('study_timer_');
    await databaseFactory.setDatabasesPath(directory.path);
    try {
      final oldDb = await openDatabase(
          path.join(directory.path, AppConstants.dbName),
          version: 2, onCreate: (db, _) async {
        await db.execute('CREATE TABLE workspaces (id INTEGER PRIMARY KEY, '
            'name TEXT NOT NULL, start_date TEXT NOT NULL, end_date TEXT NOT NULL, '
            'daily_target_hours REAL NOT NULL DEFAULT 4.0)');
        await db.execute('CREATE TABLE study_entries (id INTEGER PRIMARY KEY, '
            'workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE, '
            'entry_date TEXT NOT NULL, title TEXT NOT NULL, hours REAL NOT NULL)');
      });
      await oldDb.close();
      final workspaceDao = WorkspaceDao();
      final id = await workspaceDao.insert(const Workspace(
          name: 'قلب',
          startDate: '2026-10-01',
          endDate: '2026-10-31',
          dailyTargetHours: 6));
      final dao = StudyTimerDao();
      expect(await dao.load(), isNull);
      var session = StudyTimerSession(
          workspaceId: id,
          workspaceName: 'قلب',
          startedAt: DateTime(2026, 10, 11, 23, 59));
      await dao.start(session);
      await DatabaseService.close();
      session = (await dao.load())!;
      expect(session.isRunning, isTrue);
      expect((await workspaceDao.getById(id))!.dailyTargetHours, 6);
      await expectLater(
          workspaceDao.delete(id), throwsA(isA<DatabaseException>()));
      session = session.stop(DateTime(2026, 10, 12, 0, 1)).withSubject('مرور');
      await dao.update(session);
      await DatabaseService.close();
      session = (await dao.load())!;
      expect(session.subject, 'مرور');
      expect(session.isRunning, isFalse);
      final db = await DatabaseService.database;
      await db.execute(
          'CREATE TRIGGER fail_second_day BEFORE INSERT ON study_entries '
          "WHEN NEW.entry_date = '2026-10-12' BEGIN SELECT RAISE(ABORT, 'test failure'); END");
      await expectLater(
          dao.finish(session, 'مرور'), throwsA(isA<DatabaseException>()));
      expect(await dao.load(), isNotNull);
      expect(await StudyEntryDao().getByWorkspace(id), isEmpty);
      await db.execute('DROP TRIGGER fail_second_day');
      await dao.finish(session, 'مرور');
      expect(await dao.load(), isNull);
      final entries = await StudyEntryDao().getByWorkspace(id);
      expect(entries.length, 2);
      expect(entries.fold<double>(0, (sum, e) => sum + e.hours), 2 / 60);
      await expectLater(dao.finish(session, 'مرور'), throwsStateError);
      expect((await StudyEntryDao().getByWorkspace(id)).length, 2);
      await workspaceDao.delete(id);
    } finally {
      await DatabaseService.close();
      await directory.delete(recursive: true);
    }
  });
}
