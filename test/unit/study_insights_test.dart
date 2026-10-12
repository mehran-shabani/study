import 'package:flutter_test/flutter_test.dart';
import 'package:study/data/models.dart';
import 'package:study/domain/study_insights.dart';

const workspace = Workspace(
  id: 1,
  name: 'Study',
  startDate: '2026-10-01',
  endDate: '2026-10-31',
  dailyTargetHours: 4,
);
StudyEntry entry(
  String date,
  double hours, {
  String title = 'Math',
  int id = 1,
}) => StudyEntry(workspaceId: id, entryDate: date, title: title, hours: hours);
StudyInsights insights(
  List<StudyEntry> entries, {
  Workspace plan = workspace,
  DateTime? now,
}) => StudyInsights(entries, plan, now ?? DateTime(2026, 10, 16));

void main() {
  test('completed weeks count zero days and exclude today from averages', () {
    final result = insights([
      entry('2026-10-02', 1),
      entry('2026-10-09', 2),
      entry('2026-10-09', 2),
      entry('2026-10-15', 3),
      entry('2026-10-16', 10),
    ]);
    expect(result.recentWeek.hours, 7);
    expect(result.recentWeek.average, 1);
    expect(result.recentWeek.activeDays, 2);
    expect(result.recentWeek.goalDays, 1);
    expect(result.recentWeek.days.length, 7);
    expect(result.previousWeek.hours, 1);
    expect(result.weekChange, 6);
    expect(result.canCompareWeeks, isTrue);
    expect(result.loggedHours, 18);
  });

  test(
    'future, other workspace, out-of-range and invalid hours are excluded',
    () {
      final result = insights([
        entry('2026-10-15', 2),
        entry('2026-10-17', 20, title: 'Future'),
        entry('2026-09-30', 20),
        entry('2026-10-15', 20, id: 2),
        entry('2026-10-15', double.nan),
        entry('2026-10-15', -2),
        entry('2026-10-15', double.infinity),
      ]);
      expect(result.loggedHours, 2);
      expect(result.reviewSubjects.map((s) => s.title), ['Math']);
    },
  );

  test('new plans use only eligible days and do not compare partial weeks', () {
    final result = insights(
      [],
      plan: workspace.copyWith(startDate: '2026-10-14'),
    );
    expect(result.recentWeek.days.length, 2);
    expect(result.recentWeek.average, 0);
    expect(result.canCompareWeeks, isFalse);
    expect(result.estimatedFinish, isNull);
    expect(result.suggestedHours, 1);
  });

  test('median avoids a single very long day and respects daily target', () {
    final data = [
      entry('2026-10-10', 1),
      entry('2026-10-11', 1),
      entry('2026-10-12', 12),
    ];
    expect(insights(data).suggestedHours, 1.25);
    expect(
      insights(
        data,
        plan: workspace.copyWith(dailyTargetHours: 0.5),
      ).suggestedHours,
      0.5,
    );
    expect(
      insights(
        [],
        plan: workspace.copyWith(dailyTargetHours: 0.25),
      ).suggestedHours,
      0.25,
    );
  });

  test('even-day median aggregates multiple logs on the same day', () {
    final result = insights([
      entry('2026-10-10', 0.5),
      entry('2026-10-10', 0.5),
      entry('2026-10-11', 2),
    ]);
    expect(result.suggestedHours, 1.75);
  });

  test(
    'review order uses latest log for each trimmed subject, oldest first',
    () {
      final result = insights([
        entry('2026-10-02', 1, title: ' Math '),
        entry('2026-10-15', 1, title: 'Math'),
        entry('2026-10-09', 1, title: 'Biology'),
      ]);
      expect(result.reviewSubjects.map((s) => s.title), ['Biology', 'Math']);
      expect(result.reviewSubjects.first.daysAgo, 7);
      expect(result.plan(2).reviewTitle, 'Biology');
      expect(result.plan(2).focusTitle, 'Math');
    },
  );

  test(
    'tomorrow blocks exactly fit budget without adding final check time',
    () {
      final result = insights([entry('2026-10-15', 1)]);
      for (final budget in [0.25, 0.5, 1.25, 2.0, 24.0]) {
        final plan = result.plan(budget);
        expect(plan.totalMinutes, (budget * 60).round());
        expect(plan.reviewMinutes + plan.focusMinutes, plan.totalMinutes);
        expect(plan.reviewMinutes, greaterThan(0));
      }
      final todayOnly = insights([entry('2026-10-16', 2)]).plan(1);
      expect(todayOnly.reviewTitle, isNull);
      expect(todayOnly.reviewMinutes, 0);
      expect(todayOnly.focusMinutes, 60);
    },
  );

  test(
    'streak survives an unlogged today but stops at a completed zero day',
    () {
      final data = [entry('2026-10-14', 1), entry('2026-10-15', 1)];
      expect(insights(data).streak, 2);
      expect(insights([...data, entry('2026-10-16', 0.1)]).streak, 3);
      expect(insights(data, now: DateTime(2026, 10, 17)).streak, 0);
    },
  );

  test(
    'required pace starts tomorrow and credits today without future logs',
    () {
      final result = insights([entry('2026-10-16', 4)]);
      expect(result.remainingHours, 120);
      expect(result.remainingDays, 15);
      expect(result.requiredDailyHours, 8);
    },
  );

  test('forecast uses seven calendar days including zero days', () {
    final result = insights([entry('2026-10-09', 7)]);
    expect(result.recentWeek.average, 1);
    expect(result.estimatedFinish, DateTime.utc(2027, 2, 10));
    expect(insights([]).estimatedFinish, isNull);
  });

  test(
    'future and finished plans do not propose out-of-range tomorrow study',
    () {
      final future = insights(
        [],
        plan: workspace.copyWith(startDate: '2026-10-20'),
      );
      expect(future.canPlanTomorrow, isFalse);
      expect(future.isUpcoming, isTrue);
      expect(future.remainingDays, 12);
      final finished = insights(
        [],
        plan: workspace.copyWith(endDate: '2026-10-16'),
      );
      expect(finished.canPlanTomorrow, isFalse);
      expect(finished.requiredDailyHours, isNull);
      expect(finished.remainingDays, 0);
      expect(
        insights(
          [],
          plan: workspace.copyWith(startDate: '2026-10-17'),
        ).canPlanTomorrow,
        isTrue,
      );
    },
  );

  test('time goal completion does not produce negative remaining hours', () {
    final result = insights([entry('2026-10-15', 200)]);
    expect(result.remainingHours, 0);
    expect(result.requiredDailyHours, 0);
    expect(result.estimatedFinish, isNull);
  });

  test('tiny timer logs do not overflow the completion date', () {
    expect(
      insights([entry('2026-10-15', 1 / 3600000)]).estimatedFinish,
      isNull,
    );
  });

  test('calendar windows work across month and year boundaries', () {
    final result = insights(
      [entry('2025-12-31', 1)],
      plan: workspace.copyWith(startDate: '2025-12-20', endDate: '2026-01-10'),
      now: DateTime(2026, 1, 1),
    );
    expect(result.tomorrow, DateTime.utc(2026, 1, 2));
    expect(result.recentWeek.days.length, 7);
    expect(result.reviewSubjects.single.daysAgo, 1);
    expect(result.remainingDays, 9);
  });
}
