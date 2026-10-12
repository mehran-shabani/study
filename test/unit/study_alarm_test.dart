import 'package:flutter_test/flutter_test.dart';
import 'package:study/data/study_alarm.dart';
import 'package:study/data/study_timer.dart';
import 'package:study/data/study_timer_provider.dart';
import '../support/memory_timer_dao.dart';

class RecordingAlarm extends StudyAlarm {
  final updates = <({bool running, bool enabled, Duration elapsed})>[];
  bool fail = false;
  @override
  Future<bool> loadEnabled() async => true;
  @override
  Future<void> sync(
    StudyTimerSession? session,
    DateTime now, {
    required bool enabled,
  }) async {
    if (fail) throw StateError('Audio unavailable');
    updates.add((
      running: session?.isRunning ?? false,
      enabled: enabled,
      elapsed: session?.elapsedAt(now) ?? Duration.zero,
    ));
  }
}

void main() {
  test('quarter-hour counts continue beyond an hour with exact boundaries', () {
    for (var quarter = 1; quarter <= 20; quarter++) {
      final boundary = Duration(minutes: quarter * 15);
      expect(
        StudyAlarmProgress(
          boundary - const Duration(milliseconds: 1),
        ).nextBeepCount,
        quarter,
      );
      expect(StudyAlarmProgress(boundary).completed, quarter);
      expect(
        StudyAlarmProgress(boundary).remaining,
        const Duration(minutes: 15),
      );
    }
  });

  test(
    'pause, resume, disable, stop and failed audio preserve active study',
    () async {
      var now = DateTime(2026, 10, 12);
      final alarm = RecordingAlarm();
      final dao = MemoryTimerDao();
      final controller = StudyTimerController(
        dao,
        now: () => now,
        alarm: alarm,
      );
      addTearDown(controller.dispose);
      await controller.ready;
      await controller.start(1, 'قلب');
      now = now.add(const Duration(minutes: 14));
      await controller.pause();
      expect(alarm.updates.last.running, false);
      now = now.add(const Duration(hours: 2));
      await controller.resume();
      expect(alarm.updates.last.elapsed, const Duration(minutes: 14));
      now = now.add(const Duration(minutes: 16));
      expect(
        StudyAlarmProgress(controller.state.session!.elapsedAt(now)).completed,
        2,
      );
      await controller.setAlarmEnabled(false);
      expect(alarm.updates.last.enabled, false);
      alarm.fail = true;
      expect(await controller.stop(), true);
      expect(dao.session!.isStopped, true);
      expect(controller.state.alarmError, isNotNull);
      expect(await controller.save('قلب'), true);
      expect(dao.entries.single.hours, 0.5);
      expect(dao.session, isNull);
    },
  );
}
