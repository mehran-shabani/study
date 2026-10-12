import 'package:study/data/study_alarm.dart';
import 'package:study/data/study_timer.dart';

class SilentStudyAlarm extends StudyAlarm {
  @override
  Future<bool> loadEnabled() async => true;
  @override
  Future<void> sync(StudyTimerSession? session, DateTime now,
      {required bool enabled}) async {}
  @override
  Future<void> preview() async {}
}
