import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study/data/models.dart';
import 'package:study/data/providers.dart';
import 'package:study/data/workspace_dao.dart';
import 'package:study/presentation/workspaces/workspace_dialog.dart';
import 'package:study/presentation/tracker/tracker_screen.dart';

class RecordingWorkspaceDao extends WorkspaceDao {
  Workspace? saved;

  @override
  Future<int> update(Workspace workspace) async {
    saved = workspace;
    return 1;
  }
}

Widget localized(Widget child) => MaterialApp(
      locale: const Locale('fa'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );

void main() {
  const workspace = Workspace(
      id: 1,
      name: 'قلب',
      startDate: '2025-03-21',
      endDate: '2025-03-22',
      dailyTargetHours: 8);

  testWidgets(
      'workspace edit shows Jalali dates and saves a Persian numeric target',
      (tester) async {
    final dao = RecordingWorkspaceDao();
    await tester.pumpWidget(ProviderScope(overrides: [
      workspaceDaoProvider.overrideWithValue(dao),
    ], child: localized(const WorkspaceDialog(workspace: workspace))));
    await tester.pumpAndSettle();
    expect(find.text('1404/01/01'), findsOneWidget);
    expect(find.text('1404/01/02'), findsOneWidget);
    final target = find.widgetWithText(TextFormField, 'هدف روزانه (ساعت)');
    await tester.enterText(target, '۰');
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();
    expect(dao.saved, isNull);
    await tester.enterText(target, '۶٫۵');
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();
    expect(dao.saved!.dailyTargetHours, 6.5);
    expect(dao.saved!.startDate, '2025-03-21');
    expect(dao.saved!.endDate, '2025-03-22');
  });

  testWidgets(
      'date field opens a Jalali calendar and cancellation preserves date',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
        child: localized(const WorkspaceDialog(workspace: workspace))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1404/01/01'));
    await tester.pumpAndSettle();
    expect(find.textContaining('فروردین'), findsWidgets);
    Navigator.of(tester.element(find.textContaining('فروردین').first)).pop();
    await tester.pumpAndSettle();
    expect(find.text('1404/01/01'), findsOneWidget);
  });

  testWidgets(
      'tracker shows configured target and export button even with no sessions',
      (tester) async {
    await tester.pumpWidget(ProviderScope(overrides: [
      selectedWorkspaceIdProvider.overrideWith((ref) => 1),
      workspacesProvider.overrideWith((ref) => Stream.value([workspace])),
      studyEntriesProvider.overrideWith((ref) => Stream.value(<StudyEntry>[])),
    ], child: localized(const TrackerScreen())));
    await tester.pumpAndSettle();
    expect(find.text('مطالعه امروز / هدف: 0.0h / 8.0h'), findsOneWidget);
    expect(find.byTooltip('خروجی CSV'), findsOneWidget);
  });
}
