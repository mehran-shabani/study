import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study/data/models.dart';
import 'package:study/data/providers.dart';
import 'package:study/l10n/generated/app_localizations.dart';
import 'package:study/presentation/analytics/analytics_screen.dart';
import 'package:study/presentation/analytics/analytics_more_screen.dart';
import 'package:study/presentation/analytics/timeline_chart.dart';
import 'package:study/presentation/analytics/title_chart.dart';

const plan = Workspace(
  id: 1,
  name: 'Test plan',
  startDate: '2026-10-01',
  endDate: '2026-10-31',
  dailyTargetHours: 4,
);
const data = [
  StudyEntry(workspaceId: 1, entryDate: '2026-10-12', title: 'زیست', hours: 1),
];

Widget app({
  Widget home = const AnalyticsScreen(),
  String locale = 'fa',
  List<StudyEntry> entries = data,
  List<Workspace> plans = const [plan],
  Stream<List<StudyEntry>>? stream,
  double scale = 1,
  ProviderContainer? container,
}) {
  final child = MaterialApp(
    locale: Locale(locale),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: home,
  );
  if (container != null) {
    return UncontrolledProviderScope(container: container, child: child);
  }
  return ProviderScope(
    overrides: [
      selectedWorkspaceIdProvider.overrideWith((ref) => 1),
      workspacesProvider.overrideWith((ref) => Stream.value(plans)),
      studyEntriesProvider.overrideWith(
        (ref) => stream ?? Stream.value(entries),
      ),
      todayProvider.overrideWithValue('2026-10-13'),
    ],
    child: child,
  );
}

void main() {
  testWidgets('More opens separately and back preserves existing charts', (
    tester,
  ) async {
    await tester.pumpWidget(app());
    await tester.pumpAndSettle();
    expect(find.byType(TimelineChart), findsOneWidget);
    expect(find.byType(TitleChart), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('analytics-more')));
    await tester.pumpAndSettle();
    expect(find.byType(AnalyticsMoreScreen), findsOneWidget);
    expect(find.text('پیشنهاد برای فردا'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(AnalyticsMoreScreen), findsNothing);
    expect(find.byType(TimelineChart), findsOneWidget);
    expect(find.byType(TitleChart), findsOneWidget);
  });

  testWidgets(
    'empty history offers a starter plan without fabricated reviews',
    (tester) async {
      await tester.pumpWidget(
        app(home: const AnalyticsMoreScreen(), entries: []),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tomorrow-budget')), findsOneWidget);
      expect(find.textContaining('حداکثر یک ساعت'), findsOneWidget);
      expect(find.textContaining('یک موضوع به انتخاب خودت'), findsOneWidget);
      final scroll = find.byKey(const ValueKey('more-insights-scroll'));
      await tester.drag(scroll, const Offset(0, -700));
      await tester.pumpAndSettle();
      expect(
        find.text('یک موضوع مطالعه ثبت کن تا پیشنهاد مرور شخصی داشته باشی.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('budget can be adjusted and reset without changing target', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(home: const AnalyticsMoreScreen(), locale: 'en'),
    );
    await tester.pumpAndSettle();
    final slider = find.byKey(const ValueKey('tomorrow-budget'));
    expect(tester.widget<Slider>(slider).value, 1.25);
    tester.widget<Slider>(slider).onChanged!(2);
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(slider).value, 2);
    expect(find.text('Review زیست · 30 minutes'), findsOneWidget);
    expect(find.text('Study زیست · 90 minutes'), findsOneWidget);
    await tester.tap(find.text('Reset to suggested time'));
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(slider).value, 1.25);
    expect(plan.dailyTargetHours, 4);
  });

  testWidgets('switching plans resets custom budget and review subjects', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        workspacesProvider.overrideWith(
          (ref) => Stream.value([
            plan,
            plan.copyWith(id: 2, name: 'Second', dailyTargetHours: 0.5),
          ]),
        ),
        studyEntriesProvider.overrideWith(
          (ref) => Stream.value(
            ref.watch(selectedWorkspaceIdProvider) == 1 ? data : <StudyEntry>[],
          ),
        ),
        todayProvider.overrideWithValue('2026-10-13'),
      ],
    );
    addTearDown(container.dispose);
    container.read(selectedWorkspaceIdProvider.notifier).state = 1;
    await tester.pumpWidget(
      app(home: const AnalyticsMoreScreen(), container: container),
    );
    await tester.pumpAndSettle();
    final slider = find.byKey(const ValueKey('tomorrow-budget'));
    tester.widget<Slider>(slider).onChanged!(2);
    await tester.pumpAndSettle();
    container.read(selectedWorkspaceIdProvider.notifier).state = 2;
    await tester.pumpAndSettle();
    expect(tester.widget<Slider>(slider).value, 0.5);
    expect(find.textContaining('مرور زیست'), findsNothing);
  });

  testWidgets('new logs refresh review plan while More is open', (
    tester,
  ) async {
    final stream = StreamController<List<StudyEntry>>();
    addTearDown(stream.close);
    await tester.pumpWidget(
      app(home: const AnalyticsMoreScreen(), stream: stream.stream),
    );
    stream.add([]);
    await tester.pumpAndSettle();
    expect(find.textContaining('مرور زیست'), findsNothing);
    stream.add(data);
    await tester.pumpAndSettle();
    expect(find.textContaining('مرور زیست'), findsOneWidget);
  });

  for (final locale in ['fa', 'en']) {
    testWidgets('More fits a narrow screen at large text size in $locale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        app(home: const AnalyticsMoreScreen(), locale: locale, scale: 1.5),
      );
      await tester.pumpAndSettle();
      final scroll = find.byKey(const ValueKey('more-insights-scroll'));
      for (var i = 0; i < 10; i++) {
        await tester.drag(scroll, const Offset(0, -550));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      await tester.ensureVisible(find.byType(ExpansionTile));
      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('finished plan hides budget and allows editing dates', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        home: const AnalyticsMoreScreen(),
        plans: [plan.copyWith(endDate: '2026-10-13')],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tomorrow-budget')), findsNothing);
    expect(find.textContaining('فردا خارج از بازه'), findsOneWidget);
    expect(find.text('ویرایش برنامه'), findsWidgets);
  });
}
