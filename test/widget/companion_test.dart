import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study/core/utils.dart';
import 'package:study/data/app_settings.dart';
import 'package:study/data/models.dart';
import 'package:study/data/providers.dart';
import 'package:study/data/study_companion.dart';
import 'package:study/data/study_sound.dart';
import 'package:study/data/study_timer_provider.dart';
import 'package:study/main.dart';
import 'package:study/presentation/companion/companion_editors.dart';
import 'package:study/presentation/companion/focus_games_screen.dart';
import '../support/memory_companion.dart';
import '../support/memory_settings.dart';
import '../support/memory_timer_dao.dart';
import '../support/silent_study_alarm.dart';

const workspace = Workspace(
  id: 1,
  name: 'پزشکی · ترم پاییز',
  startDate: '2026-10-01',
  endDate: '2026-12-01',
);
const capture = bool.fromEnvironment('CAPTURE_COMPANION');
final captureKey = GlobalKey();

class ManualPracticeClock implements Stopwatch {
  int milliseconds = 0;
  @override
  bool isRunning = false;
  @override
  Duration get elapsed => Duration(milliseconds: milliseconds);
  @override
  int get elapsedMilliseconds => milliseconds;
  @override
  int get elapsedMicroseconds => milliseconds * 1000;
  @override
  int get elapsedTicks => milliseconds;
  @override
  int get frequency => 1000;
  @override
  void reset() {
    milliseconds = 0;
  }

  @override
  void start() {
    isRunning = true;
  }

  @override
  void stop() {
    isRunning = false;
  }
}

Future<ProviderContainer> openDay(
  WidgetTester tester,
  MemoryCompanionRepository repository, {
  String language = 'en',
  String theme = 'light',
  double scale = 1,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        companionRepositoryProvider.overrideWithValue(repository),
        appSettingsRepositoryProvider.overrideWithValue(
          MemorySettingsRepository(),
        ),
        appLanguagePlatformProvider.overrideWithValue(
          RecordingLanguagePlatform(),
        ),
        selectedWorkspaceIdProvider.overrideWith((ref) => 1),
        initialSettingsProvider.overrideWithValue(
          AppSettingsState(
            value: AppSettings(
              language: language,
              theme: theme,
              textScale: scale,
            ),
          ),
        ),
        workspacesProvider.overrideWith((ref) => Stream.value([workspace])),
        studyEntriesProvider.overrideWith(
          (ref) => Stream.value(<StudyEntry>[]),
        ),
        studyTimerDaoProvider.overrideWithValue(MemoryTimerDao()),
        studyAlarmProvider.overrideWithValue(SilentStudyAlarm()),
        studySoundProvider.overrideWithValue(MemoryStudySound()),
      ],
      child: RepaintBoundary(key: captureKey, child: const StudyApp()),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(MainScreen)));
}

MemoryCompanionRepository sampleRepository() =>
    MemoryCompanionRepository()
      ..values[1] = CompanionPlan(
        stage: 'clinical',
        selectedCourseId: 'internal',
        courses: const [
          MedicalCourse(
            id: 'internal',
            name: 'داخلی',
            priority: 3,
            examDate: '2026-11-01',
          ),
          MedicalCourse(id: 'pharmacology', name: 'فارماکولوژی'),
          MedicalCourse(id: 'pathology', name: 'پاتولوژی'),
        ],
        days: {
          AppUtils.today(): const CompanionDay(
            tasks: [
              DailyTask(
                id: 'one',
                subject: 'داخلی',
                title: 'چرخهٔ قلب و ده تست',
                method: 'questions',
              ),
              DailyTask(
                id: 'two',
                subject: 'فارماکولوژی',
                title: 'مرور داروهای اتونوم',
                method: 'recall',
                done: true,
              ),
            ],
          ),
        },
      );

Future<void> screenshot(WidgetTester tester, String name) async {
  if (!capture) return;
  await tester.pump();
  final boundary =
      captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final img = await boundary.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/screenshots/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    img.dispose();
  });
}

