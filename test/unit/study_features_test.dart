import 'package:flutter_test/flutter_test.dart';
import 'package:study/core/utils.dart';
import 'package:study/data/models.dart';
import 'package:study/domain/csv_export.dart';
import 'package:study/domain/helpers.dart';

void main() {
  const workspace = Workspace(
      id: 1,
      name: 'قلب',
      startDate: '2025-03-20',
      endDate: '2025-03-21',
      dailyTargetHours: 8);
  const entry = StudyEntry(
      id: 1,
      workspaceId: 1,
      entryDate: '2025-03-21',
      title: 'قلب, "مرور"\nبخش دوم',
      hours: 4);

  test('progress uses the configured target and updates after editing it', () {
    expect(calcProgress([entry], workspace), 25);
    expect(calcProgress([entry], workspace.copyWith(dailyTargetHours: 4)), 50);
  });

  test('target round trips through database maps, preserving legacy defaults',
      () {
    expect(Workspace.fromMap(workspace.toMap()), workspace);
    final legacy = workspace.toMap()..remove('daily_target_hours');
    expect(Workspace.fromMap(legacy).dailyTargetHours, 4);
    final integerValue = workspace.toMap()..['daily_target_hours'] = 6;
    expect(Workspace.fromMap(integerValue).dailyTargetHours, 6);
    expect(workspace, isNot(workspace.copyWith(dailyTargetHours: 4)));
  });

  test(
      'Jalali display covers Nowruz and the leap day without changing ISO storage',
      () {
    expect(AppUtils.displayDate('2025-03-20'), '1403/12/30');
    expect(AppUtils.displayDate('2025-03-21'), '1404/01/01');
    expect(AppUtils.displayDate('2026-10-11'), '1405/07/19');
    expect(AppUtils.formatDate(AppUtils.parseDate('2025-03-21')), '2025-03-21');
  });

  test(
      'targets accept Persian decimals and reject non-finite or invalid values',
      () {
    expect(AppUtils.validateHours('۸٫۵'), isNull);
    expect(AppUtils.normalizeNumber('٨.٥'), '8.5');
    for (final value in ['0', '-1', '25', 'NaN', 'Infinity', '']) {
      expect(AppUtils.validateHours(value), isNotNull, reason: value);
    }
  });

  test(
      'CSV preserves Persian text, escaped quotes, multiline titles, and both dates',
      () {
    final csv = buildStudyCsv(workspace, [entry]);
    expect(csv, startsWith('\uFEFF"workspace"'));
    expect(csv, contains('"1404/01/01","2025-03-21"'));
    expect(csv, contains('"قلب, ""مرور""\nبخش دوم","4.0","8.0"'));
    expect(csv, endsWith('\r\n'));
  });

  test('CSV sorts sessions, filters other workspaces and neutralizes formulas',
      () {
    final csv = buildStudyCsv(workspace, [
      entry,
      entry.copyWith(id: 2, entryDate: '2025-03-20', title: '=1+1'),
      entry.copyWith(workspaceId: 2, title: 'Other workspace'),
    ]);
    expect(csv.indexOf('2025-03-20'), lessThan(csv.indexOf('2025-03-21')));
    expect(csv, contains('"\'=1+1"'));
    expect(csv, isNot(contains('Other workspace')));
  });

  test('empty CSV export still has a header', () {
    expect(buildStudyCsv(workspace, []).split('\r\n').length, 2);
  });
}
