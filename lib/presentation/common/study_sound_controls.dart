import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study/l10n/generated/app_localizations.dart';
import '../../data/study_sound.dart';

/// Shared controls keep Settings and the timer on the same saved sound state.
class StudySoundControls extends ConsumerStatefulWidget {
  const StudySoundControls({super.key});
  @override
  ConsumerState<StudySoundControls> createState() => _StudySoundControlsState();
}

class _StudySoundControlsState extends ConsumerState<StudySoundControls>
    with WidgetsBindingObserver {
  double? _volume;
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
    if (state == AppLifecycleState.resumed) {
      ref.read(studySoundSettingsProvider.notifier).reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!ref.watch(studySoundProvider).supported) {
      return Text(l10n.focusSoundUnsupported);
    }
    final async = ref.watch(studySoundSettingsProvider);
    final sound = async.valueOrNull;
    final controller = ref.read(studySoundSettingsProvider.notifier);
    final disabled = async.isLoading || sound == null;
    final labels = [
      l10n.focusSoundOff,
      l10n.focusMelody,
      l10n.soundPiano,
      l10n.soundLofi,
      l10n.soundAmbient,
      l10n.soundStrings,
      l10n.soundBells,
      l10n.focusRain,
      l10n.focusBrown,
      l10n.soundOcean,
      l10n.soundForest,
      l10n.soundStream,
      l10n.soundWhite,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (sound != null) ...[
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (var i = 0; i < studySoundTracks.length; i++)
                ChoiceChip(
                  key: ValueKey('sound-${studySoundTracks[i]}'),
                  label: Text(labels[i]),
                  selected: sound.track == studySoundTracks[i],
                  onSelected: disabled
                      ? null
                      : (_) => controller.save(
                          sound.copyWith(track: studySoundTracks[i]),
                        ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.focusSoundHint,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Text(
            '${l10n.focusVolume} · ${((_volume ?? sound.volume) * 100).round()}%',
          ),
          Slider(
            key: const ValueKey('focus-volume'),
            value: _volume ?? sound.volume,
            max: 0.6,
            divisions: 12,
            semanticFormatterCallback: (value) =>
                '${l10n.focusVolume} ${(value * 100).round()}%',
            onChanged: disabled
                ? null
                : (value) => setState(() => _volume = value),
            onChangeEnd: disabled
                ? null
                : (value) async {
                    await controller.save(sound.copyWith(volume: value));
                    if (mounted) setState(() => _volume = null);
                  },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l10n.focusKeepAwake),
            subtitle: Text(l10n.focusKeepAwakeHint),
            value: sound.keepAwake,
            onChanged: disabled
                ? null
                : (value) => controller.save(sound.copyWith(keepAwake: value)),
          ),
        ],
        if (async.isLoading) const LinearProgressIndicator(),
        if (async.hasError) ...[
          Text(
            l10n.focusSoundFailed,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          TextButton.icon(
            onPressed: async.isLoading ? null : controller.reload,
            icon: const Icon(Icons.refresh),
            label: Text(l10n.retry),
          ),
        ],
      ],
    );
  }
}
