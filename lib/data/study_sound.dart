import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class StudySoundSettings {
  const StudySoundSettings({
    this.track = 'off',
    this.volume = 0.25,
    this.keepAwake = false,
  });
  final String track;
  final double volume;
  final bool keepAwake;
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
    return StudySoundSettings(
      track: map?['track'] as String? ?? 'off',
      volume: (map?['volume'] as num?)?.toDouble() ?? 0.25,
      keepAwake: map?['keepAwake'] as bool? ?? false,
    );
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
