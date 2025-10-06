import 'package:sqflite/sqflite.dart';
import 'database.dart';
import 'models.dart';

/// Data Access Object for StudyEntry operations
class StudyEntryDao {
  /// Get all entries for a workspace
  Future<List<StudyEntry>> getByWorkspace(int workspaceId) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'study_entries',
      where: 'workspace_id = ?',
      whereArgs: [workspaceId],
      orderBy: 'entry_date DESC, id DESC',
    );
    return maps.map((map) => StudyEntry.fromMap(map)).toList();
  }

  /// Get entries for a workspace by date
  Future<List<StudyEntry>> getByWorkspaceAndDate(
    int workspaceId,
    String date,
  ) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'study_entries',
      where: 'workspace_id = ? AND entry_date = ?',
      whereArgs: [workspaceId, date],
      orderBy: 'id DESC',
    );
    return maps.map((map) => StudyEntry.fromMap(map)).toList();
  }

  /// Get entry by ID
  Future<StudyEntry?> getById(int id) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'study_entries',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return StudyEntry.fromMap(maps.first);
  }

  /// Insert a new entry
  Future<int> insert(StudyEntry entry) async {
    final db = await DatabaseService.database;
    return await db.insert(
      'study_entries',
      entry.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update an existing entry
  Future<int> update(StudyEntry entry) async {
    final db = await DatabaseService.database;
    return await db.update(
      'study_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  /// Delete an entry by ID
  Future<int> delete(int id) async {
    final db = await DatabaseService.database;
    return await db.delete(
      'study_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete all entries for a workspace
  Future<int> deleteByWorkspace(int workspaceId) async {
    final db = await DatabaseService.database;
    return await db.delete(
      'study_entries',
      where: 'workspace_id = ?',
      whereArgs: [workspaceId],
    );
  }

  /// Count total entries for a workspace
  Future<int> countByWorkspace(int workspaceId) async {
    final db = await DatabaseService.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM study_entries WHERE workspace_id = ?',
      [workspaceId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
