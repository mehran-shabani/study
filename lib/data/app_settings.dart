import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'database.dart';

@immutable
class AppSettings {
  const AppSettings({
    this.language = 'system',
    this.theme = 'system',
    this.focusMinutes = 25,
    this.dailyTargetHours = 4,
    this.textScale = 1,
  });

  final String language;
  final String theme;
  final int focusMinutes;
  final double dailyTargetHours;
  final double textScale;

  Locale? get locale => language == 'system' ? null : Locale(language);
  ThemeMode get themeMode => switch (theme) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  AppSettings copyWith({
    String? language,
    String? theme,
    int? focusMinutes,
    double? dailyTargetHours,
    double? textScale,
  }) => AppSettings(
    language: language ?? this.language,
    theme: theme ?? this.theme,
    focusMinutes: focusMinutes ?? this.focusMinutes,
    dailyTargetHours: dailyTargetHours ?? this.dailyTargetHours,
    textScale: textScale ?? this.textScale,
  );

  Map<String, Object> toMap() => {
    'language': language,
    'theme': theme,
    'focusMinutes': focusMinutes,
    'dailyTargetHours': dailyTargetHours,
    'textScale': textScale,
  };

  factory AppSettings.fromMap(Map<String, dynamic> map) {
    final target = map['dailyTargetHours'];
    final scale = map['textScale'];
    return AppSettings(
      language: ['system', 'fa', 'en'].contains(map['language'])
          ? map['language'] as String
          : 'system',
      theme: ['system', 'light', 'dark'].contains(map['theme'])
          ? map['theme'] as String
          : 'system',
      focusMinutes:
          map['focusMinutes'] is int &&
              [0, 15, 25, 50].contains(map['focusMinutes'])
          ? map['focusMinutes'] as int
          : 25,
      dailyTargetHours:
          target is num && target.isFinite && target >= 0.25 && target <= 24
          ? target.toDouble()
          : 4,
      textScale: scale is num && [1.0, 1.15, 1.3].contains(scale)
          ? scale.toDouble()
          : 1,
    );
  }
}

/// Preferences share the existing offline database, independently of study logs.
class AppSettingsRepository {
  Future<AppSettings> load() async {
    final db = await DatabaseService.database;
    final rows = await db.query('app_settings', where: 'id = 1');
    if (rows.isEmpty) return const AppSettings();
    try {
      final decoded = jsonDecode(rows.single['value'] as String);
      return decoded is Map<String, dynamic>
          ? AppSettings.fromMap(decoded)
          : const AppSettings();
    } on FormatException {
      return const AppSettings();
    }
  }

  Future<void> save(AppSettings value) async {
    final db = await DatabaseService.database;
    await db.insert('app_settings', {
      'id': 1,
      'value': jsonEncode(value.toMap()),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}

class AppLanguagePlatform {
  static const channel = MethodChannel('study/settings');
  Future<void> sync(String language) async {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      await channel.invokeMethod<void>('language', language);
    }
  }
}

class AppSettingsState {
  const AppSettingsState({
    this.value = const AppSettings(),
    this.busy = false,
    this.error,
    this.loadFailed = false,
  });
  final AppSettings value;
  final bool busy;
  final Object? error;
  final bool loadFailed;
}

final initialSettingsProvider = Provider<AppSettingsState>(
  (ref) => const AppSettingsState(),
);
final appSettingsRepositoryProvider = Provider(
  (ref) => AppSettingsRepository(),
);
final appLanguagePlatformProvider = Provider((ref) => AppLanguagePlatform());
final appSettingsProvider =
    StateNotifierProvider<AppSettingsController, AppSettingsState>(
      (ref) => AppSettingsController(
        ref.watch(appSettingsRepositoryProvider),
        ref.watch(appLanguagePlatformProvider),
        ref.watch(initialSettingsProvider),
      ),
    );

class AppSettingsController extends StateNotifier<AppSettingsState> {
  AppSettingsController(this.repository, this.platform, super.state);
  final AppSettingsRepository repository;
  final AppLanguagePlatform platform;

  Future<bool> reload() async {
    if (state.busy) return false;
    state = AppSettingsState(value: state.value, busy: true, loadFailed: true);
    try {
      final value = await repository.load();
      Object? platformError;
      try {
        await platform.sync(value.language);
      } catch (error) {
        platformError = error;
      }
      if (mounted) state = AppSettingsState(value: value, error: platformError);
      return platformError == null;
    } catch (error) {
      if (mounted) {
        state = AppSettingsState(
          value: state.value,
          error: error,
          loadFailed: true,
        );
      }
      return false;
    }
  }

  Future<bool> update(AppSettings value) async {
    if (state.busy || state.loadFailed) return false;
    final previous = state.value;
    state = AppSettingsState(value: previous, busy: true);
    try {
      final validated = AppSettings.fromMap(value.toMap());
      await repository.save(validated);
      // A notification-language failure must not undo a saved preference.
      Object? platformError;
      try {
        await platform.sync(validated.language);
      } catch (error) {
        platformError = error;
      }
      if (mounted) {
        state = AppSettingsState(value: validated, error: platformError);
      }
      return platformError == null;
    } catch (error) {
      if (mounted) state = AppSettingsState(value: previous, error: error);
      return false;
    }
  }
}
