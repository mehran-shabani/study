import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../core/constants.dart';

/// Database service for managing SQLite operations
class DatabaseService {
  static Database? _database;
  static Future<Database>? _opening;

  /// Get the database instance (singleton pattern)
  static Future<Database> get database async {
    if (_database != null) return _database!;
    final opening = _opening ??= _initDatabase();
    try {
      return _database = await opening;
    } finally {
      if (identical(_opening, opening)) _opening = null;
    }
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
    await _createTimerTable(db);
    await _addTimerIntervals(db);
    await _addFocusColumns(db);
    await _createSettingsTable(db);
    await _createCompanionTable(db);
  }

  static Future<void> _createCompanionTable(Database db) => db.execute('''
    CREATE TABLE study_companion (
      workspace_id INTEGER PRIMARY KEY REFERENCES workspaces(id) ON DELETE CASCADE,
      value TEXT NOT NULL
    )
  ''');

  static Future<void> _createSettingsTable(Database db) => db.execute('''
    CREATE TABLE app_settings (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      value TEXT NOT NULL
    )
  ''');

  static Future<void> _createTimerTable(Database db) async {
    await db.execute('''
      CREATE TABLE study_timer (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        workspace_id INTEGER NOT NULL REFERENCES workspaces(id) ON DELETE RESTRICT,
        workspace_name TEXT NOT NULL,
        started_at TEXT NOT NULL,
        stopped_at TEXT,
        subject TEXT NOT NULL DEFAULT ''
      )
    ''');
  }

  static Future<void> _addTimerIntervals(Database db) async {
    await db.execute('ALTER TABLE study_timer ADD COLUMN paused_at TEXT');
    await db.execute('ALTER TABLE study_timer ADD COLUMN active_since TEXT');
    await db.execute(
      "ALTER TABLE study_timer ADD COLUMN intervals TEXT NOT NULL DEFAULT '[]'",
    );
  }

  /// Preserve existing workspaces and entries when adding configurable targets.
  static Future<void> _addFocusColumns(Database db) async {
    await db.execute(
      'ALTER TABLE study_timer ADD COLUMN focus_minutes INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE study_timer ADD COLUMN break_minutes INTEGER NOT NULL DEFAULT 5',
    );
    await db.execute(
      'ALTER TABLE study_timer ADD COLUMN focus_target_ms INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute(
      'ALTER TABLE study_timer ADD COLUMN rounds_completed INTEGER NOT NULL DEFAULT 0',
    );
    await db.execute('ALTER TABLE study_timer ADD COLUMN break_ends_at TEXT');
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('''
        ALTER TABLE workspaces ADD COLUMN daily_target_hours REAL NOT NULL
          DEFAULT 4.0 CHECK (daily_target_hours >= 0.25 AND daily_target_hours <= 24.0)
      ''');
    }
    if (oldVersion < 3) await _createTimerTable(db);
    if (oldVersion < 4) await _addTimerIntervals(db);
    if (oldVersion < 5) await _addFocusColumns(db);
    if (oldVersion < 6) await _createSettingsTable(db);
    if (oldVersion < 7) await _createCompanionTable(db);
  }

  /// Close the database
  static Future<void> close() async {
    final db = _database ?? await _opening;
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
