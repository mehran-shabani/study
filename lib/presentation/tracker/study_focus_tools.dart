import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study/l10n/generated/app_localizations.dart';
import '../../data/study_sound.dart';
import '../../data/study_timer.dart';
import '../../data/study_timer_provider.dart';

class StudyFocusTools extends ConsumerStatefulWidget {
  const StudyFocusTools({
    super.key,
    required this.focusMinutes,
    required this.onModeChanged,
    required this.now,
  });
  final int focusMinutes;
  final ValueChanged<int> onModeChanged;
  final DateTime now;

  @override
  ConsumerState<StudyFocusTools> createState() => _StudyFocusToolsState();
}

class _StudyFocusToolsState extends ConsumerState<StudyFocusTools>
    with WidgetsBindingObserver {
  StudySoundSettings _sound = const StudySoundSettings();
  bool _loading = true;
  bool _saving = false;
  bool _failed = false;
  bool _foreground = true;
  bool _awake = false;
  late final StudySound _adapter;

  @override
  void initState() {
    super.initState();
    _adapter = ref.read(studySoundProvider);
    WidgetsBinding.instance.addObserver(this);
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final settings = await ref.read(studySoundProvider).load();
      if (mounted) {
        setState(() {
          _sound = settings;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _failed = true;
          _loading = false;
        });
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _awake = false;
      unawaited(_adapter.screenAwake(false).catchError((Object _) {}));
    }
    if (_foreground) unawaited(_load());
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Keep the native adapter before ConsumerState loses its ref.
    unawaited(_adapter.screenAwake(false).catchError((Object _) {}));
    super.dispose();
  }

  Future<void> _save({String? track, double? volume, bool? keepAwake}) async {
    if (_saving || _loading) return;
    final settings = StudySoundSettings(
      track: track ?? _sound.track,
      volume: volume ?? _sound.volume,
      keepAwake: keepAwake ?? _sound.keepAwake,
    );
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await ref.read(studySoundProvider).save(settings);
      if (mounted) setState(() => _sound = settings);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyTimerProvider);
    final session = state.session;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final supported = ref.read(studySoundProvider).supported;
    final desiredAwake =
        supported &&
        _foreground &&
        _sound.keepAwake &&
        session?.isRunning == true;
    if (_awake != desiredAwake) {
      _awake = desiredAwake;
      unawaited(
        ref.read(studySoundProvider).screenAwake(_awake).catchError((Object _) {
          if (mounted) setState(() => _failed = true);
        }),
      );
    }
    final elapsed = session?.elapsedAt(widget.now) ?? Duration.zero;
    final remaining = session == null
        ? Duration.zero
        : Duration(
            milliseconds: (session.focusTargetMs - elapsed.inMilliseconds)
                .clamp(0, 1 << 52),
          );
    final breakLeft =
        session?.breakEndsAt?.difference(widget.now) ?? Duration.zero;
    final isBreak = session?.isPaused == true && session?.breakEndsAt != null;
    return Column(
      children: [
        Card(
          key: const ValueKey('focus-tools'),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(l10n.focusCompanion, style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                if (session == null) ...[
                  DropdownButtonFormField<int>(
                    key: const ValueKey('focus-mode'),
                    initialValue: widget.focusMinutes,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l10n.focusMode),
                    items: [
                      for (final value in [0, 15, 25, 50])
                        DropdownMenuItem(
                          value: value,
                          child: Text(switch (value) {
                            15 => l10n.focusGentle,
                            25 => l10n.focusStandard,
                            50 => l10n.focusDeep,
                            _ => l10n.focusFree,
                          }),
                        ),
                    ],
                    onChanged: state.busy
                        ? null
                        : (value) => widget.onModeChanged(value!),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.focusModeHint, style: theme.textTheme.bodySmall),
                ],
                if (session != null &&
                    session.focusMinutes > 0 &&
                    !session.isStopped) ...[
                  if (!isBreak) ...[
                    Text(
                      l10n.focusRemaining(formatTimerDuration(remaining)),
                      key: const ValueKey('focus-remaining'),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value:
                          (1 -
                                  remaining.inMilliseconds /
                                      Duration(
                                        minutes: session.focusMinutes,
                                      ).inMilliseconds)
                              .clamp(0, 1),
                    ),
                    const SizedBox(height: 8),
                  ],
                  Text(l10n.focusRounds(session.roundsCompleted)),
                ],
                if (isBreak) ...[
                  Text(
                    breakLeft > Duration.zero
                        ? l10n.focusBreakRemaining(
                            formatTimerDuration(breakLeft),
                          )
                        : l10n.focusBreakReady,
                    key: const ValueKey('focus-break'),
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.focusBreakHint),
                ],
                if (session != null && !session.isStopped) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('focus-sleepy'),
                        onPressed: state.busy ? null : _sleepy,
                        icon: const Icon(Icons.self_improvement),
                        label: Text(l10n.focusSleepy),
                      ),
                    ],
                  ),
                  if (session.isRunning &&
                      session.focusMinutes > 0 &&
                      remaining <= const Duration(minutes: 2)) ...[
                    Text(
                      l10n.focusRecallTitle,
                      style: theme.textTheme.titleSmall,
                    ),
                    Text(l10n.focusRecall),
                  ] else
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(l10n.focusRecallTitle),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(l10n.focusRecall),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        ),
        Card(
          child: ExpansionTile(
            key: const ValueKey('focus-sound-panel'),
            onExpansionChanged: (open) {
              if (open) unawaited(_load());
            },
            leading: const Icon(Icons.headphones_outlined),
            title: Text(l10n.focusSound),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              if (!supported)
                Text(l10n.focusSoundUnsupported)
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final (id, label) in [
                      ('off', l10n.focusSoundOff),
                      ('melody', l10n.focusMelody),
                      ('rain', l10n.focusRain),
                      ('brown', l10n.focusBrown),
                    ])
                      ChoiceChip(
                        key: ValueKey('sound-$id'),
                        label: Text(label),
                        selected: _sound.track == id,
                        onSelected: _loading || _saving
                            ? null
                            : (_) => _save(track: id),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(l10n.focusSoundHint, style: theme.textTheme.bodySmall),
                Slider(
                  key: const ValueKey('focus-volume'),
                  value: _sound.volume.clamp(0, 0.6),
                  max: 0.6,
                  divisions: 12,
                  semanticFormatterCallback: (value) =>
                      '${l10n.focusVolume} ${(value * 100).round()}%',
                  onChanged: _loading || _saving
                      ? null
                      : (value) => setState(
                          () => _sound = StudySoundSettings(
                            track: _sound.track,
                            volume: value,
                            keepAwake: _sound.keepAwake,
                          ),
                        ),
                  onChangeEnd: (value) => _save(volume: value),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.focusKeepAwake),
                  subtitle: Text(l10n.focusKeepAwakeHint),
                  value: _sound.keepAwake,
                  onChanged: _loading || _saving
                      ? null
                      : (value) => _save(keepAwake: value),
                ),
              ],
              if (_failed)
                Text(
                  l10n.focusSoundFailed,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _sleepy() async {
    final l10n = AppLocalizations.of(context)!;
    final minutes = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(l10n.focusSleepy),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.focusSleepyHint),
            const SizedBox(height: 16),
            const SizedBox(height: 12),
            Text(
              l10n.focusSleepNote,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context, 3),
            child: Text(l10n.focusMoveBreak),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 20),
            child: Text(l10n.focusNap),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
        ],
      ),
    );
    if (minutes != null && mounted) {
      final success = await ref
          .read(studyTimerProvider.notifier)
          .takeBreak(minutes);
      if (!success && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.timerActionFailed)));
      }
    }
  }
}
