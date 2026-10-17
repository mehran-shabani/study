import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const studySoundTracks = [
  'off',
  'melody',
  'piano',
  'lofi',
  'ambient',
  'strings',
  'bells',
  'rain',
  'brown',
  'ocean',
  'forest',
  'stream',
  'white',
];

class StudySoundSettings {
  const StudySoundSettings({
    this.track = 'off',
    this.volume = 0.25,
    this.keepAwake = false,
  });
  final String track;
  final double volume;
  final bool keepAwake;

  StudySoundSettings copyWith({
    String? track,
    double? volume,
    bool? keepAwake,
  }) => StudySoundSettings(
    track: track ?? this.track,
    volume: volume ?? this.volume,
    keepAwake: keepAwake ?? this.keepAwake,
  );

  factory StudySoundSettings.fromMap(Map<String, dynamic> map) {
    final volume = map['volume'];
    return StudySoundSettings(
      track: studySoundTracks.contains(map['track'])
          ? map['track'] as String
          : 'off',
      volume: volume is num && volume.isFinite
          ? volume.toDouble().clamp(0, 0.6)
          : 0.25,
      keepAwake: map['keepAwake'] == true,
    );
  }
}

/// Android's existing foreground service owns playback, including screen-off
/// study. No network, subscription, or additional package is required.
class StudySound {
  static const channel = MethodChannel('study/awareness');
  bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<StudySoundSettings> load() async {
    if (!supported) return const StudySoundSettings();
    final map = await channel.invokeMapMethod<String, dynamic>('soundSettings');
    return StudySoundSettings.fromMap(map ?? {});
  }

  Future<void> save(StudySoundSettings settings) async {
    if (!supported) return;
    await channel.invokeMethod<void>('setSound', {
      'track': settings.track,
      'volume': settings.volume,
      'keepAwake': settings.keepAwake,
    });
  }

  Future<void> screenAwake(bool enabled) async {
    if (supported) await channel.invokeMethod<void>('screenAwake', enabled);
  }
}

final studySoundProvider = Provider<StudySound>((ref) => StudySound());

final studySoundSettingsProvider =
    StateNotifierProvider<StudySoundController, AsyncValue<StudySoundSettings>>(
      (ref) => StudySoundController(ref.watch(studySoundProvider)),
    );

class StudySoundController
    extends StateNotifier<AsyncValue<StudySoundSettings>> {
  StudySoundController(this.adapter) : super(const AsyncLoading()) {
    ready = reload();
  }
  final StudySound adapter;
  late final Future<void> ready;
  bool busy = false;
  StudySoundSettings? _lastSaved;
  Future<void> reload() async {
    if (busy) return;
    busy = true;
    state = const AsyncLoading<StudySoundSettings>().copyWithPrevious(state);
    try {
      final value = await adapter.load();
      _lastSaved = StudySoundSettings.fromMap({
        'track': value.track,
        'volume': value.volume,
        'keepAwake': value.keepAwake,
      });
      if (mounted) state = AsyncData(_lastSaved!);
    } catch (error, stack) {
      if (mounted) {
        final failed = AsyncError<StudySoundSettings>(error, stack);
        state = _lastSaved == null
            ? failed
            : failed.copyWithPrevious(AsyncData(_lastSaved!));
      }
    } finally {
      busy = false;
    }
  }

  Future<bool> save(StudySoundSettings value) async {
    if (busy || _lastSaved == null) return false;
    busy = true;
    final previous = _lastSaved!;
    state = const AsyncLoading<StudySoundSettings>().copyWithPrevious(
      AsyncData(previous),
    );
    try {
      final validated = StudySoundSettings.fromMap({
        'track': value.track,
        'volume': value.volume,
        'keepAwake': value.keepAwake,
      });
      await adapter.save(validated);
      _lastSaved = validated;
      if (mounted) state = AsyncData(validated);
      return true;
    } catch (error, stack) {
      if (mounted) {
        state = AsyncError<StudySoundSettings>(
          error,
          stack,
        ).copyWithPrevious(AsyncData(previous));
      }
      return false;
    } finally {
      busy = false;
    }
  }
}
