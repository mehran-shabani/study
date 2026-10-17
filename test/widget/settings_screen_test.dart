import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study/data/app_settings.dart';
import 'package:study/data/models.dart';
import 'package:study/data/providers.dart';
import 'package:study/data/study_sound.dart';
import 'package:study/data/study_timer_provider.dart';
import 'package:study/main.dart';
import 'package:study/presentation/tracker/study_timer_screen.dart';
import 'package:study/presentation/workspaces/workspace_dialog.dart';
import '../support/memory_settings.dart';
import '../support/memory_timer_dao.dart';
import '../support/silent_study_alarm.dart';

const plan = Workspace(
  id: 1,
  name: 'زیست',
  startDate: '2026-10-01',
  endDate: '2026-10-31',
);

Future<ProviderContainer> openSettings(
  WidgetTester tester, {
  AppSettings settings = const AppSettings(language: 'en'),
  MemorySettingsRepository? repository,
  MemoryStudySound? sound,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialSettingsProvider.overrideWithValue(
          AppSettingsState(value: settings),
        ),
        appSettingsRepositoryProvider.overrideWithValue(
          repository ?? MemorySettingsRepository(),
        ),
        appLanguagePlatformProvider.overrideWithValue(
          RecordingLanguagePlatform(),
        ),
        studySoundProvider.overrideWithValue(sound ?? MemoryStudySound()),
        studyTimerDaoProvider.overrideWithValue(MemoryTimerDao()),
        studyAlarmProvider.overrideWithValue(SilentStudyAlarm()),
        workspacesProvider.overrideWith((ref) => Stream.value([plan])),
        studyEntriesProvider.overrideWith(
          (ref) => Stream.value(<StudyEntry>[]),
        ),
      ],
      child: const StudyApp(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(MainScreen)),
  );
  container.read(mainTabProvider.notifier).state = 3;
  await tester.pumpAndSettle();
  return container;
}

