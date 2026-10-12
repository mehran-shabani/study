import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study/data/database.dart';
import 'package:study/data/study_backup.dart';
import 'package:study/data/models.dart';
import 'package:study/domain/csv_export.dart';

void main() {
  late Directory directory;
  setUp(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    directory = await Directory.systemTemp.createTemp('study_backup_');
    await databaseFactory.setDatabasesPath(directory.path);
  });
  tearDown(() async {
    await DatabaseService.close();
    await directory.delete(recursive: true);
  });

  const plan = Workspace(
    id: 1,
    name: 'دستیاری, قلب',
    startDate: '2026-10-01',
    endDate: '2026-10-31',
  );
  const entry = StudyEntry(
    id: 1,
    workspaceId: 1,
    entryDate: '2026-10-12',
    title: 'قلب "مرور"\nفصل ۲',
    hours: 0.25,
  );

  test('old CSV round trips Persian, BOM, quotes and multiline subjects', () {
    final result = StudyBackup.decode(buildStudyCsv(plan, [entry]));
    expect(result.workspaces.single['name'], plan.name);
    expect(result.workspaces.single['start_date'], entry.entryDate);
    expect(result.entries.single['title'], entry.title);
    expect(result.entries.single['hours'], 0.25);
  });

  test(
    'full backup merges without losing identical real sessions; repeat is idempotent',
    () async {
      final db = await DatabaseService.database;
      await db.insert('workspaces', plan.toMap());
      await db.insert('study_entries', entry.toMap());
      await db.insert('study_entries', entry.copyWith(id: 2).toMap());
      final backup = StudyBackup();
      final saved = await backup.exportJson();
      await db.delete('study_entries');
      await db.delete('workspaces');
      await db.insert(
        'workspaces',
        plan.copyWith(id: 5, name: 'موجود').toMap(),
      );
      expect(await backup.importText(saved), 2);
      expect(await backup.importText(saved), 0);
      expect((await db.query('workspaces')).length, 2);
      expect((await db.query('study_entries')).length, 2);
      final restored = jsonDecode(await backup.exportJson());
      expect(restored['workspaces'].length, 2);
    },
  );

  test('invalid backups leave all existing data intact', () async {
    final db = await DatabaseService.database;
    await db.insert('workspaces', plan.toMap());
    await db.insert('study_entries', entry.toMap());
    final backup = StudyBackup();
    final json = jsonDecode(await backup.exportJson());
    json['entries'][0]['entry_date'] = '2026-02-30';
    await expectLater(
      backup.importText(jsonEncode(json)),
      throwsFormatException,
    );
    json['entries'][0]['entry_date'] = '2026-10-12';
    json['entries'][0]['workspace_id'] = 999;
    await expectLater(
      backup.importText(jsonEncode(json)),
      throwsFormatException,
    );
    expect((await db.query('study_entries')).single['title'], entry.title);
    expect((await db.query('workspaces')).length, 1);
  });
}
