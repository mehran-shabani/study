import 'dart:async';
import 'package:study/data/app_settings.dart';
import 'package:study/data/study_sound.dart';

class MemorySettingsRepository extends AppSettingsRepository {
  AppSettings value = const AppSettings();
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<AppSettings> load() async {
    if (fail) throw StateError('Unavailable');
    return value;
  }

  @override
  Future<void> save(AppSettings settings) async {
    await gate?.future;
    if (fail) throw StateError('Storage full');
    value = settings;
  }
}

class RecordingLanguagePlatform extends AppLanguagePlatform {
  final values = <String>[];
  bool fail = false;
  @override
  Future<void> sync(String language) async {
    if (fail) throw StateError('Service unavailable');
    values.add(language);
  }
}

class MemoryStudySound extends StudySound {
  StudySoundSettings settings = const StudySoundSettings();
  bool fail = false;
  final awake = <bool>[];
  @override
  bool get supported => true;
  @override
  Future<StudySoundSettings> load() async => settings;
  @override
  Future<void> save(StudySoundSettings value) async {
    if (fail) throw StateError('Audio unavailable');
    settings = value;
  }

  @override
  Future<void> screenAwake(bool value) async => awake.add(value);
}
