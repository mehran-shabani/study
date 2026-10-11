import 'models.dart';

/// Wall-clock timestamps keep the timer accurate while the app is backgrounded
/// and allow a running or stopped session to survive process restarts.
class StudyTimerSession {
  const StudyTimerSession({
    required this.workspaceId,
    required this.workspaceName,
    required this.startedAt,
    this.stoppedAt,
    this.subject = '',
  });

  final int workspaceId;
  final String workspaceName;
  final DateTime startedAt;
  final DateTime? stoppedAt;
  final String subject;

  bool get isRunning => stoppedAt == null;

  Duration elapsedAt(DateTime now) {
    final duration = (stoppedAt ?? now).difference(startedAt);
    return duration.isNegative ? Duration.zero : duration;
  }

  StudyTimerSession stop(DateTime now) => StudyTimerSession(
        workspaceId: workspaceId,
        workspaceName: workspaceName,
        startedAt: startedAt,
        stoppedAt: now,
        subject: subject,
      );

  StudyTimerSession withSubject(String value) => StudyTimerSession(
        workspaceId: workspaceId,
        workspaceName: workspaceName,
        startedAt: startedAt,
        stoppedAt: stoppedAt,
        subject: value,
      );

  Map<String, Object?> toMap() => {
        'id': 1,
        'workspace_id': workspaceId,
        'workspace_name': workspaceName,
        'started_at': startedAt.toUtc().toIso8601String(),
        'stopped_at': stoppedAt?.toUtc().toIso8601String(),
        'subject': subject,
      };

  factory StudyTimerSession.fromMap(Map<String, Object?> map) =>
      StudyTimerSession(
        workspaceId: map['workspace_id'] as int,
        workspaceName: map['workspace_name'] as String,
        startedAt: DateTime.parse(map['started_at'] as String).toLocal(),
        stoppedAt: map['stopped_at'] == null
            ? null
            : DateTime.parse(map['stopped_at'] as String).toLocal(),
        subject: map['subject'] as String,
      );

  /// Split at local midnight, retaining the actual duration without rounding
  /// short sessions up to the manual entry minimum of fifteen minutes.
  List<StudyEntry> entriesFor(String title) {
    final end = stoppedAt?.toLocal();
    if (end == null || !end.isAfter(startedAt)) {
      throw StateError('The timer must be stopped after it starts.');
    }
    final entries = <StudyEntry>[];
    var cursor = startedAt.toLocal();
    while (cursor.isBefore(end)) {
      final midnight = DateTime(cursor.year, cursor.month, cursor.day + 1);
      final boundary = midnight.isBefore(end) ? midnight : end;
      entries.add(StudyEntry(
        workspaceId: workspaceId,
        entryDate: '${cursor.year.toString().padLeft(4, '0')}-'
            '${cursor.month.toString().padLeft(2, '0')}-'
            '${cursor.day.toString().padLeft(2, '0')}',
        title: title.trim(),
        hours: boundary.difference(cursor).inMicroseconds /
            Duration.microsecondsPerHour,
      ));
      cursor = boundary;
    }
    return entries;
  }
}

String formatTimerDuration(Duration duration) {
  final hours = duration.inHours.toString().padLeft(2, '0');
  final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
  final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
  return '$hours:$minutes:$seconds';
}
