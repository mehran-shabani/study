import '../core/constants.dart';
import '../core/utils.dart';
import '../data/models.dart';

/// Point on the daily timeline chart
class DailyPoint {
  final String date;
  final double hours;

  const DailyPoint({
    required this.date,
    required this.hours,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DailyPoint && other.date == date && other.hours == hours;
  }

  @override
  int get hashCode => Object.hash(date, hours);
}

/// Calculate progress percentage (0-100) based on actual vs expected hours
/// Formula: (sum of hours) / (days in workspace × avgDailyTarget) × 100
double calcProgress(List<StudyEntry> entries, Workspace workspace) {
  if (entries.isEmpty) return 0.0;

  final totalHours = entries.fold<double>(
    0.0,
    (sum, entry) => sum + entry.hours,
  );

  final startDate = AppUtils.parseDate(workspace.startDate);
  final endDate = AppUtils.parseDate(workspace.endDate);
  final days = AppUtils.daysBetween(startDate, endDate);

  final expectedHours = days * AppConstants.avgDailyTargetHours;

  if (expectedHours == 0) return 0.0;

  final progress = (totalHours / expectedHours) * 100;
  return progress.clamp(0.0, 100.0);
}

/// Build a timeline covering every calendar day in the workspace range
/// Maps each date to total logged hours (default 0)
List<DailyPoint> buildTimeline(List<StudyEntry> entries, Workspace workspace) {
  final startDate = AppUtils.parseDate(workspace.startDate);
  final endDate = AppUtils.parseDate(workspace.endDate);

  // Create a map of date -> total hours
  final Map<String, double> hoursMap = {};

  // Initialize all dates with 0
  DateTime currentDate = startDate;
  while (
      currentDate.isBefore(endDate) || currentDate.isAtSameMomentAs(endDate)) {
    hoursMap[AppUtils.formatDate(currentDate)] = 0.0;
    currentDate = currentDate.add(const Duration(days: 1));
  }

  // Fill in actual hours from entries
  for (final entry in entries) {
    if (hoursMap.containsKey(entry.entryDate)) {
      hoursMap[entry.entryDate] = hoursMap[entry.entryDate]! + entry.hours;
    }
  }

  // Convert to sorted list of DailyPoints
  final points = hoursMap.entries
      .map((e) => DailyPoint(date: e.key, hours: e.value))
      .toList();

  // Sort by date
  points.sort((a, b) => a.date.compareTo(b.date));

  return points;
}

/// Aggregate total hours by title across all entries
/// Returns a map of title -> total hours, sorted by hours descending
Map<String, double> aggHoursByTitle(List<StudyEntry> entries) {
  final Map<String, double> titleHours = {};

  for (final entry in entries) {
    titleHours[entry.title] = (titleHours[entry.title] ?? 0.0) + entry.hours;
  }

  // Convert to sorted list and back to map (to maintain order)
  final sortedEntries = titleHours.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  return Map.fromEntries(sortedEntries);
}
