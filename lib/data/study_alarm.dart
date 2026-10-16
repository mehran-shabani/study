import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'study_timer.dart';

/// Uses active study time, so breaks never advance an awareness milestone.
class StudyAlarmProgress {
  const StudyAlarmProgress(this.elapsed);
  final Duration elapsed;
  static const interval = Duration(minutes: 15);
  int get completed => elapsed.inMilliseconds ~/ interval.inMilliseconds;
  int get nextBeepCount => completed + 1;
  Duration get remaining => Duration(
    milliseconds:
        nextBeepCount * interval.inMilliseconds - elapsed.inMilliseconds,
  );
}

class StudyAlarm {
  static const channel = MethodChannel('study/awareness');
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<bool> loadEnabled() async =>
      supported ? await channel.invokeMethod<bool>('isEnabled') ?? true : true;

  Future<void> sync(
    StudyTimerSession? session,
    DateTime now, {
    required bool enabled,
  }) async {
    if (!supported) return;
    await channel.invokeMethod<void>('sync', {
      'enabled': enabled,
      'running': session?.isRunning ?? false,
      'sessionId': session?.startedAt.toUtc().toIso8601String() ?? '',
      'elapsedMs': session?.elapsedAt(now).inMilliseconds ?? 0,
      'workspace': session?.workspaceName ?? '',
      'focusDeadline': session?.focusDeadline?.millisecondsSinceEpoch ?? 0,
      'breakEndsAt': session?.breakEndsAt?.millisecondsSinceEpoch ?? 0,
      'breakMinutes': session?.breakMinutes ?? 5,
    });
  }

  Future<void> preview() async {
    if (supported) await channel.invokeMethod<void>('preview');
  }
}
