import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:study/core/constants.dart';
import 'package:study/data/app_settings.dart';
import 'package:study/data/database.dart';
import 'package:study/data/models.dart';
import 'package:study/data/study_sound.dart';
import 'package:study/data/study_timer.dart';
import 'package:study/data/study_timer_dao.dart';
import 'package:study/data/workspace_dao.dart';
import '../support/memory_settings.dart';

void main() {
  test('malformed and out-of-range preferences use safe defaults', () {
    final value = AppSettings.fromMap(const {
      'language': 'xx',
      'theme': 4,
      'focusMinutes': 25.0,
      'dailyTargetHours': double.nan,
      'textScale': -1,
    });
    expect(value.toMap(), const AppSettings().toMap());
    for (final target in [0, -1, 25, double.infinity, '4']) {
      expect(
        AppSettings.fromMap({'dailyTargetHours': target}).dailyTargetHours,
        4,
      );
    }
    for (final language in ['fa', 'en', 'system']) {
      final settings = AppSettings(
        language: language,
        theme: 'dark',
        focusMinutes: 50,
        dailyTargetHours: 0.25,
        textScale: 1.3,
      );
      expect(AppSettings.fromMap(settings.toMap()).toMap(), settings.toMap());
    }
  });

  test(
    'a failed write retains the previous settings and allows retry',
    () async {
      final repository = MemorySettingsRepository()..fail = true;
      final platform = RecordingLanguagePlatform();
      final controller = AppSettingsController(
        repository,
        platform,
        const AppSettingsState(),
      );
      addTearDown(controller.dispose);
      expect(await controller.update(const AppSettings(language: 'fa')), false);
      expect(controller.state.value.language, 'system');
      expect(controller.state.error, isNotNull);
      expect(platform.values, isEmpty);
      repository.fail = false;
      expect(await controller.update(const AppSettings(language: 'fa')), true);
      expect(repository.value.language, 'fa');
      expect(platform.values, ['fa']);
    },
  );

  test('notification failure does not roll back a saved language', () async {
    final repository = MemorySettingsRepository();
    final controller = AppSettingsController(
      repository,
      RecordingLanguagePlatform()..fail = true,
      const AppSettingsState(),
    );
    addTearDown(controller.dispose);
    expect(await controller.update(const AppSettings(language: 'fa')), false);
    expect(repository.value.language, 'fa');
    expect(controller.state.value.language, 'fa');
    expect(controller.state.loadFailed, false);
  });

  test(
    'failed initial load must be retried before overwriting preferences',
    () async {
      final repository = MemorySettingsRepository()
        ..value = const AppSettings(language: 'fa');
      final controller = AppSettingsController(
        repository,
        RecordingLanguagePlatform(),
        AppSettingsState(loadFailed: true, error: StateError('Read failed')),
      );
      addTearDown(controller.dispose);
      expect(await controller.update(const AppSettings()), false);
      expect(repository.value.language, 'fa');
      expect(await controller.reload(), true);
      expect(controller.state.value.language, 'fa');
      expect(controller.state.loadFailed, false);
    },
  );

  test('rapid writes do not overwrite an in-flight preference', () async {
    final repository = MemorySettingsRepository()..gate = Completer<void>();
    final controller = AppSettingsController(
      repository,
      RecordingLanguagePlatform(),
      const AppSettingsState(),
    );
    addTearDown(controller.dispose);
    final pending = controller.update(const AppSettings(language: 'fa'));
    expect(await controller.update(const AppSettings(theme: 'dark')), false);
    repository.gate!.complete();
    expect(await pending, true);
    expect(controller.state.value.language, 'fa');
  });

  test(
    'version 5 database upgrades, reopens preferences and keeps the pending timer',
    () async {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final directory = await Directory.systemTemp.createTemp(
        'study_settings_',
      );
      await databaseFactory.setDatabasesPath(directory.path);
      try {
        // Construct the previous schema from the current schema by removing only
        // the newly introduced table and resetting SQLite's user version.
        final db = await DatabaseService.database;
        await db.execute('DROP TABLE app_settings');
        await db.setVersion(5);
        final id = await WorkspaceDao().insert(
          const Workspace(
            name: 'پزشکی',
            startDate: '2026-10-01',
            endDate: '2026-10-31',
          ),
        );
        final session = StudyTimerSession(
          workspaceId: id,
          workspaceName: 'پزشکی',
          startedAt: DateTime(2026, 10, 17, 10),
        );
        await StudyTimerDao().start(session);
        await DatabaseService.close();
        // Simultaneous consumers must share the same database connection.
        final connections = await Future.wait(
          List.generate(4, (_) => DatabaseService.database),
        );
        expect(
          connections.every((db) => identical(db, connections.first)),
          true,
        );
        expect(await connections.first.getVersion(), AppConstants.dbVersion);
        final repository = AppSettingsRepository();
        expect((await repository.load()).toMap(), const AppSettings().toMap());
        const saved = AppSettings(
          language: 'fa',
          theme: 'dark',
          focusMinutes: 50,
          dailyTargetHours: 6.25,
          textScale: 1.3,
        );
        await repository.save(saved);
        await DatabaseService.close();
        expect((await repository.load()).toMap(), saved.toMap());
        expect((await StudyTimerDao().load())!.workspaceId, id);
        expect((await WorkspaceDao().getAll()).single.name, 'پزشکی');
        await repository.save(const AppSettings());
        expect((await StudyTimerDao().load())!.startedAt, session.startedAt);
        expect((await WorkspaceDao().getAll()).length, 1);
        final upgradedDb = await DatabaseService.database;
        for (final malformed in [
          'invalid json',
          '[]',
          'null',
          '{"focusMinutes":25.0}',
        ]) {
          await upgradedDb.update('app_settings', {
            'value': malformed,
          }, where: 'id = 1');
          expect(
            (await repository.load()).toMap(),
            const AppSettings().toMap(),
          );
        }
      } finally {
        await DatabaseService.close();
        await directory.delete(recursive: true);
      }
    },
  );

  test('sound preferences sanitize unknown tracks and invalid volume', () {
    expect(studySoundTracks.toSet().length, 13);
    for (final volume in [double.nan, double.infinity, 'loud', null]) {
      final settings = StudySoundSettings.fromMap({
        'track': 'missing',
        'volume': volume,
      });
      expect(settings.track, 'off');
      expect(settings.volume, 0.25);
    }
    expect(StudySoundSettings.fromMap({'volume': 1}).volume, 0.6);
    expect(StudySoundSettings.fromMap({'volume': -1}).volume, 0);
  });

  test(
    'a failed audio write restores the last saved volume and can recover',
    () async {
      final sound = MemoryStudySound();
      final controller = StudySoundController(sound);
      addTearDown(controller.dispose);
      await controller.ready;
      sound.fail = true;
      expect(
        await controller.save(
          const StudySoundSettings(track: 'piano', volume: 0.5),
        ),
        false,
      );
      expect(controller.state.valueOrNull!.volume, 0.25);
      expect(controller.state.valueOrNull!.track, 'off');
      expect(controller.state.hasError, true);
      sound.fail = false;
      expect(
        await controller.save(
          const StudySoundSettings(track: 'piano', volume: 0.5),
        ),
        true,
      );
      await controller.reload();
      expect(controller.state.valueOrNull!.track, 'piano');
      expect(controller.state.hasError, false);
    },
  );
}
