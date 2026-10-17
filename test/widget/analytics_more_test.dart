import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:study/data/models.dart';
import 'package:study/core/theme.dart';
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
  bool dark = false,
}) {
  final child = MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
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
  const shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

  testWidgets('long AI histories share a complete UTF-8 text file', (
    tester,
  ) async {
    final directory = Directory.systemTemp.createTempSync(
      'study-ai-share-test-',
    );
    addTearDown(() => directory.deleteSync(recursive: true));
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    final shared = Completer<MethodCall>();
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      pathChannel,
      (_) async => directory.path,
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      shareChannel,
      (call) async {
        shared.complete(call);
        return 'dev.fluttercommunity.plus/share/dismissed';
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        pathChannel,
        null,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        shareChannel,
        null,
      );
    });
    await tester.pumpWidget(
      app(
        home: const AnalyticsMoreScreen(),
        entries: List.generate(700, (_) => data.first),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-with-ai')));
    await tester.pumpAndSettle();
    final preview = tester
        .widget<SelectableText>(find.byKey(const ValueKey('ai-prompt-preview')))
        .data!;
    await tester.tap(find.byKey(const ValueKey('send-ai-prompt')));
    // File IO runs outside Flutter's fake clock; pump channel completions too.
    for (var i = 0; i < 100 && !shared.isCompleted; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(shared.isCompleted, isTrue);
    final call = await shared.future;
    expect(call.method, 'shareFiles');
    expect(call.arguments['mimeTypes'], ['text/plain']);
    final paths = call.arguments['paths'] as List;
    expect(paths, hasLength(1));
    expect(File(paths.single as String).readAsStringSync(), preview);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'AI preview copies and shares identical complete text with custom budget',
    (tester) async {
      String? clipboard;
      MethodCall? shared;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboard = call.arguments['text'] as String;
          }
          return null;
        },
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        shareChannel,
        (call) async {
          shared = call;
          return 'dev.fluttercommunity.plus/share/dismissed';
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          shareChannel,
          null,
        );
      });
      await tester.pumpWidget(app(home: const AnalyticsMoreScreen()));
      await tester.pumpAndSettle();
      tester
          .widget<Slider>(find.byKey(const ValueKey('tomorrow-budget')))
          .onChanged!(2);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('share-with-ai')));
      await tester.pumpAndSettle();
      final preview = tester
          .widget<SelectableText>(
            find.byKey(const ValueKey('ai-prompt-preview')),
          )
          .data!;
      final payload = jsonDecode(preview.substring(preview.indexOf('{')));
      expect(preview, contains('به فارسی پاسخ بده'));
      expect(payload['plan']['name'], plan.name);
      expect(payload['tomorrow_draft']['available_hours'], 2);
      await tester.tap(find.byKey(const ValueKey('copy-ai-prompt')));
      await tester.pumpAndSettle();
      expect(clipboard, preview);
      expect(find.textContaining('متن کپی شد'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('send-ai-prompt')));
      await tester.pumpAndSettle();
      expect(shared!.method, 'share');
      expect(shared!.arguments['text'], preview);
      expect(shared!.arguments['subject'], contains(plan.name));
      expect(shared!.arguments['originWidth'], greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('failed AI sharing preserves preview and allows copy or retry', (
    tester,
  ) async {
    var attempts = 0;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      shareChannel,
      (_) async {
        attempts++;
        throw PlatformException(code: 'unavailable');
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        shareChannel,
        null,
      ),
    );
    await tester.pumpWidget(
      app(home: const AnalyticsMoreScreen(), locale: 'en'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('share-with-ai')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('send-ai-prompt')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Could not open sharing'), findsOneWidget);
    expect(find.byKey(const ValueKey('ai-prompt-preview')), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(find.byKey(const ValueKey('copy-ai-prompt')))
          .onPressed,
      isNotNull,
    );
    await tester.tap(find.byKey(const ValueKey('send-ai-prompt')));
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });

  for (final locale in ['fa', 'en']) {
    testWidgets(
      'Reports fits narrow and wide layouts with large text in $locale',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.devicePixelRatio = 1;
        for (final size in [const Size(320, 700), const Size(1200, 900)]) {
          tester.view.physicalSize = size;
          await tester.pumpWidget(
            app(locale: locale, scale: 1.5, dark: size.width > 900),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(find.byType(TitleChart));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
      },
    );

    testWidgets(
      'AI preview fits narrow large-text and wide dark layouts in $locale',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.devicePixelRatio = 1;
        for (final size in [const Size(320, 700), const Size(1200, 900)]) {
          tester.view.physicalSize = size;
          await tester.pumpWidget(
            app(
              home: const AnalyticsMoreScreen(),
              locale: locale,
              scale: 1.5,
              dark: true,
            ),
          );
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.byKey(const ValueKey('share-with-ai')),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('share-with-ai')));
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('copy-ai-prompt')).hitTestable(),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('send-ai-prompt')).hitTestable(),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.tap(find.byIcon(Icons.close_rounded));
          await tester.pumpAndSettle();
        }
      },
    );
  }

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
    await tester.ensureVisible(find.text('Reset to suggested time'));
    await tester.pumpAndSettle();
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
