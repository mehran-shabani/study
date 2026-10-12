import 'dart:math' as math;
import '../core/utils.dart';
import '../data/models.dart';

/// Calendar arithmetic uses UTC dates to avoid daylight-saving gaps.
DateTime _day(DateTime date) => DateTime.utc(date.year, date.month, date.day);
DateTime _parse(String value) => _day(AppUtils.parseDate(value));

class StudyWeek {
  const StudyWeek(this.days, this.target);
  final List<DailyStudy> days;
  final double target;
  double get hours => days.fold(0, (sum, day) => sum + day.hours);
  int get activeDays => days.where((day) => day.hours > 0).length;
  int get goalDays => days.where((day) => day.hours >= target).length;
  double get average => days.isEmpty ? 0 : hours / days.length;
}

class DailyStudy {
  const DailyStudy(this.date, this.hours);
  final String date;
  final double hours;
}

class ReviewSubject {
  const ReviewSubject(this.title, this.lastDate, this.daysAgo);
  final String title;
  final String lastDate;
  final int daysAgo;
}

class TomorrowPlan {
  const TomorrowPlan(
    this.totalMinutes,
    this.reviewMinutes,
    this.reviewTitle,
    this.focusTitle,
  );
  final int totalMinutes;
  final int reviewMinutes;
  final String? reviewTitle;
  final String? focusTitle;
  int get focusMinutes => totalMinutes - reviewMinutes;
}

/// Insights describe logged time, never inferred knowledge or exam readiness.
class StudyInsights {
  StudyInsights(List<StudyEntry> entries, this.workspace, DateTime now)
    : today = _day(now) {
    start = _parse(workspace.startDate);
    end = _parse(workspace.endDate);
    tomorrow = today.add(const Duration(days: 1));
    final subjects = <String, DateTime>{};
    for (final entry in entries) {
      if (entry.workspaceId != workspace.id ||
          !entry.hours.isFinite ||
          entry.hours <= 0) {
        continue;
      }
      final date = _parse(entry.entryDate);
      if (date.isBefore(start) || date.isAfter(end) || date.isAfter(today)) {
        continue;
      }
      hoursByDate.update(
        entry.entryDate,
        (hours) => hours + entry.hours,
        ifAbsent: () => entry.hours,
      );
      final title = entry.title.trim();
      if (title.isNotEmpty &&
          (subjects[title] == null || date.isAfter(subjects[title]!))) {
        subjects[title] = date;
      }
    }
    reviewSubjects =
        subjects.entries
            .map(
              (entry) => ReviewSubject(
                entry.key,
                AppUtils.formatDate(entry.value),
                today.difference(entry.value).inDays,
              ),
            )
            .toList()
          ..sort((a, b) {
            final date = a.lastDate.compareTo(b.lastDate);
            return date != 0 ? date : a.title.compareTo(b.title);
          });
    recentWeek = _week(
      today.subtract(const Duration(days: 7)),
      today.subtract(const Duration(days: 1)),
    );
    previousWeek = _week(
      today.subtract(const Duration(days: 14)),
      today.subtract(const Duration(days: 8)),
    );
  }

  final Workspace workspace;
  final DateTime today;
  late final DateTime start, end, tomorrow;
  final hoursByDate = <String, double>{};
  late final List<ReviewSubject> reviewSubjects;
  late final StudyWeek recentWeek, previousWeek;

  StudyWeek _week(DateTime from, DateTime to) {
    final days = <DailyStudy>[];
    for (
      var date = from;
      !date.isAfter(to);
      date = date.add(const Duration(days: 1))
    ) {
      if (date.isBefore(start) || date.isAfter(end)) continue;
      final iso = AppUtils.formatDate(date);
      days.add(DailyStudy(iso, hoursByDate[iso] ?? 0));
    }
    return StudyWeek(days, workspace.dailyTargetHours);
  }

  bool get canPlanTomorrow =>
      !tomorrow.isBefore(start) && !tomorrow.isAfter(end);
  bool get isUpcoming => tomorrow.isBefore(start);
  bool get hasHistory => hoursByDate.isNotEmpty;
  bool get canCompareWeeks =>
      recentWeek.days.length == 7 && previousWeek.days.length == 7;
  double get weekChange => recentWeek.hours - previousWeek.hours;
  double get loggedHours =>
      hoursByDate.values.fold(0, (sum, hours) => sum + hours);
  int get totalDays => end.difference(start).inDays + 1;
  double get remainingHours =>
      math.max(0, totalDays * workspace.dailyTargetHours - loggedHours);
  int get remainingDays {
    final from = tomorrow.isBefore(start) ? start : tomorrow;
    return math.max(0, end.difference(from).inDays + 1);
  }

  double? get requiredDailyHours =>
      remainingDays == 0 ? null : remainingHours / remainingDays;

  /// Estimate of logged-time goal completion, using all eligible completed days.
  DateTime? get estimatedFinish {
    if (remainingHours == 0 ||
        recentWeek.days.length < 7 ||
        recentWeek.average <= 0) {
      return null;
    }
    final daysNeeded = remainingHours / recentWeek.average;
    // Tiny timer logs can otherwise produce an unrepresentable calendar date.
    if (!daysNeeded.isFinite || daysNeeded > 3650) return null;
    return tomorrow.add(Duration(days: daysNeeded.ceil() - 1));
  }

  int get streak {
    var date = today.isAfter(end) ? end : today;
    if (date.isBefore(start)) return 0;
    // A day still in progress does not break yesterday's streak.
    if (date == today && (hoursByDate[AppUtils.formatDate(date)] ?? 0) == 0) {
      date = date.subtract(const Duration(days: 1));
    }
    var count = 0;
    while (!date.isBefore(start) &&
        (hoursByDate[AppUtils.formatDate(date)] ?? 0) > 0) {
      count++;
      date = date.subtract(const Duration(days: 1));
    }
    return count;
  }

  /// Conservative product heuristic, not a scientifically optimal duration.
  /// Start with at most one hour; otherwise grow the active-day median by 25%.
  double get suggestedHours {
    final active =
        recentWeek.days
            .where((day) => day.hours > 0)
            .map((day) => day.hours)
            .toList()
          ..sort();
    if (active.isEmpty) return math.min(workspace.dailyTargetHours, 1);
    final middle = active.length ~/ 2;
    final median = active.length.isOdd
        ? active[middle]
        : (active[middle - 1] + active[middle]) / 2;
    return math.min(
      workspace.dailyTargetHours,
      math.max(0.25, (median * 1.25 * 4).floor() / 4),
    );
  }

  TomorrowPlan plan(double hours) {
    final minutes = (hours.clamp(0.25, 24) * 60).round();
    final older = reviewSubjects
        .where((subject) => subject.daysAgo >= 1)
        .toList();
    final review = older.isEmpty ? null : older.first.title;
    final other = reviewSubjects
        .where((subject) => subject.title != review)
        .toList();
    other.sort((a, b) => b.lastDate.compareTo(a.lastDate));
    return TomorrowPlan(
      minutes,
      review == null ? 0 : (minutes * 0.25).round(),
      review,
      other.isEmpty ? review : other.first.title,
    );
  }
}
