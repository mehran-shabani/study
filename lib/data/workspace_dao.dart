import 'package:sqflite/sqflite.dart';
import 'database.dart';
import 'models.dart';

/// Data Access Object for Workspace operations
class WorkspaceDao {
  /// Get all workspaces
  Future<List<Workspace>> getAll() async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'workspaces',
      orderBy: 'start_date DESC',
    );
    return maps.map((map) => Workspace.fromMap(map)).toList();
  }

  /// Get workspace by ID
  Future<Workspace?> getById(int id) async {
    final db = await DatabaseService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'workspaces',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return Workspace.fromMap(maps.first);
  }

  /// Insert a new workspace
  Future<int> insert(Workspace workspace) async {
    final db = await DatabaseService.database;
    return await db.insert(
      'workspaces',
      workspace.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update an existing workspace
  Future<int> update(Workspace workspace) async {
    final db = await DatabaseService.database;
    return await db.update(
      'workspaces',
      workspace.toMap(),
      where: 'id = ?',
      whereArgs: [workspace.id],
    );
  }

  /// Delete a workspace by ID
  Future<int> delete(int id) async {
    final db = await DatabaseService.database;
    return await db.delete(
      'workspaces',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Count total workspaces
  Future<int> count() async {
    final db = await DatabaseService.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM workspaces');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