Future<void> selectOption(
  WidgetTester tester,
  String key,
  String option,
) async {
  final dropdown = find.byKey(ValueKey(key));
  await tester.ensureVisible(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(dropdown);
  await tester.pumpAndSettle();
  await tester.tap(find.text(option).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'language and theme update immediately and retain selected plan',
    (tester) async {
      final repository = MemorySettingsRepository();
      final container = await openSettings(tester, repository: repository);
      container.read(selectedWorkspaceIdProvider.notifier).state = 1;
      await selectOption(tester, 'settings-language', 'فارسی');
      expect(find.text('زبان برنامه'), findsOneWidget);
      expect(
        Directionality.of(
          tester.element(find.byKey(const ValueKey('settings-language'))),
        ),
        TextDirection.rtl,
      );
      expect(repository.value.language, 'fa');
      await selectOption(tester, 'settings-theme', 'تیره');
      expect(
        Theme.of(
          tester.element(find.byKey(const ValueKey('settings-theme'))),
        ).brightness,
        Brightness.dark,
      );
      expect(container.read(selectedWorkspaceIdProvider), 1);
      await selectOption(tester, 'settings-language', 'English');
      expect(find.text('App language'), findsOneWidget);
      expect(
        Directionality.of(
          tester.element(find.byKey(const ValueKey('settings-language'))),
        ),
        TextDirection.ltr,
      );
      expect(repository.value.theme, 'dark');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed preference save keeps the displayed selection and supports retry',
    (tester) async {
      final repository = MemorySettingsRepository()..fail = true;
      final container = await openSettings(tester, repository: repository);
      await selectOption(tester, 'settings-theme', 'Dark');
      expect(container.read(appSettingsProvider).value.theme, 'system');
      expect(
        tester
            .widget<DropdownButton<String>>(
              find.byKey(const ValueKey('settings-theme')),
            )
            .value,
        'system',
      );
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining('Could not apply'),
        ),
        findsOneWidget,
      );
      repository.fail = false;
      await selectOption(tester, 'settings-theme', 'Dark');
      expect(container.read(appSettingsProvider).value.theme, 'dark');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('new timer and plan use the saved defaults', (tester) async {
    final container = await openSettings(
      tester,
      settings: const AppSettings(
        language: 'en',
        focusMinutes: 50,
        dailyTargetHours: 6.25,
      ),
    );
    final context = tester.element(find.byType(MainScreen));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const StudyTimerScreen(workspace: plan),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('timer-start')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('timer-start')));
    await tester.pumpAndSettle();
    expect(container.read(studyTimerProvider).session!.focusMinutes, 50);
    expect(container.read(studyTimerProvider).session!.breakMinutes, 10);
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    showDialog<void>(context: context, builder: (_) => const WorkspaceDialog());
    await tester.pumpAndSettle();
    final field = tester
        .widgetList<TextField>(find.byType(TextField))
        .firstWhere(
          (field) => field.decoration?.labelText == 'Daily target (hours)',
        );
    expect(field.controller!.text, '6.25');
    Navigator.of(context).pop();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'all 12 tracks can be selected and failed volume changes recover',
    (tester) async {
      final sound = MemoryStudySound();
      final container = await openSettings(tester, sound: sound);
      for (final track in studySoundTracks) {
        final chip = find.byKey(ValueKey('sound-$track'));
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
        await tester.pumpAndSettle();
        expect(sound.settings.track, track);
      }
      sound.fail = true;
      await tester.ensureVisible(find.byKey(const ValueKey('focus-volume')));
      await tester.pumpAndSettle();
      final slider = tester.widget<Slider>(
        find.byKey(const ValueKey('focus-volume')),
      );
      slider.onChanged!(0.5);
      slider.onChangeEnd!(0.5);
      await tester.pumpAndSettle();
      expect(
        tester.widget<Slider>(find.byKey(const ValueKey('focus-volume'))).value,
        0.25,
      );
      expect(container.read(studySoundSettingsProvider).hasError, true);
      sound.fail = false;
      await tester.ensureVisible(find.byKey(const ValueKey('sound-piano')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sound-piano')));
      await tester.pumpAndSettle();
      expect(sound.settings.track, 'piano');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Persian daily target validates, saves and reset preserves study and audio',
    (tester) async {
      final sound = MemoryStudySound()
        ..settings = const StudySoundSettings(track: 'piano');
      final container = await openSettings(
        tester,
        settings: const AppSettings(language: 'fa'),
        sound: sound,
      );
      await tester.ensureVisible(find.text('هدف روزانه برای برنامه‌های جدید'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('هدف روزانه برای برنامه‌های جدید'));
      await tester.pumpAndSettle();
      final field = find.byKey(const ValueKey('settings-target-input'));
      await tester.enterText(field, '۲۵');
      await tester.tap(find.widgetWithText(FilledButton, 'ذخیره'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(field, '۶٫۲۵');
      await tester.tap(find.widgetWithText(FilledButton, 'ذخیره'));
      await tester.pumpAndSettle();
      expect(container.read(appSettingsProvider).value.dailyTargetHours, 6.25);
      await container.read(studyTimerProvider.notifier).start(1, 'زیست');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('settings-reset')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('settings-reset')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'بازنشانی تنظیمات برنامه'),
      );
      await tester.pumpAndSettle();
      expect(
        container.read(appSettingsProvider).value.toMap(),
        const AppSettings().toMap(),
      );
      expect(container.read(studyTimerProvider).session, isNotNull);
      expect(container.read(workspacesProvider).valueOrNull, [plan]);
      expect(sound.settings.track, 'piano');
      expect(tester.takeException(), isNull);
    },
  );

  for (final language in ['fa', 'en']) {
    testWidgets('$language settings fit 320px with large system and app text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await openSettings(
        tester,
        settings: AppSettings(language: language, textScale: 1.3),
      );
      expect(tester.takeException(), isNull);
      for (final key in [
        'settings-focus',
        'sound-bells',
        'focus-volume',
        'settings-reset',
      ]) {
        await tester.ensureVisible(find.byKey(ValueKey(key)));
        await tester.pumpAndSettle();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    });
  }
}
