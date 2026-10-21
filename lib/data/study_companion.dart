import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'database.dart';

const studyMethods = ['read', 'recall', 'questions', 'case'];

class MedicalCourse {
  const MedicalCourse({
    required this.id,
    required this.name,
    this.priority = 2,
    this.examDate,
  });
  final String id;
  final String name;
  final int priority;
  final String? examDate;
  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'priority': priority,
    'examDate': examDate,
  };
  factory MedicalCourse.fromMap(Map<String, dynamic> map) => MedicalCourse(
    id: _text(map['id'], 100),
    name: _text(map['name'], 60),
    priority: map['priority'] is int && [1, 2, 3].contains(map['priority'])
        ? map['priority'] as int
        : 2,
    examDate: map['examDate'] == null ? null : _date(map['examDate']),
  );
}

class DailyTask {
  const DailyTask({
    required this.id,
    required this.subject,
    required this.title,
    this.minutes = 25,
    this.method = 'read',
    this.done = false,
  });
  final String id;
  final String subject;
  final String title;
  final int minutes;
  final String method;
  final bool done;
  DailyTask toggle() => DailyTask(
    id: id,
    subject: subject,
    title: title,
    minutes: minutes,
    method: method,
    done: !done,
  );
  Map<String, Object?> toMap() => {
    'id': id,
    'subject': subject,
    'title': title,
    'minutes': minutes,
    'method': method,
    'done': done,
  };
  factory DailyTask.fromMap(Map<String, dynamic> map) => DailyTask(
    id: _text(map['id'], 100),
    subject: _text(map['subject'], 60),
    title: _text(map['title'], 80),
    minutes: map['minutes'] is int && [15, 25, 50].contains(map['minutes'])
        ? map['minutes'] as int
        : 25,
    method: studyMethods.contains(map['method'])
        ? map['method'] as String
        : 'read',
    done: map['done'] == true,
  );
}

class CompanionDay {
  const CompanionDay({
    this.energy = 2,
    this.tasks = const [],
    this.reflection = '',
    this.tomorrow = '',
  });
  final int energy;
  final List<DailyTask> tasks;
  final String reflection;
  final String tomorrow;
  CompanionDay copyWith({
    int? energy,
    List<DailyTask>? tasks,
    String? reflection,
    String? tomorrow,
  }) => CompanionDay(
    energy: energy ?? this.energy,
    tasks: tasks ?? this.tasks,
    reflection: reflection ?? this.reflection,
    tomorrow: tomorrow ?? this.tomorrow,
  );
  Map<String, Object?> toMap() => {
    'energy': energy,
    'tasks': tasks.map((t) => t.toMap()).toList(),
    'reflection': reflection,
    'tomorrow': tomorrow,
  };
  factory CompanionDay.fromMap(Map<String, dynamic> map) => CompanionDay(
    energy: [1, 2, 3].contains(map['energy']) ? map['energy'] as int : 2,
    tasks: _maps(map['tasks']).map(DailyTask.fromMap).toList(),
    reflection: _text(map['reflection'] ?? '', 1000, empty: true),
    tomorrow: _text(map['tomorrow'] ?? '', 1000, empty: true),
  );
}

/// One independent companion per study plan. No sample progress is persisted.
class CompanionPlan {
  const CompanionPlan({
    this.stage = 'basic',
    this.courses = const [],
    this.selectedCourseId,
    this.days = const {},
  });
  final String stage;
  final List<MedicalCourse> courses;
  final String? selectedCourseId;
  final Map<String, CompanionDay> days;
  MedicalCourse? get selectedCourse {
    for (final course in courses) {
      if (course.id == selectedCourseId) return course;
    }
    return courses.isEmpty ? null : courses.first;
  }

  CompanionDay day(String date) => days[date] ?? const CompanionDay();

  /// Merge a backup without replacing existing course preferences or notes.
  /// Stable task IDs make repeated imports idempotent.
  CompanionPlan merge(CompanionPlan incoming) {
    final mergedCourses = {
      for (final c in incoming.courses) c.id: c,
      for (final c in courses) c.id: c,
    };
    final mergedDays = {...incoming.days, ...days};
    for (final date in incoming.days.keys.where(days.containsKey)) {
      final current = days[date]!;
      final other = incoming.days[date]!;
      mergedDays[date] = current.copyWith(
        tasks: {
          for (final t in other.tasks) t.id: t,
          for (final t in current.tasks) t.id: t,
        }.values.toList(),
        reflection: current.reflection.isEmpty
            ? other.reflection
            : current.reflection,
        tomorrow: current.tomorrow.isEmpty ? other.tomorrow : current.tomorrow,
      );
    }
    return CompanionPlan(
      stage: courses.isEmpty ? incoming.stage : stage,
      courses: mergedCourses.values.toList(),
      selectedCourseId: selectedCourseId ?? incoming.selectedCourseId,
      days: mergedDays,
    );
  }

