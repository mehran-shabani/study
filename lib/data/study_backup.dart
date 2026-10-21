import 'dart:convert';
import 'package:flutter/services.dart';
import 'database.dart';
import 'study_companion.dart';
import 'package:sqflite/sqflite.dart';

class StudyBackup {
  static const channel = MethodChannel('study/files');
  static const maxFileBytes = 20 * 1024 * 1024;

  Future<String> exportJson() async {
    final db = await DatabaseService.database;
    return db.transaction((tx) async {
      if ((await tx.query('study_timer')).isNotEmpty) {
        throw StateError('Finish or discard the pending timer first.');
      }
      return jsonEncode({
        'format': 'study-backup',
        'version': 1,
        'createdAt': DateTime.now().toUtc().toIso8601String(),
        'workspaces': await tx.query('workspaces'),
        'entries': await tx.query('study_entries'),
        'companions': await tx.query('study_companion'),
      });
    });
  }

  Future<bool> save() async {
    final content = await exportJson();
    return await channel.invokeMethod<bool>('save', {
          'name': 'study-backup-${DateTime.now().millisecondsSinceEpoch}.json',
          'content': content,
        }) ??
        false;
  }

  Future<String?> chooseFile() => channel.invokeMethod<String>('open');

  /// Merge transactionally; repeated imports do not duplicate saved sessions.
  Future<int> importText(String text) async {
    final data = decode(text);
    final db = await DatabaseService.database;
    return db.transaction((tx) async {
      if ((await tx.query('study_timer')).isNotEmpty) {
        throw StateError('Finish or discard the pending timer first.');
      }
      final existingPlans = List<Map<String, Object?>>.of(
        await tx.query('workspaces'),
      );
      final existingEntries = await tx.query('study_entries');
      final ids = <int, int>{};
      final usedPlanIds = <int>{};
      for (final plan in data.workspaces) {
        final matches = existingPlans.where(
          (old) =>
              !usedPlanIds.contains(old['id']) &&
              old['name'] == plan['name'] &&
              old['start_date'] == plan['start_date'] &&
              old['end_date'] == plan['end_date'] &&
              (old['daily_target_hours'] as num).toDouble() ==
                  (plan['daily_target_hours'] as num).toDouble(),
        );
        int id;
        if (matches.isNotEmpty) {
          id = matches.first['id'] as int;
        } else {
          final inserted = Map<String, Object?>.from(plan)..remove('id');
          id = await tx.insert('workspaces', inserted);
          existingPlans.add({...inserted, 'id': id});
        }
        ids[plan['id'] as int] = id;
        usedPlanIds.add(id);
      }
      final signatures = <String, int>{};
      for (final entry in existingEntries) {
        final key = _signature(entry);
        signatures[key] = (signatures[key] ?? 0) + 1;
      }
      final occurrences = <String, int>{};
      var count = 0;
      for (final entry in data.entries) {
        final row = Map<String, Object?>.from(entry)
          ..remove('id')
          ..['workspace_id'] = ids[entry['workspace_id'] as int];
        final key = _signature(row);
        occurrences[key] = (occurrences[key] ?? 0) + 1;
        if (occurrences[key]! > (signatures[key] ?? 0)) {
          await tx.insert('study_entries', row);
          count++;
        }
      }
      for (final item in data.companions.entries) {
        final id = ids[item.key]!;
        final rows = await tx.query(
          'study_companion',
          where: 'workspace_id = ?',
          whereArgs: [id],
        );
        final current = rows.isEmpty
            ? const CompanionPlan()
            : CompanionPlan.fromMap(
                jsonDecode(rows.single['value'] as String)
                    as Map<String, dynamic>,
              );
        await tx.insert('study_companion', {
          'workspace_id': id,
          'value': jsonEncode(current.merge(item.value).toMap()),
        }, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      return count;
    });
  }

  static String _signature(Map<String, Object?> entry) => jsonEncode([
    entry['workspace_id'],
    entry['entry_date'],
    entry['title'],
    (entry['hours'] as num).toDouble(),
  ]);

  static BackupData decode(String input) {
    if (utf8.encode(input).length > maxFileBytes) {
      throw const FormatException('Backup is too large.');
    }
    final text = input.replaceFirst(RegExp(r'^\uFEFF'), '').trim();
    if (!text.startsWith('{')) return _decodeCsv(text);
    final json = jsonDecode(text);
    if (json is! Map ||
        json['format'] != 'study-backup' ||
        json['version'] != 1 ||
        json['workspaces'] is! List ||
        json['entries'] is! List) {
      throw const FormatException('Unsupported backup format.');
    }
    final plans = <Map<String, Object?>>[];
    final ids = <int>{};
    for (final raw in json['workspaces']) {
      if (raw is! Map ||
          raw['id'] is! int ||
          (raw['id'] as int) <= 0 ||
          !ids.add(raw['id'] as int)) {
        throw const FormatException('Invalid workspace ID.');
      }
      plans.add(_plan(raw));
    }
    final entries = <Map<String, Object?>>[];
    for (final raw in json['entries']) {
      if (raw is! Map || !ids.contains(raw['workspace_id'])) {
        throw const FormatException('Invalid study workspace.');
      }
      entries.add(_entry(raw));
    }
    final companions = <int, CompanionPlan>{};
    final rawCompanions = json['companions'];
    if (rawCompanions != null) {
      if (rawCompanions is! List) {
        throw const FormatException('Invalid companions');
      }
      for (final raw in rawCompanions) {
        if (raw is! Map ||
            raw['workspace_id'] is! int ||
            !ids.contains(raw['workspace_id']) ||
            raw['value'] is! String ||
            companions.containsKey(raw['workspace_id'])) {
          throw const FormatException('Invalid companion workspace');
        }
        final value = jsonDecode(raw['value'] as String);
        if (value is! Map<String, dynamic>) {
          throw const FormatException('Invalid companion');
        }
        companions[raw['workspace_id'] as int] = CompanionPlan.fromMap(value);
      }
    }
    return BackupData(plans, entries, companions);
  }

  static Map<String, Object?> _plan(Map raw) {
    final name = _label(raw['name'], 50);
    final start = _date(raw['start_date']);
    final end = _date(raw['end_date']);
    final target = raw['daily_target_hours'];
    if (end.compareTo(start) < 0 ||
        target is! num ||
        !target.isFinite ||
        target < 0.25 ||
        target > 24) {
      throw const FormatException('Invalid workspace dates or target.');
    }
    return {
      'id': raw['id'],
      'name': name,
      'start_date': start,
      'end_date': end,
      'daily_target_hours': target.toDouble(),
    };
  }

  static Map<String, Object?> _entry(Map raw) {
    final hours = raw['hours'];
    if (hours is! num || !hours.isFinite || hours <= 0 || hours > 24) {
      throw const FormatException('Invalid study duration.');
    }
    return {
      'workspace_id': raw['workspace_id'],
      'entry_date': _date(raw['entry_date']),
      'title': _label(raw['title'], 80),
      'hours': hours.toDouble(),
    };
  }

  static String _label(Object? value, int max) {
    if (value is! String || value.trim().isEmpty || value.length > max) {
      throw const FormatException('Invalid label.');
    }
    return value;
  }

  static String _date(Object? value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      throw const FormatException('Invalid date.');
    }
    final parsed = DateTime.tryParse(value);
    if (parsed == null || parsed.toIso8601String().substring(0, 10) != value) {
      throw const FormatException('Invalid date.');
    }
    return value;
  }

  /// Existing releases export one plan per CSV. The original plan date range
  /// is absent, so use the earliest/latest logged day (explained in the UI).
  static BackupData _decodeCsv(String text) {
    final rows = _csvRows(text);
    const header = [
      'workspace',
      'date_jalali',
      'date_iso',
      'title',
      'hours',
      'daily_target_hours',
    ];
    if (rows.isEmpty || jsonEncode(rows.first) != jsonEncode(header)) {
      throw const FormatException('Unsupported CSV.');
    }
    final grouped = <String, List<Map<String, Object?>>>{};
    final targets = <String, double>{};
    for (final row in rows.skip(1)) {
      if (row.length != 6) throw const FormatException('Invalid CSV row.');
      final name = _label(row[0], 50);
      final target = double.tryParse(row[5]);
      if (target == null ||
          !target.isFinite ||
          target < 0.25 ||
          target > 24 ||
          (targets.containsKey(name) && targets[name] != target)) {
        throw const FormatException('Invalid CSV target.');
      }
      targets[name] = target;
      grouped
          .putIfAbsent(name, () => [])
          .add(
            _entry({
              'entry_date': row[2],
              'title': row[3],
              'hours': double.tryParse(row[4]),
            }),
          );
    }
    if (grouped.isEmpty) {
      throw const FormatException('CSV contains no sessions.');
    }
    final plans = <Map<String, Object?>>[];
    final entries = <Map<String, Object?>>[];
    for (final group in grouped.entries) {
      final id = plans.length + 1;
      final dates =
          group.value.map((row) => row['entry_date'] as String).toList()
            ..sort();
      plans.add(
        _plan({
          'id': id,
          'name': group.key,
          'start_date': dates.first,
          'end_date': dates.last,
          'daily_target_hours': targets[group.key],
        }),
      );
      entries.addAll(
        group.value.map((entry) => {...entry, 'workspace_id': id}),
      );
    }
    return BackupData(plans, entries);
  }

  static List<List<String>> _csvRows(String text) {
    final rows = <List<String>>[];
    var row = <String>[];
    var field = StringBuffer();
    var quoted = false;
    var closed = false;
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      if (quoted) {
        if (char == '"') {
          if (i + 1 < text.length && text[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            quoted = false;
            closed = true;
          }
        } else {
          field.write(char);
        }
      } else if (char == '"' && field.isEmpty && !closed) {
        quoted = true;
      } else if (char == ',' || char == '\n' || char == '\r') {
        row.add(field.toString());
        field = StringBuffer();
        closed = false;
        if (char != ',') {
          rows.add(row);
          row = [];
          if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
        }
      } else {
        if (closed || char == '"') {
          throw const FormatException('Malformed CSV.');
        }
        field.write(char);
      }
    }
    if (quoted) throw const FormatException('Unclosed CSV quote.');
    if (field.isNotEmpty || row.isNotEmpty || closed) {
      row.add(field.toString());
      rows.add(row);
    }
    return rows;
  }
}

class BackupData {
  const BackupData(this.workspaces, this.entries, [this.companions = const {}]);
  final List<Map<String, Object?>> workspaces;
  final List<Map<String, Object?>> entries;
  final Map<int, CompanionPlan> companions;
}