void main() {
  setUpAll(() async {
    if (capture && Platform.isWindows) {
      final font = FontLoader('Roboto')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              await File('C:/Windows/Fonts/tahoma.ttf').readAsBytes(),
            ),
          ),
        );
      await font.load();
      final config = jsonDecode(
        await File('.dart_tool/package_config.json').readAsString(),
      );
      final flutter = (config['packages'] as List).firstWhere(
        (p) => p['name'] == 'flutter',
      );
      final sdk = Directory.fromUri(
        Uri.parse(flutter['rootUri'] as String),
      ).parent.parent;
      final icons = FontLoader('MaterialIcons')
        ..addFont(
          Future.value(
            ByteData.sublistView(
              await File(
                '${sdk.path}/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
              ).readAsBytes(),
            ),
          ),
        );
      await icons.load();
    }
  });

  testWidgets(
    'customize courses, retain a failed draft, then prepare a timer with subject',
    (tester) async {
      final repository = MemoryCompanionRepository();
      final container = await openDay(tester, repository);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('manage-courses')),
        300,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('companion-day')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('manage-courses')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilterChip, 'Anatomy'));
      await tester.enterText(
        find.byKey(const ValueKey('custom-course')),
        'Medical ethics',
      );
      repository.fail = true;
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(find.byType(CompanionEditor), findsOneWidget);
      expect(find.text('Medical ethics'), findsOneWidget);
      repository.fail = false;
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(repository.values[1]!.courses.length, 2);
      await tester.ensureVisible(find.byKey(const ValueKey('prepare-study')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('prepare-study')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('prepared-start')));
      await tester.pumpAndSettle();
      final subject = tester.widget<TextField>(
        find.byKey(const ValueKey('timer-initial-subject')),
      );
      expect(subject.controller!.text, 'Anatomy');
      await tester.ensureVisible(find.byKey(const ValueKey('timer-start')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('timer-start')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(container.read(studyTimerProvider).session!.subject, 'Anatomy');
      expect(container.read(studyTimerProvider).session!.focusMinutes, 25);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'planned task completion and reflection persist independently of logged hours',
    (tester) async {
      final repository = sampleRepository();
      await openDay(tester, repository);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('add-daily-task')),
        400,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('companion-day')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('add-daily-task')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('daily-task-title')),
        'Review renal physiology',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(repository.values[1]!.day(AppUtils.today()).tasks.length, 3);
      final checkbox = find.byType(Checkbox).first;
      await tester.ensureVisible(checkbox);
      await tester.pumpAndSettle();
      await tester.tap(checkbox);
      await tester.pumpAndSettle();
      expect(
        repository.values[1]!.day(AppUtils.today()).tasks.first.done,
        true,
      );
      await tester.scrollUntilVisible(
        find.widgetWithText(OutlinedButton, 'Close the day gently'),
        400,
        scrollable: find
            .descendant(
              of: find.byKey(const PageStorageKey('companion-day')),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(OutlinedButton, 'Close the day gently'),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).first,
        'Review the mechanism tomorrow',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Save'));
      await tester.pumpAndSettle();
      expect(
        repository.values[1]!.day(AppUtils.today()).reflection,
        'Review the mechanism tomorrow',
      );
      final container = ProviderScope.containerOf(
        tester.element(find.byType(MainScreen)),
      );
      expect(container.read(studyEntriesProvider).value, isEmpty);
    },
  );

  for (final language in ['fa', 'en']) {
    for (final appearance in ['light', 'dark']) {
      testWidgets(
        '$language $appearance companion fits narrow large text and editors',
        (tester) async {
          tester.view.physicalSize = const Size(320, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await openDay(
            tester,
            sampleRepository(),
            language: language,
            theme: appearance,
            scale: 1.3,
          );
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('manage-courses')),
            300,
            scrollable: find
                .descendant(
                  of: find.byKey(const PageStorageKey('companion-day')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('manage-courses')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(
            find.widgetWithText(
              TextButton,
              language == 'fa' ? 'لغو' : 'Cancel',
            ),
          );
          await tester.pumpAndSettle();
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('add-daily-task')),
            350,
            scrollable: find
                .descendant(
                  of: find.byKey(const PageStorageKey('companion-day')),
                  matching: find.byType(Scrollable),
                )
                .first,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.byKey(const ValueKey('add-daily-task')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets('number game completes in order and pauses on background', (
    tester,
  ) async {
    await openDay(tester, sampleRepository());
    final context = tester.element(find.byType(MainScreen));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const FocusGamesScreen(initialGame: FocusGameKind.numbers),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('focus-game-start')));
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(
      find.text('Practice paused. Resume when you are ready.'),
      findsOneWidget,
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    await tester.tap(find.text('Resume practice'));
    await tester.pump();
    for (var i = 1; i <= 16; i++) {
      await tester.tap(find.byKey(ValueKey('number-$i')));
      await tester.pump();
    }
    expect(find.text('Practice complete'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'opening practice pauses active study without changing its subject',
    (tester) async {
      final container = await openDay(tester, sampleRepository());
      await container
          .read(studyTimerProvider.notifier)
          .start(1, workspace.name, subject: 'Anatomy');
      await tester.pump();
      await tester.tap(find.byTooltip('A short focus warm-up').first);
      await tester.pumpAndSettle();
      expect(container.read(studyTimerProvider).session!.isPaused, true);
      expect(container.read(studyTimerProvider).session!.subject, 'Anatomy');
      expect(
        find.text(
          'Study is paused while you practice. Return to the study timer to resume.',
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'response practice scores taps and inhibition across all twenty rounds',
    (tester) async {
      await openDay(tester, sampleRepository());
      final clock = ManualPracticeClock();
      Navigator.of(tester.element(find.byType(MainScreen))).push(
        MaterialPageRoute<void>(
          builder: (_) => FocusGamesScreen(
            initialGame: FocusGameKind.response,
            clock: clock,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('focus-game-start')));
      await tester.pump();
      for (var round = 0; round < 20; round++) {
        if (find.text('Circle · tap').evaluate().isNotEmpty) {
          await tester.tap(find.byKey(const ValueKey('response-target')));
          await tester.pump();
        }
        clock.milliseconds += 1200;
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Practice complete'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'pattern practice hides the pattern then scores three complete rounds',
    (tester) async {
      await openDay(tester, sampleRepository());
      final clock = ManualPracticeClock();
      Navigator.of(tester.element(find.byType(MainScreen))).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              FocusGamesScreen(initialGame: FocusGameKind.memory, clock: clock),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('focus-game-start')));
      await tester.pump();
      for (var round = 0; round < 3; round++) {
        final targets = [
          for (var i = 0; i < 9; i++)
            if (find
                .descendant(
                  of: find.byKey(ValueKey('pattern-$i')),
                  matching: find.byIcon(Icons.circle),
                )
                .evaluate()
                .isNotEmpty)
              i,
        ];
        expect(targets.length, 3 + round);
        clock.milliseconds += 1800;
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('Find the tiles'), findsOneWidget);
        for (final i in targets) {
          await tester.tap(find.byKey(ValueKey('pattern-$i')));
          await tester.pump();
        }
        clock.milliseconds += 700;
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Practice complete'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('capture Persian home, route and game in light and dark', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 960);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = await openDay(tester, sampleRepository(), language: 'fa');
    await screenshot(tester, 'companion-fa-light');
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('add-daily-task')),
      350,
      scrollable: find
          .descendant(
            of: find.byKey(const PageStorageKey('companion-day')),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await screenshot(tester, 'companion-fa-route');
    await container
        .read(appSettingsProvider.notifier)
        .update(const AppSettings(language: 'fa', theme: 'dark'));
    final context = tester.element(find.byType(MainScreen));
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            const FocusGamesScreen(initialGame: FocusGameKind.numbers),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('focus-game-start')));
    await tester.pump();
    await screenshot(tester, 'companion-fa-game-dark');
    await tester.pumpWidget(const SizedBox());
  });
}