  CompanionPlan copyWith({
    String? stage,
    List<MedicalCourse>? courses,
    String? selectedCourseId,
    Map<String, CompanionDay>? days,
  }) => CompanionPlan(
    stage: stage ?? this.stage,
    courses: courses ?? this.courses,
    selectedCourseId: selectedCourseId ?? this.selectedCourseId,
    days: days ?? this.days,
  );
  CompanionPlan withDay(String date, CompanionDay value) =>
      copyWith(days: {...days, date: value});
  Map<String, Object?> toMap() => {
    'stage': stage,
    'courses': courses.map((c) => c.toMap()).toList(),
    'selectedCourseId': selectedCourseId,
    'days': days.map((date, day) => MapEntry(date, day.toMap())),
  };
  factory CompanionPlan.fromMap(Map<String, dynamic> map) {
    final rawDays = map['days'];
    if (rawDays != null && rawDays is! Map<String, dynamic>) {
      throw const FormatException('Invalid companion days');
    }
    final courses = _maps(map['courses']).map(MedicalCourse.fromMap).toList();
    if (courses.map((c) => c.id).toSet().length != courses.length) {
      throw const FormatException('Duplicate course');
    }
    return CompanionPlan(
      stage: ['basic', 'clinical', 'intern'].contains(map['stage'])
          ? map['stage'] as String
          : 'basic',
      courses: courses,
      selectedCourseId: map['selectedCourseId'] is String
          ? map['selectedCourseId'] as String
          : null,
      days: (rawDays as Map<String, dynamic>? ?? {}).map((date, raw) {
        if (raw is! Map<String, dynamic>) {
          throw const FormatException('Invalid companion day');
        }
        return MapEntry(_date(date), CompanionDay.fromMap(raw));
      }),
    );
  }
}

List<Map<String, dynamic>> _maps(Object? raw) {
  if (raw == null) return [];
  if (raw is! List || raw.any((v) => v is! Map<String, dynamic>)) {
    throw const FormatException('Invalid companion list');
  }
  return raw.cast<Map<String, dynamic>>();
}

String _text(Object? raw, int max, {bool empty = false}) {
  if (raw is! String || raw.length > max || (!empty && raw.trim().isEmpty)) {
    throw const FormatException('Invalid companion text');
  }
  return raw;
}

String _date(Object? raw) {
  if (raw is! String ||
      !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw) ||
      DateTime.tryParse(raw)?.toIso8601String().substring(0, 10) != raw) {
    throw const FormatException('Invalid companion date');
  }
  return raw;
}

class CompanionRepository {
  Future<CompanionPlan> load(int workspaceId) async {
    final db = await DatabaseService.database;
    final rows = await db.query(
      'study_companion',
      where: 'workspace_id = ?',
      whereArgs: [workspaceId],
    );
    return rows.isEmpty
        ? const CompanionPlan()
        : CompanionPlan.fromMap(
            jsonDecode(rows.single['value'] as String) as Map<String, dynamic>,
          );
  }

  Future<void> save(int workspaceId, CompanionPlan plan) async {
    final db = await DatabaseService.database;
    await db.insert('study_companion', {
      'workspace_id': workspaceId,
      'value': jsonEncode(plan.toMap()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

class CompanionState {
  const CompanionState({
    this.plan = const CompanionPlan(),
    this.loading = false,
    this.busy = false,
    this.error,
    this.loadFailed = false,
  });
  final CompanionPlan plan;
  final bool loading;
  final bool busy;
  final Object? error;
  final bool loadFailed;
}

final companionRepositoryProvider = Provider((ref) => CompanionRepository());
final companionProvider =
    StateNotifierProvider.family<CompanionController, CompanionState, int>(
      (ref, id) =>
          CompanionController(ref.watch(companionRepositoryProvider), id),
    );

/// Also used by the manual-entry dialog; the actual timer stores its own subject.
final selectedStudySubjectProvider = StateProvider.family<String, int>(
  (ref, id) => '',
);

class CompanionController extends StateNotifier<CompanionState> {
  CompanionController(this.repository, this.workspaceId)
    : super(const CompanionState()) {
    ready = load();
  }
  final CompanionRepository repository;
  final int workspaceId;
  late final Future<void> ready;
  Future<void> load() async {
    if (state.loading || state.busy) return;
    state = CompanionState(plan: state.plan, loading: true);
    try {
      final plan = await repository.load(workspaceId);
      if (mounted) state = CompanionState(plan: plan);
    } catch (error) {
      if (mounted) {
        state = CompanionState(
          plan: state.plan,
          error: error,
          loadFailed: true,
        );
      }
    }
  }

  Future<bool> update(CompanionPlan Function(CompanionPlan) change) async {
    if (state.loading || state.busy || state.loadFailed) return false;
    final previous = state.plan;
    state = CompanionState(plan: previous, busy: true);
    try {
      final next = CompanionPlan.fromMap(change(previous).toMap());
      await repository.save(workspaceId, next);
      if (mounted) state = CompanionState(plan: next);
      return true;
    } catch (error) {
      if (mounted) state = CompanionState(plan: previous, error: error);
      return false;
    }
  }
}
