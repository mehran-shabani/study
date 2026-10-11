import '../core/utils.dart';
import '../data/models.dart';

/// Excel-compatible UTF-8 CSV, one row per session in chronological order.
String buildStudyCsv(Workspace workspace, List<StudyEntry> entries) {
  final sorted = entries.where((e) => e.workspaceId == workspace.id).toList()
    ..sort((a, b) {
      final dateOrder = a.entryDate.compareTo(b.entryDate);
      return dateOrder != 0 ? dateOrder : (a.id ?? 0).compareTo(b.id ?? 0);
    });
  final rows = <List<String>>[
    [
      'workspace',
      'date_jalali',
      'date_iso',
      'title',
      'hours',
      'daily_target_hours'
    ],
    for (final entry in sorted)
      [
        workspace.name,
        AppUtils.displayDate(entry.entryDate),
        entry.entryDate,
        entry.title,
        entry.hours.toString(),
        workspace.dailyTargetHours.toString(),
      ],
  ];
  return '\uFEFF${rows.map((row) => row.map(_escapeCell).join(',')).join('\r\n')}\r\n';
}

String _escapeCell(String value) {
  // Prevent spreadsheet applications from interpreting user text as formulas.
  if (RegExp(r'^[=+@\-\t\r\n]').hasMatch(value.trimLeft()) ||
      RegExp(r'^[\t\r\n]').hasMatch(value)) {
    value = "'$value";
  }
  return '"${value.replaceAll('"', '""')}"';
}
