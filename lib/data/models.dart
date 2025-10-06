/// Data models for the Study app
class Workspace {
  final int? id;
  final String name;
  final String startDate; // yyyy-MM-dd
  final String endDate; // yyyy-MM-dd

  const Workspace({
    this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'start_date': startDate,
      'end_date': endDate,
    };
  }

  factory Workspace.fromMap(Map<String, dynamic> map) {
    return Workspace(
      id: map['id'] as int?,
      name: map['name'] as String,
      startDate: map['start_date'] as String,
      endDate: map['end_date'] as String,
    );
  }

  Workspace copyWith({
    int? id,
    String? name,
    String? startDate,
    String? endDate,
  }) {
    return Workspace(
      id: id ?? this.id,
      name: name ?? this.name,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
    );
  }

  @override
  String toString() {
    return 'Workspace{id: $id, name: $name, startDate: $startDate, endDate: $endDate}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Workspace &&
        other.id == id &&
        other.name == name &&
        other.startDate == startDate &&
        other.endDate == endDate;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, startDate, endDate);
  }
}

class StudyEntry {
  final int? id;
  final int workspaceId;
  final String entryDate; // yyyy-MM-dd
  final String title;
  final double hours;

  const StudyEntry({
    this.id,
    required this.workspaceId,
    required this.entryDate,
    required this.title,
    required this.hours,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'workspace_id': workspaceId,
      'entry_date': entryDate,
      'title': title,
      'hours': hours,
    };
  }

  factory StudyEntry.fromMap(Map<String, dynamic> map) {
    return StudyEntry(
      id: map['id'] as int?,
      workspaceId: map['workspace_id'] as int,
      entryDate: map['entry_date'] as String,
      title: map['title'] as String,
      hours: map['hours'] as double,
    );
  }

  StudyEntry copyWith({
    int? id,
    int? workspaceId,
    String? entryDate,
    String? title,
    double? hours,
  }) {
    return StudyEntry(
      id: id ?? this.id,
      workspaceId: workspaceId ?? this.workspaceId,
      entryDate: entryDate ?? this.entryDate,
      title: title ?? this.title,
      hours: hours ?? this.hours,
    );
  }

  @override
  String toString() {
    return 'StudyEntry{id: $id, workspaceId: $workspaceId, entryDate: $entryDate, title: $title, hours: $hours}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is StudyEntry &&
        other.id == id &&
        other.workspaceId == workspaceId &&
        other.entryDate == entryDate &&
        other.title == title &&
        other.hours == hours;
  }

  @override
  int get hashCode {
    return Object.hash(id, workspaceId, entryDate, title, hours);
  }
}
