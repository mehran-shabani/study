import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study/data/models.dart';
import 'package:study/data/providers.dart';
import 'package:study/data/study_timer_provider.dart';
import 'package:study/presentation/tracker/tracker_screen.dart';
import 'package:study/presentation/tracker/timer_subject_dialog.dart';
import '../support/memory_timer_dao.dart';
import 'study_features_test.dart' show localized;

void main() {
  testWidgets(
      'small clock above Log study stops, asks subject and saves exact time',
      (tester) async {
    var now = DateTime(2026, 10, 11, 23, 59, 30);
    final dao = MemoryTimerDao();
    const workspace = Workspace(
        id: 1, name: 'قلب', startDate: '2026-10-01', endDate: '2026-10-31');
    const otherPlan = Workspace(
        id: 2, name: 'ریه', startDate: '2026-10-01', endDate: '2026-10-31');
    await tester.pumpWidget(ProviderScope(overrides: [
      studyTimerDaoProvider.overrideWithValue(dao),
      timerClockProvider.overrideWithValue(() => now),
      selectedWorkspaceIdProvider.overrideWith((ref) => 1),
      workspacesProvider
          .overrideWith((ref) => Stream.value([workspace, otherPlan])),
      studyEntriesProvider.overrideWith((ref) => Stream.value(<StudyEntry>[])),
    ], child: localized(const TrackerScreen())));
    await tester.pumpAndSettle();
    final clock = find.byKey(const ValueKey('study-timer-button'));
    final log = find.byKey(const ValueKey('log-study-button'));
    expect(tester.getCenter(clock).dx, tester.getCenter(log).dx);
    expect(tester.getCenter(clock).dy, lessThan(tester.getCenter(log).dy));
    expect(tester.getSize(clock).width, lessThan(tester.getSize(log).width));
    expect(find.byIcon(Icons.schedule_outlined), findsOneWidget);
    await tester.tap(clock);
    await tester.pumpAndSettle();
    now = now.add(const Duration(seconds: 90));
    final container =
        ProviderScope.containerOf(tester.element(find.byType(TrackerScreen)));
    container.read(selectedWorkspaceIdProvider.notifier).state = 2;
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('00:01:30'), findsOneWidget);
    await tester.tap(clock);
    await tester.pumpAndSettle();
    expect(find.byType(TimerSubjectDialog), findsOneWidget);
    expect(
        find.descendant(
            of: find.byType(TimerSubjectDialog),
            matching: find.textContaining('1405/07/19')),
        findsOneWidget);
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();
    expect(dao.entries, isEmpty);
    await tester.enterText(find.byKey(const ValueKey('timer-subject')), 'قلب');
    dao.failFinish = true;
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();
    expect(find.textContaining('اطلاعاتت حفظ شده'), findsOneWidget);
    expect(dao.entries, isEmpty);
    await tester.tap(find.text('بعداً ثبت می‌کنم'));
    await tester.pumpAndSettle();
    now = now.add(const Duration(hours: 1));
    await tester.tap(clock);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<TextFormField>(find.byKey(const ValueKey('timer-subject')))
            .controller!
            .text,
        'قلب');
    dao.failFinish = false;
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();
    expect(find.byType(TimerSubjectDialog), findsNothing);
    expect(dao.entries.map((e) => e.entryDate), ['2026-10-11', '2026-10-12']);
    expect(dao.entries.every((e) => e.workspaceId == 1), isTrue);
    expect(dao.entries.fold<double>(0, (sum, e) => sum + e.hours), 90 / 3600);
    expect(dao.session, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
