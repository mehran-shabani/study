import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study/core/utils.dart';
import 'package:study/data/models.dart';
import 'package:study/data/providers.dart';
import 'package:study/data/study_entry_dao.dart';
import 'package:study/main.dart';
import 'package:study/presentation/tracker/entry_dialog.dart';
import 'package:study/data/study_timer_provider.dart';
import '../support/memory_timer_dao.dart';

class ControlledEntryDao extends StudyEntryDao {
  final pending = Completer<int>();
  int calls = 0;
  StudyEntry? submitted;

  @override
  Future<int> insert(StudyEntry entry) {
    calls++;
    submitted = entry;
    return pending.future;
  }
}

Widget dialogApp() => MaterialApp(
      locale: const Locale('fa'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate
      ],
      home: Builder(
          builder: (context) => Scaffold(
                  body: TextButton(
                onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => const EntryDialog(workspaceId: 1)),
                child: const Text('open'),
              ))),
    );

void main() {
  testWidgets(
      'presets and recent subjects save once and preserve input on failure',
      (tester) async {
    final dao = ControlledEntryDao();
    await tester.pumpWidget(ProviderScope(overrides: [
      studyEntryDaoProvider.overrideWithValue(dao),
      studyEntriesProvider.overrideWith((ref) => Stream.value([
            StudyEntry(
                workspaceId: 1,
                entryDate: AppUtils.today(),
                title: 'قلب',
                hours: 2),
          ])),
    ], child: dialogApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'قلب'));
    final preset = find.byType(ChoiceChip).at(1); // 30 minutes
    await tester.ensureVisible(preset);
    await tester.tap(preset);
    await tester.tap(find.text('ذخیره'));
    await tester.pump();
    expect(dao.calls, 1);
    expect(dao.submitted!.title, 'قلب');
    expect(dao.submitted!.hours, 0.5);
    expect(find.text('در حال ذخیره…'), findsOneWidget);
    final save = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'در حال ذخیره…'));
    expect(save.onPressed, isNull);
    dao.pending.completeError(StateError('storage unavailable'));
    await tester.pumpAndSettle();
    expect(find.byType(EntryDialog), findsOneWidget);
    expect(find.textContaining('اطلاعاتت حفظ شده'), findsOneWidget);
    expect(
        tester
            .widget<TextFormField>(
                find.widgetWithText(TextFormField, 'درس یا موضوع'))
            .controller!
            .text,
        'قلب');
    expect(
        tester
            .widget<TextFormField>(
                find.widgetWithText(TextFormField, 'مدت مطالعه'))
            .controller!
            .text,
        '0.5');
    expect(dao.calls, 1);
  });

  testWidgets('selecting a plan opens Study and the header can change plans',
      (tester) async {
    const plans = [
      Workspace(
          id: 1,
          name: 'Cardiology',
          startDate: '2026-10-01',
          endDate: '2026-10-31'),
      Workspace(
          id: 2,
          name: 'Pulmonology',
          startDate: '2026-10-01',
          endDate: '2026-10-31'),
    ];
    await tester.pumpWidget(ProviderScope(overrides: [
      studyTimerDaoProvider.overrideWithValue(MemoryTimerDao()),
      workspacesProvider.overrideWith((ref) => Stream.value(plans)),
      studyEntriesProvider.overrideWith((ref) => Stream.value(<StudyEntry>[])),
    ], child: const StudyApp()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cardiology').first);
    await tester.pumpAndSettle();
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1);
    final selector = find.byType(DropdownButton<int>);
    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pulmonology').last);
    await tester.pumpAndSettle();
    expect(tester.widget<DropdownButton<int>>(selector).value, 2);
    expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1);
  });
}
