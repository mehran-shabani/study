import 'dart:convert';
import 'models.dart';

class StudyInterval {
  const StudyInterval(this.start, this.end);
  final DateTime start;
  final DateTime end;

  Map<String, String> toMap() => {
    'start': start.toUtc().toIso8601String(),
    'end': end.toUtc().toIso8601String(),
  };
}

/// Only active intervals count as study. UTC storage preserves running, paused
/// and stopped sessions across process restarts; daily totals use local dates.
class StudyTimerSession {
  const StudyTimerSession({
    required this.workspaceId,
    required this.workspaceName,
    required this.startedAt,
    this.stoppedAt,
    this.pausedAt,
    DateTime? activeSince,
    this.intervals = const [],
    this.subject = '',
    this.focusMinutes = 0,
    this.breakMinutes = 5,
    this.focusTargetMs = 0,
    this.roundsCompleted = 0,
    this.breakEndsAt,
  }) : activeSince = activeSince ?? startedAt;

  final int workspaceId;
  final String workspaceName;
  final DateTime startedAt;
  final DateTime? stoppedAt;
  final DateTime? pausedAt;
  final DateTime activeSince;
  final List<StudyInterval> intervals;
  final String subject;
  final int focusMinutes;
  final int breakMinutes;
  final int focusTargetMs;
  final int roundsCompleted;
  final DateTime? breakEndsAt;

  /// The active-time target survives manual pauses and process restarts.
  DateTime? get focusDeadline {
    if (!isRunning || focusMinutes == 0) return null;
    final previous = intervals.fold<int>(
      0,
      (sum, item) => sum + item.end.difference(item.start).inMilliseconds,
    );
    return activeSince.add(Duration(milliseconds: focusTargetMs - previous));
  }

  bool get isStopped => stoppedAt != null;
  bool get isPaused => !isStopped && pausedAt != null;
  bool get isRunning => !isStopped && !isPaused;

  List<StudyInterval> _activeIntervals(DateTime now) {
    var end = stoppedAt ?? now;
    final deadline = focusDeadline;
    if (deadline != null && end.isAfter(deadline)) end = deadline;
    return [
      ...intervals,
      if (pausedAt == null && end.isAfter(activeSince))
        StudyInterval(activeSince, end),
    ];
  }

  Duration elapsedAt(DateTime now) => _activeIntervals(now).fold(
    Duration.zero,
    (sum, interval) => sum + interval.end.difference(interval.start),
  );

  StudyTimerSession pause(DateTime now) {
    if (!isRunning) return this;
    return StudyTimerSession(
      workspaceId: workspaceId,
      workspaceName: workspaceName,
      startedAt: startedAt,
      pausedAt: now,
      activeSince: activeSince,
      intervals: List.unmodifiable(_activeIntervals(now)),
      subject: subject,
      focusMinutes: focusMinutes,
      breakMinutes: breakMinutes,
      focusTargetMs: focusTargetMs,
      roundsCompleted: roundsCompleted,
    );
  }

  StudyTimerSession resume(DateTime now) {
    if (!isPaused) return this;
    return StudyTimerSession(
      workspaceId: workspaceId,
      workspaceName: workspaceName,
      startedAt: startedAt,
      activeSince: now,
      intervals: intervals,
      subject: subject,
      focusMinutes: focusMinutes,
      breakMinutes: breakMinutes,
      focusTargetMs: focusTargetMs,
      roundsCompleted: roundsCompleted,
    );
  }

  StudyTimerSession stop(DateTime now) {
    if (isStopped) return this;
    return StudyTimerSession(
      workspaceId: workspaceId,
      workspaceName: workspaceName,
      startedAt: startedAt,
      stoppedAt: now,
      activeSince: now,
      intervals: List.unmodifiable(_activeIntervals(now)),
      subject: subject,
      focusMinutes: focusMinutes,
      breakMinutes: breakMinutes,
      focusTargetMs: focusTargetMs,
      roundsCompleted: roundsCompleted,
    );
  }

  StudyTimerSession withSubject(String value) => StudyTimerSession(
    workspaceId: workspaceId,
    workspaceName: workspaceName,
    startedAt: startedAt,
    stoppedAt: stoppedAt,
    pausedAt: pausedAt,
    activeSince: activeSince,
    intervals: intervals,
    subject: value,
    focusMinutes: focusMinutes,
    breakMinutes: breakMinutes,
    focusTargetMs: focusTargetMs,
    roundsCompleted: roundsCompleted,
    breakEndsAt: breakEndsAt,
  );

