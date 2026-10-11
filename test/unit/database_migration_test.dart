import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study/core/constants.dart';
import 'package:study/data/database.dart';
import 'package:study/data/study_entry_dao.dart';
import 'package:study/data/workspace_dao.dart';

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
      expect(await (await DatabaseService.database).getVersion(), 2);
    } finally {
      await DatabaseService.close();
      await directory.delete(recursive: true);
    }
  });
}
