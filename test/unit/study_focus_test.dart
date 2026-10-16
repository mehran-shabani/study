import 'package:flutter_test/flutter_test.dart';
import 'package:study/data/study_timer.dart';
import 'package:study/data/study_timer_provider.dart';
import '../support/memory_timer_dao.dart';
import '../support/silent_study_alarm.dart';

void main() {
  final start = DateTime(2026, 10, 16, 23, 50);
  StudyTimerSession focus() => StudyTimerSession(
    workspaceId: 1,
    workspaceName: 'قلب',
    startedAt: start,
    focusMinutes: 25,
    breakMinutes: 5,
    focusTargetMs: const Duration(minutes: 25).inMilliseconds,
  );

  test(
    'late foreground and overnight restore cap study at the exact boundary',
    () {
      var session = focus();
      final nextDay = start.add(const Duration(hours: 9));
      expect(session.elapsedAt(nextDay), const Duration(minutes: 25));
      session = StudyTimerSession.fromMap(session.toMap()).settle(nextDay);
      expect(session.isPaused, true);
      expect(session.pausedAt, start.add(const Duration(minutes: 25)));
      expect(session.breakEndsAt, start.add(const Duration(minutes: 30)));
      expect(session.roundsCompleted, 1);
      expect(session.settle(nextDay), same(session));
      session = session.resume(nextDay);
      expect(session.focusDeadline, nextDay.add(const Duration(minutes: 25)));
      final stopped = session.stop(nextDay.add(const Duration(minutes: 3)));
      expect(stopped.entriesFor('قلب').map((e) => e.hours), [10 / 60, 18 / 60]);
    },
  );

  test(
    'manual pause preserves remainder; rest never advances a focus block',
    () {
      var session = focus().pause(start.add(const Duration(minutes: 10)));
      final resumedAt = start.add(const Duration(hours: 2));
      session = StudyTimerSession.fromMap(session.toMap()).resume(resumedAt);
      expect(session.focusDeadline, resumedAt.add(const Duration(minutes: 15)));
      expect(
        session.settle(resumedAt.add(const Duration(minutes: 14))).isRunning,
        true,
      );
      session = session.settle(resumedAt.add(const Duration(minutes: 15)));
      expect(
        session.elapsedAt(resumedAt.add(const Duration(days: 1))),
        const Duration(minutes: 25),
      );
    },
  );

  test(
    'sleepy break is persisted and continues only after explicit resume',
    () {
      var session = focus().takeBreak(
        start.add(const Duration(minutes: 7)),
        minutes: 20,
      );
      session = StudyTimerSession.fromMap(session.toMap());
      expect(session.breakEndsAt, start.add(const Duration(minutes: 27)));
      expect(session.roundsCompleted, 0);
      expect(
        session.settle(start.add(const Duration(hours: 4))).isPaused,
        true,
      );
      session = session.resume(start.add(const Duration(hours: 4)));
      expect(session.breakEndsAt, isNull);
      expect(
        session.focusDeadline,
        start.add(const Duration(hours: 4, minutes: 25)),
      );
      expect(
        session.elapsedAt(start.add(const Duration(hours: 4))),
        const Duration(minutes: 7),
      );
    },
  );

  test(
    'controller restoration settles overdue focus before native sync',
    () async {
      final dao = MemoryTimerDao()..session = focus();
      var now = start.add(const Duration(hours: 2));
      final controller = StudyTimerController(
        dao,
        now: () => now,
        alarm: SilentStudyAlarm(),
      );
      addTearDown(controller.dispose);
      await controller.ready;
      expect(dao.session!.isPaused, true);
      expect(dao.session!.elapsedAt(now), const Duration(minutes: 25));
      await controller.resume();
      now = now.add(const Duration(minutes: 25));
      await controller.checkFocus();
      expect(dao.session!.roundsCompleted, 2);
      expect(await controller.stop(), true);
      expect(await controller.save('قلب'), true);
      expect(
        dao.entries.fold<double>(0, (sum, e) => sum + e.hours),
        closeTo(50 / 60, 1e-10),
      );
    },
  );

  test(
    'failed automatic pause freezes time and can be saved without overcount',
    () async {
      var now = start;
      final dao = MemoryTimerDao();
      final controller = StudyTimerController(
        dao,
        now: () => now,
        alarm: SilentStudyAlarm(),
      );
      addTearDown(controller.dispose);
      await controller.ready;
      await controller.start(1, 'قلب', focusMinutes: 15, breakMinutes: 3);
      now = now.add(const Duration(minutes: 20));
      dao.failUpdate = true;
      await controller.checkFocus();
      expect(controller.state.session!.isPaused, true);
      expect(controller.state.error, isNotNull);
      expect(
        controller.state.session!.elapsedAt(now),
        const Duration(minutes: 15),
      );
      dao.failUpdate = false;
      await controller.stop();
      await controller.save('قلب');
      expect(dao.entries.fold<double>(0, (sum, e) => sum + e.hours), 0.25);
    },
  );

  test(
    'invalid focus and break settings cannot create or mutate a session',
    () async {
      final dao = MemoryTimerDao();
      final controller = StudyTimerController(
        dao,
        now: () => start,
        alarm: SilentStudyAlarm(),
      );
      addTearDown(controller.dispose);
      await controller.ready;
      expect(await controller.start(1, 'قلب', focusMinutes: 1), false);
      expect(await controller.start(1, 'قلب', breakMinutes: 50), false);
      expect(dao.session, isNull);
      await controller.start(1, 'قلب');
      expect(await controller.takeBreak(-1), false);
      expect(dao.session!.isRunning, true);
    },
  );
}