  /// A late foreground tick still ends study at the exact focus deadline.
  StudyTimerSession settle(DateTime now) {
    final deadline = focusDeadline;
    if (deadline == null || now.isBefore(deadline)) return this;
    return takeBreak(deadline, minutes: breakMinutes, completedRound: true);
  }

  StudyTimerSession takeBreak(
    DateTime now, {
    required int minutes,
    bool completedRound = false,
  }) {
    if (isStopped) return this;
    final paused = pause(now);
    return StudyTimerSession(
      workspaceId: workspaceId,
      workspaceName: workspaceName,
      startedAt: startedAt,
      pausedAt: paused.pausedAt,
      activeSince: paused.activeSince,
      intervals: paused.intervals,
      subject: subject,
      focusMinutes: focusMinutes,
      breakMinutes: breakMinutes,
      focusTargetMs:
          paused.elapsedAt(now).inMilliseconds +
          Duration(minutes: focusMinutes).inMilliseconds,
      roundsCompleted: roundsCompleted + (completedRound ? 1 : 0),
      breakEndsAt: now.add(Duration(minutes: minutes)),
    );
  }

  Map<String, Object?> toMap() => {
    'id': 1,
    'workspace_id': workspaceId,
    'workspace_name': workspaceName,
    'started_at': startedAt.toUtc().toIso8601String(),
    'stopped_at': stoppedAt?.toUtc().toIso8601String(),
    'paused_at': pausedAt?.toUtc().toIso8601String(),
    'active_since': activeSince.toUtc().toIso8601String(),
    'intervals': jsonEncode(intervals.map((i) => i.toMap()).toList()),
    'subject': subject,
    'focus_minutes': focusMinutes,
    'break_minutes': breakMinutes,
    'focus_target_ms': focusTargetMs,
    'rounds_completed': roundsCompleted,
    'break_ends_at': breakEndsAt?.toUtc().toIso8601String(),
  };

  factory StudyTimerSession.fromMap(Map<String, Object?> map) {
    DateTime? date(String key) =>
        map[key] == null ? null : DateTime.parse(map[key] as String).toLocal();
    final intervals = (jsonDecode(map['intervals'] as String? ?? '[]') as List)
        .map(
          (item) => StudyInterval(
            DateTime.parse(item['start'] as String).toLocal(),
            DateTime.parse(item['end'] as String).toLocal(),
          ),
        )
        .toList();
    return StudyTimerSession(
      workspaceId: map['workspace_id'] as int,
      workspaceName: map['workspace_name'] as String,
      startedAt: date('started_at')!,
      stoppedAt: date('stopped_at'),
      pausedAt: date('paused_at'),
      activeSince: date('active_since'),
      intervals: List.unmodifiable(intervals),
      subject: map['subject'] as String,
      focusMinutes: map['focus_minutes'] as int? ?? 0,
      breakMinutes: map['break_minutes'] as int? ?? 5,
      focusTargetMs: map['focus_target_ms'] as int? ?? 0,
      roundsCompleted: map['rounds_completed'] as int? ?? 0,
      breakEndsAt: date('break_ends_at'),
    );
  }

  /// Aggregate active intervals by local day, excluding all breaks. Legacy
  /// timers without interval history still use their original start/stop pair.
  List<StudyEntry> entriesFor(String title) {
    if (!isStopped) throw StateError('Stop the timer before saving.');
    final totals = <String, int>{};
    for (final interval in _activeIntervals(stoppedAt!)) {
      var cursor = interval.start.toLocal();
      final end = interval.end.toLocal();
      while (cursor.isBefore(end)) {
        final midnight = DateTime(cursor.year, cursor.month, cursor.day + 1);
        final boundary = midnight.isBefore(end) ? midnight : end;
        final date =
            '${cursor.year.toString().padLeft(4, '0')}-'
            '${cursor.month.toString().padLeft(2, '0')}-'
            '${cursor.day.toString().padLeft(2, '0')}';
        totals.update(
          date,
          (value) => value + boundary.difference(cursor).inMicroseconds,
          ifAbsent: () => boundary.difference(cursor).inMicroseconds,
        );
        cursor = boundary;
      }
    }
    if (totals.isEmpty) throw StateError('No study time to save.');
    final dates = totals.keys.toList()..sort();
    return dates
        .map(
          (date) => StudyEntry(
            workspaceId: workspaceId,
            entryDate: date,
            title: title.trim(),
            hours: totals[date]! / Duration.microsecondsPerHour,
          ),
        )
        .toList();
  }
}

String formatTimerDuration(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
