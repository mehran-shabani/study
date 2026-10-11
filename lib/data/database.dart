import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../core/constants.dart';

/// Database service for managing SQLite operations
class DatabaseService {
  static Database? _database;

  /// Get the database instance (singleton pattern)
  static Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Initialize the database
  static Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);

    return await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );
  }

  /// Enable foreign key constraints
  static Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  /// Create database tables
  static Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE workspaces (
        id           INTEGER PRIMARY KEY AUTOINCREMENT,
        name         TEXT    NOT NULL,
        start_date   TEXT    NOT NULL,
        end_date     TEXT    NOT NULL,
        daily_target_hours REAL NOT NULL DEFAULT 4.0
          CHECK (daily_target_hours >= 0.25 AND daily_target_hours <= 24.0)
      )
    ''');

    await db.execute('''
      CREATE TABLE study_entries (
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id  INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
        entry_date    TEXT    NOT NULL,
        title         TEXT    NOT NULL,
        hours         REAL    NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_entries_workspace_date 
      ON study_entries(workspace_id, entry_date)
    ''');
  }

  /// Preserve existing workspaces and entries when adding configurable targets.
  static Future<void> _onUpgrade(
      Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        ALTER TABLE workspaces ADD COLUMN daily_target_hours REAL NOT NULL
          DEFAULT 4.0 CHECK (daily_target_hours >= 0.25 AND daily_target_hours <= 24.0)
      ''');
    }
  }

  /// Close the database
  static Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  /// Reset database (for testing purposes)
  static Future<void> reset() async {
    await close();
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, AppConstants.dbName);
    await deleteDatabase(path);
  }
}
