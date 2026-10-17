import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:study/l10n/generated/app_localizations.dart';
import 'core/theme.dart';
import 'data/providers.dart';
import 'data/app_settings.dart';
import 'presentation/settings/settings_screen.dart';
import 'presentation/workspaces/workspace_list_screen.dart';
import 'presentation/tracker/tracker_screen.dart';
import 'presentation/analytics/analytics_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppSettingsState initial;
  try {
    final settings = await AppSettingsRepository().load();
    Object? languageError;
    try {
      await AppLanguagePlatform().sync(settings.language);
    } catch (error) {
      languageError = error;
    }
    initial = AppSettingsState(value: settings, error: languageError);
  } catch (error) {
    initial = AppSettingsState(error: error, loadFailed: true);
  }
  runApp(
    ProviderScope(
      overrides: [initialSettingsProvider.overrideWithValue(initial)],
      child: const StudyApp(),
    ),
  );
}

class StudyApp extends ConsumerWidget {
  const StudyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(
      appSettingsProvider.select((state) => state.value),
    );
    return MaterialApp(
      onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
      locale: settings.locale,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: settings.themeMode,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: _PreferenceTextScaler(
            MediaQuery.textScalerOf(context),
            settings.textScale,
          ),
        ),
        child: child!,
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('fa')],
      home: const MainScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

/// Preserve Android's nonlinear accessibility scaling before adding the user's
/// in-app size preference.
class _PreferenceTextScaler extends TextScaler {
  const _PreferenceTextScaler(this.system, this.factor);
  final TextScaler system;
  final double factor;
  @override
  double scale(double fontSize) => system.scale(fontSize) * factor;
  @override
  double get textScaleFactor => scale(14) / 14;
}

class MainScreen extends ConsumerStatefulWidget {
  const MainScreen({super.key});

  @override
  ConsumerState<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends ConsumerState<MainScreen>
    with WidgetsBindingObserver {
  final _visited = <int>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(todayProvider);
  }

  static const List<Widget> _screens = [
    WorkspaceListScreen(),
    TrackerScreen(),
    AnalyticsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = ref.watch(mainTabProvider);
    _visited.add(currentIndex);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: IndexedStack(
        index: currentIndex,
        children: [
          for (var i = 0; i < _screens.length; i++)
            TickerMode(
              enabled: i == currentIndex,
              child: _visited.contains(i)
                  ? _screens[i]
                  : const SizedBox.shrink(),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (index) {
          ref.read(mainTabProvider.notifier).state = index;
        },
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.workspace_premium_outlined),
            selectedIcon: const Icon(Icons.workspace_premium),
            label: l10n.workspaces,
          ),
          NavigationDestination(
            icon: const Icon(Icons.edit_note_outlined),
            selectedIcon: const Icon(Icons.edit_note),
            label: l10n.tracker,
          ),
          NavigationDestination(
            icon: const Icon(Icons.analytics_outlined),
            selectedIcon: const Icon(Icons.analytics),
            label: l10n.analytics,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.settings,
          ),
        ],
      ),
    );
  }
}
