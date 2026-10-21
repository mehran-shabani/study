import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study/core/constants.dart';
import 'package:study/data/database.dart';
import 'package:study/data/models.dart';
import 'package:study/data/study_backup.dart';
import 'package:study/data/study_companion.dart';
import 'package:study/data/workspace_dao.dart';
import 'package:study/domain/focus_games.dart';
import '../support/memory_companion.dart';

const sample = CompanionPlan(
  stage: 'clinical',
  selectedCourseId: 'internal',
  courses: [
    MedicalCourse(
      id: 'internal',
      name: 'داخلی',
      priority: 3,
      examDate: '2026-11-01',
    ),
  ],
  days: {
    '2026-10-21': CompanionDay(
      energy: 1,
      tasks: [
        DailyTask(id: 'task-1', subject: 'داخلی', title: 'قلب', done: true),
      ],
      reflection: 'نیاز به مرور',
      tomorrow: 'ده تست',
    ),
  },
);

void main() {
  test(
    'course preferences and daily records round trip without mixing days',
    () {
      final plan = CompanionPlan.fromMap(
        jsonDecode(jsonEncode(sample.toMap())),
      );
      expect(plan.toMap(), sample.toMap());
      expect(plan.day('2026-10-22').tasks, isEmpty);
      final edited = plan.withDay('2026-10-22', const CompanionDay(energy: 3));
      expect(edited.day('2026-10-21').reflection, 'نیاز به مرور');
      expect(plan.days.length, 1);
      expect(edited.day('2026-10-22').energy, 3);
    },
  );

  test(
    'invalid dates and duplicate course IDs cannot overwrite saved data',
    () {
      expect(
        () => MedicalCourse.fromMap({
          'id': 'x',
          'name': 'x',
          'examDate': '2026-02-31',
        }),
        throwsFormatException,
      );
      expect(
        () => CompanionPlan.fromMap({
          'courses': [
            sample.courses.first.toMap(),
            sample.courses.first.toMap(),
          ],
        }),
        throwsFormatException,
      );
      expect(
        () => CompanionPlan.fromMap({
          'days': {'bad-date': {}},
        }),
        throwsFormatException,
      );
    },
  );

  test(
    'failed load blocks writes; failed save retains a retryable draft base',
    () async {
      final repository = MemoryCompanionRepository()..fail = true;
      final controller = CompanionController(repository, 1);
      addTearDown(controller.dispose);
      await controller.ready;
      expect(controller.state.loadFailed, true);
      expect(await controller.update((_) => sample), false);
      repository.fail = false;
      await controller.load();
      expect(await controller.update((_) => sample), true);
      repository.fail = true;
      expect(
        await controller.update((p) => p.copyWith(stage: 'intern')),
        false,
      );
      expect(controller.state.plan.stage, 'clinical');
      repository.fail = false;
      expect(await controller.update((p) => p.copyWith(stage: 'intern')), true);
    },
  );

  test('backup merge keeps current notes and never duplicates tasks', () {
    final newer = sample.withDay(
      '2026-10-21',
      sample.day('2026-10-21').copyWith(reflection: 'new'),
    );
    final merged = newer.merge(sample).merge(sample);
    expect(merged.day('2026-10-21').tasks.length, 1);
    expect(merged.day('2026-10-21').reflection, 'new');
  });

  test('number trail requires order and ignores already completed tiles', () {
    final game = NumberTrail(Random(7));
    expect(game.board.toSet().length, 16);
    game.tap(3);
    expect(game.mistakes, 1);
    expect(game.next, 1);
    game.tap(1);
    game.tap(1);
    expect(game.mistakes, 1);
    for (var i = 2; i <= 16; i++) {
      game.tap(i);
    }
    expect(game.complete, true);
    expect(game.next, 17);
  });

  test(
    'memory counts unique selections and closes after the allowed guesses',
    () {
      final game = PatternMemory(Random(1), 3);
      final target = game.targets.first;
      game.tap(target);
      game.tap(target);
      expect(game.guesses.length, 1);
      for (final i in game.targets.skip(1)) {
        game.tap(i);
      }
      expect(game.complete, true);
      expect(game.correct, 3);
      expect(game.mistakes, 0);
      game.tap(8);
      expect(game.guesses.length, 3);
    },
  );

  test(
    'SQLite persists per-plan data; backups remap IDs and imports are idempotent',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dir = await Directory.systemTemp.createTemp('study_companion_');
      await databaseFactory.setDatabasesPath(dir.path);
      try {
        final id = await WorkspaceDao().insert(
          const Workspace(
            name: 'Medical',
            startDate: '2026-10-01',
            endDate: '2026-11-01',
          ),
        );
        final repository = CompanionRepository();
        await repository.save(id, sample);
        await DatabaseService.close();
        expect((await repository.load(id)).toMap(), sample.toMap());
        final backup = await StudyBackup().exportJson();
        await WorkspaceDao().delete(id);
        expect(
          await (await DatabaseService.database).query('study_companion'),
          isEmpty,
        );
        await StudyBackup().importText(backup);
        await StudyBackup().importText(backup);
        final restored = (await WorkspaceDao().getAll()).single;
        expect(restored.id, isNot(id));
        expect((await repository.load(restored.id!)).toMap(), sample.toMap());
        expect(
          (await repository.load(restored.id!)).day('2026-10-21').tasks.length,
          1,
        );
      } finally {
        await DatabaseService.close();
        await dir.delete(recursive: true);
      }
    },
  );

  test(
    'version 6 migration adds companion storage and preserves preferences',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dir = await Directory.systemTemp.createTemp('study_companion_v6_');
      await databaseFactory.setDatabasesPath(dir.path);
      try {
        final old = await openDatabase(
          path.join(dir.path, AppConstants.dbName),
          version: 6,
          onCreate: (db, _) async {
            await db.execute(
              'CREATE TABLE workspaces (id INTEGER PRIMARY KEY, name TEXT)',
            );
            await db.execute(
              'CREATE TABLE app_settings (id INTEGER PRIMARY KEY, value TEXT)',
            );
            await db.insert('workspaces', {'id': 1, 'name': 'old plan'});
            await db.insert('app_settings', {
              'id': 1,
              'value': '{"language":"fa"}',
            });
          },
        );
        await old.close();
        await CompanionRepository().save(1, sample);
        final db = await DatabaseService.database;
        expect(
          (await db.query('app_settings')).single['value'],
          '{"language":"fa"}',
        );
        expect((await db.query('workspaces')).single['name'], 'old plan');
        expect(await db.getVersion(), 7);
      } finally {
        await DatabaseService.close();
        await dir.delete(recursive: true);
      }
    },
  );
}
