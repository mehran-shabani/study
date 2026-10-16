import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study/data/models.dart';
import 'package:study/data/study_sound.dart';
import 'package:study/data/study_timer_provider.dart';
import 'package:study/l10n/generated/app_localizations.dart';
import 'package:study/presentation/tracker/study_timer_screen.dart';
import '../support/memory_timer_dao.dart';
import '../support/silent_study_alarm.dart';

class FakeSound extends StudySound {
  var settings = const StudySoundSettings();
  final awake = <bool>[];
  @override
  bool get supported => true;
  @override
  Future<StudySoundSettings> load() async => settings;
  @override
  Future<void> save(StudySoundSettings value) async {
    settings = value;
  }

  @override
  Future<void> screenAwake(bool value) async {
    awake.add(value);
  }
}

void main() {
  const workspace = Workspace(
    id: 1,
    name: 'قلب',
    startDate: '2026-10-01',
    endDate: '2026-10-31',
  );
  for (final language in ['fa', 'en']) {
    testWidgets(
      '$language focus controls fit 320px with 1.5x text and persist breaks',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var now = DateTime(2026, 10, 16, 10);
        final dao = MemoryTimerDao();
        final sound = FakeSound();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studyTimerDaoProvider.overrideWithValue(dao),
              studyAlarmProvider.overrideWithValue(SilentStudyAlarm()),
              studySoundProvider.overrideWithValue(sound),
              timerClockProvider.overrideWithValue(() => now),
            ],
            child: MaterialApp(
              locale: Locale(language),
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.5)),
                child: child!,
              ),
              home: const StudyTimerScreen(workspace: workspace),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byKey(const ValueKey('timer-start')));
        await tester.tap(find.byKey(const ValueKey('timer-start')));
        await tester.pumpAndSettle();
        expect(dao.session!.focusMinutes, 25);
        now = now.add(const Duration(minutes: 25));
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
        expect(dao.session!.isPaused, true);
        expect(find.byKey(const ValueKey('focus-break')), findsOneWidget);
        now = now.add(const Duration(hours: 1));
        await tester.pump(const Duration(seconds: 1));
        expect(dao.session!.elapsedAt(now), const Duration(minutes: 25));
        await tester.ensureVisible(find.byKey(const ValueKey('timer-resume')));
        await tester.tap(find.byKey(const ValueKey('timer-resume')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('focus-sleepy')));
        await tester.tap(find.byKey(const ValueKey('focus-sleepy')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(
            language == 'fa' ? '۳ دقیقه تحرک' : '3-minute movement break',
          ),
        );
        await tester.pumpAndSettle();
        expect(dao.session!.breakEndsAt, now.add(const Duration(minutes: 3)));
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.byKey(const ValueKey('focus-sound-panel')),
        );
        await tester.tap(find.byKey(const ValueKey('focus-sound-panel')));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byKey(const ValueKey('sound-melody')));
        await tester.tap(find.byKey(const ValueKey('sound-melody')));
        await tester.pumpAndSettle();
        expect(sound.settings.track, 'melody');
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        expect(sound.awake.last, false);
      },
    );
  }
}
