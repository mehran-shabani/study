import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study/data/models.dart';
import 'package:study/data/providers.dart';
import 'package:study/data/study_timer_provider.dart';
import 'package:study/presentation/tracker/tracker_screen.dart';
import 'package:study/presentation/tracker/study_timer_screen.dart';
import 'package:study/presentation/tracker/timer_subject_dialog.dart';
import '../support/memory_timer_dao.dart';
import '../support/silent_study_alarm.dart';
import 'study_features_test.dart' show localized;

void main() {
  const workspace = Workspace(
    id: 1,
    name: 'قلب',
    startDate: '2026-10-01',
    endDate: '2026-10-31',
  );

  testWidgets(
    'pink square aligns on the right and opens full timer with pause and stop',
    (tester) async {
      var now = DateTime(2026, 10, 11, 23, 59, 30);
      final dao = MemoryTimerDao();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyAlarmProvider.overrideWithValue(SilentStudyAlarm()),
            studyTimerDaoProvider.overrideWithValue(dao),
            timerClockProvider.overrideWithValue(() => now),
            selectedWorkspaceIdProvider.overrideWith((ref) => 1),
            workspacesProvider.overrideWith((ref) => Stream.value([workspace])),
            studyEntriesProvider.overrideWith(
              (ref) => Stream.value(<StudyEntry>[]),
            ),
          ],
          child: localized(const TrackerScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final clock = find.byKey(const ValueKey('study-timer-button'));
      final log = find.byKey(const ValueKey('log-study-button'));
      expect(tester.getRect(clock).right, tester.getRect(log).right);
      expect(
        tester.getRect(clock).right,
        tester.view.physicalSize.width / tester.view.devicePixelRatio - 16,
      );
      expect(tester.getCenter(clock).dy, lessThan(tester.getCenter(log).dy));
      expect(tester.getSize(clock), const Size(64, 64));
      expect(
        tester.widget<FloatingActionButton>(clock).backgroundColor,
        timerButtonPink,
      );
      expect(tester.widget<Icon>(find.byIcon(Icons.schedule_rounded)).size, 34);
      await tester.tap(clock);
      await tester.pumpAndSettle();
      expect(find.byType(StudyTimerScreen), findsOneWidget);
      expect(
        dao.session,
        isNull,
      ); // Opening the screen doesn't start accidentally.
      await tester.ensureVisible(find.byKey(const ValueKey('timer-start')));
      await tester.tap(find.byKey(const ValueKey('timer-start')));
      await tester.pumpAndSettle();
      now = now.add(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:00:30'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('timer-pause')));
      await tester.tap(find.byKey(const ValueKey('timer-pause')));
      await tester.pumpAndSettle();
      now = now.add(const Duration(minutes: 10));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:00:30'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('timer-resume')));
      await tester.tap(find.byKey(const ValueKey('timer-resume')));
      await tester.pumpAndSettle();
      now = now.add(const Duration(seconds: 60));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('00:01:30'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('timer-stop')));
      await tester.tap(find.byKey(const ValueKey('timer-stop')));
      await tester.pumpAndSettle();
      expect(find.byType(TimerSubjectDialog), findsOneWidget);
      await tester.tap(find.text('ذخیره'));
      await tester.pumpAndSettle();
      expect(dao.entries, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('timer-subject')),
        'قلب',
      );
      dao.failFinish = true;
      await tester.tap(find.text('ذخیره'));
      await tester.pumpAndSettle();
      expect(find.textContaining('اطلاعاتت حفظ شده'), findsOneWidget);
      expect(dao.entries, isEmpty);
      await tester.tap(find.text('بعداً ثبت می‌کنم'));
      await tester.pumpAndSettle();
      now = now.add(const Duration(hours: 1));
      await tester.ensureVisible(find.byKey(const ValueKey('timer-save')));
      await tester.tap(find.byKey(const ValueKey('timer-save')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('timer-subject')))
            .controller!
            .text,
        'قلب',
      );
      dao.failFinish = false;
      await tester.tap(find.text('ذخیره'));
      await tester.pumpAndSettle();
      expect(find.byType(TimerSubjectDialog), findsNothing);
      expect(dao.entries.map((e) => e.entryDate), ['2026-10-11', '2026-10-12']);
      expect(dao.entries.map((e) => e.hours), [30 / 3600, 60 / 3600]);
      expect(dao.session, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'leaving and reopening preserves pause, deletion is confirmed and records nothing',
    (tester) async {
      var now = DateTime(2026, 10, 11);
      final dao = MemoryTimerDao();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studyAlarmProvider.overrideWithValue(SilentStudyAlarm()),
            studyTimerDaoProvider.overrideWithValue(dao),
            timerClockProvider.overrideWithValue(() => now),
            selectedWorkspaceIdProvider.overrideWith((ref) => 1),
            workspacesProvider.overrideWith((ref) => Stream.value([workspace])),
            studyEntriesProvider.overrideWith(
              (ref) => Stream.value(<StudyEntry>[]),
            ),
          ],
          child: localized(const TrackerScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('study-timer-button')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('timer-start')));
      await tester.tap(find.byKey(const ValueKey('timer-start')));
      await tester.pumpAndSettle();
      now = now.add(const Duration(seconds: 20));
      await tester.ensureVisible(find.byKey(const ValueKey('timer-pause')));
      await tester.tap(find.byKey(const ValueKey('timer-pause')));
      await tester.pumpAndSettle();
      Navigator.of(tester.element(find.byType(StudyTimerScreen))).pop();
      await tester.pumpAndSettle();
      now = now.add(const Duration(hours: 1));
      await tester.tap(find.byKey(const ValueKey('study-timer-button')));
      await tester.pumpAndSettle();
      expect(find.text('00:00:20'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('timer-discard')));
      await tester.tap(find.byKey(const ValueKey('timer-discard')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('لغو'));
      await tester.pumpAndSettle();
      expect(dao.session, isNotNull);
      await tester.ensureVisible(find.byKey(const ValueKey('timer-discard')));
      await tester.tap(find.byKey(const ValueKey('timer-discard')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('حذف'));
      await tester.pumpAndSettle();
      expect(dao.session, isNull);
      expect(dao.entries, isEmpty);
      expect(find.byKey(const ValueKey('timer-start')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
