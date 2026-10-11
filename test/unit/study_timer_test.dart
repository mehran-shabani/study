import 'package:flutter_test/flutter_test.dart';
import 'package:study/data/study_timer.dart';
import 'package:study/data/study_timer_provider.dart';
import '../support/memory_timer_dao.dart';

void main() {
  test('crossing local midnight creates exact durations on each day', () {
    final session = StudyTimerSession(
      workspaceId: 7,
      workspaceName: 'قلب',
      startedAt: DateTime(2026, 10, 11, 23, 50),
      stoppedAt: DateTime(2026, 10, 12, 0, 20),
    );
    final entries = session.entriesFor(' قلب ');
    expect(entries.map((e) => e.entryDate), ['2026-10-11', '2026-10-12']);
    expect(entries.map((e) => e.hours), [10 / 60, 20 / 60]);
    expect(
        entries.every((e) => e.workspaceId == 7 && e.title == 'قلب'), isTrue);
  });

  test('ending at midnight creates no zero-duration next-day entry', () {
    final session = StudyTimerSession(
      workspaceId: 1,
      workspaceName: 'قلب',
      startedAt: DateTime(2026, 10, 11, 23, 59, 59),
      stoppedAt: DateTime(2026, 10, 12),
    );
    expect(session.entriesFor('قلب').single.hours, 1 / 3600);
    expect(session.entriesFor('قلب').single.entryDate, '2026-10-11');
    expect(
        formatTimerDuration(const Duration(hours: 25, seconds: 2)), '25:00:02');
  });

  test('timestamps survive storage round trip and negative time clamps to zero',
      () {
    final session = StudyTimerSession(
        workspaceId: 1,
        workspaceName: 'قلب',
        startedAt: DateTime(2026, 10, 11));
    final restored = StudyTimerSession.fromMap(session.toMap());
    expect(restored.startedAt, session.startedAt);
    expect(restored.isRunning, isTrue);
    expect(restored.elapsedAt(DateTime(2026, 10, 10)), Duration.zero);
    expect(() => restored.entriesFor('قلب'), throwsStateError);
  });

  test('restore, stop, failed save and retry preserve session and refresh once',
      () async {
    var now = DateTime(2026, 10, 11, 23, 59);
    final dao = MemoryTimerDao();
    var refreshes = 0;
    var controller =
        StudyTimerController(dao, now: () => now, onSaved: () => refreshes++);
    await controller.ready;
    expect(await controller.start(1, 'قلب'), isTrue);
    expect(await controller.start(2, 'ریه'), isFalse);
    controller.dispose();
    now = DateTime(2026, 10, 12, 0, 1);
    controller =
        StudyTimerController(dao, now: () => now, onSaved: () => refreshes++);
    addTearDown(controller.dispose);
    await controller.ready;
    expect(
        controller.state.session!.elapsedAt(now), const Duration(minutes: 2));
    expect(await controller.stop(), isTrue);
    now = now.add(const Duration(hours: 1));
    expect(
        controller.state.session!.elapsedAt(now), const Duration(minutes: 2));
    dao.failFinish = true;
    expect(await controller.save('قلب'), isFalse);
    expect(controller.state.session!.isRunning, isFalse);
    expect(controller.state.session!.subject, 'قلب');
    expect(dao.entries, isEmpty);
    expect(refreshes, 0);
    dao.failFinish = false;
    expect(await controller.save('قلب'), isTrue);
    expect(controller.state.session, isNull);
    expect(dao.entries.length, 2);
    expect(refreshes, 1);
    expect(await controller.save('قلب'), isFalse);
    expect(dao.entries.length, 2);
  });
}
