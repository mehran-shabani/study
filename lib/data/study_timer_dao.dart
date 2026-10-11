import 'database.dart';
import 'study_timer.dart';

class StudyTimerDao {
  Future<StudyTimerSession?> load() async {
    final rows = await (await DatabaseService.database).query('study_timer');
    return rows.isEmpty ? null : StudyTimerSession.fromMap(rows.single);
  }

  Future<void> start(StudyTimerSession session) async {
    await (await DatabaseService.database)
        .insert('study_timer', session.toMap());
  }

  Future<void> update(StudyTimerSession session) async {
    final changed = await (await DatabaseService.database).update(
      'study_timer',
      session.toMap(),
      where: 'id = 1 AND started_at = ?',
      whereArgs: [session.toMap()['started_at']],
    );
    if (changed != 1) throw StateError('Timer session no longer exists.');
  }

  /// Entries and clearing the pending timer commit together. Retrying after a
  /// failure cannot leave half a midnight-spanning session or duplicate it.
  Future<void> finish(StudyTimerSession session, String title) async {
    final entries = session.entriesFor(title);
    final db = await DatabaseService.database;
    await db.transaction((transaction) async {
      final removed = await transaction.delete(
        'study_timer',
        where: 'id = 1 AND started_at = ? AND stopped_at = ?',
        whereArgs: [
          session.toMap()['started_at'],
          session.toMap()['stopped_at'],
        ],
      );
      if (removed != 1) throw StateError('Timer session no longer exists.');
      for (final entry in entries) {
        await transaction.insert('study_entries', entry.toMap());
      }
    });
  }
}
