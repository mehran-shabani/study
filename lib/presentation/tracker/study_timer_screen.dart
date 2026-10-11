import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../data/study_timer.dart';
import '../../data/study_timer_provider.dart';
import 'timer_subject_dialog.dart';

const timerButtonPink = Color(0xFFFFE1EC);
const timerButtonInk = Color(0xFF82334F);

class StudyTimerScreen extends ConsumerStatefulWidget {
  const StudyTimerScreen({super.key, this.workspace});
  final Workspace? workspace;

  @override
  ConsumerState<StudyTimerScreen> createState() => _StudyTimerScreenState();
}

class _StudyTimerScreenState extends ConsumerState<StudyTimerScreen>
    with WidgetsBindingObserver {
  Timer? _ticker;
  bool _foreground = true;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) {
      _ticker?.cancel();
      _ticker = null;
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyTimerProvider);
    final session = state.session;
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (session?.isRunning == true && _foreground) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
    final elapsed =
        session?.elapsedAt(ref.read(timerClockProvider)()) ?? Duration.zero;
    final status = session == null
        ? l10n.timerReady
        : session.isStopped
            ? l10n.timerFinished
            : session.isPaused
                ? l10n.timerPaused
                : l10n.timerRunning;
    final statusIcon = session == null
        ? Icons.schedule_rounded
        : session.isStopped
            ? Icons.check_circle_outline_rounded
            : session.isPaused
                ? Icons.pause_circle_outline_rounded
                : Icons.play_circle_outline_rounded;
    return Scaffold(
      key: const ValueKey('study-timer-screen'),
      appBar: AppBar(title: Text(l10n.studyTimer)),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  minHeight: (constraints.maxHeight - 48)
                      .clamp(0, double.infinity)
                      .toDouble()),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                          color: timerButtonPink,
                          borderRadius: BorderRadius.circular(24)),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(statusIcon, color: timerButtonInk, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                            child: Text(status,
                                style: const TextStyle(
                                    color: timerButtonInk,
                                    fontWeight: FontWeight.w600))),
                      ]),
                    ),
                    const SizedBox(height: 24),
                    Text(
                        session?.workspaceName ??
                            widget.workspace?.name ??
                            l10n.chooseWorkspace,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 32),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 40),
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                      child: Column(children: [
                        Semantics(
                          label: l10n.duration,
                          value: formatTimerDuration(elapsed),
                          child: ExcludeSemantics(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                formatTimerDuration(elapsed),
                                key: const ValueKey('timer-elapsed'),
                                textDirection: TextDirection.ltr,
                                style: theme.textTheme.displayLarge?.copyWith(
                                    fontSize: 64,
                                    fontWeight: FontWeight.w500,
                                    fontFeatures: const [
                                      ui.FontFeature.tabularFigures()
                                    ]),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(l10n.timerTimeUnits,
                            style: theme.textTheme.bodySmall),
                        const SizedBox(height: 20),
                        Text(
                            AppUtils.displayDate(AppUtils.formatDate(
                                session?.startedAt ??
                                    ref.read(timerClockProvider)())),
                            style: theme.textTheme.titleSmall),
                      ]),
                    ),
                    const SizedBox(height: 24),
                    Text(
                        session?.isStopped == true
                            ? l10n.timerFinishedHint
                            : l10n.timerPauseHint,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 24),
                    if (state.busy) const LinearProgressIndicator(),
                    if (state.error != null) ...[
                      Text(
                          state.error is TimerTooShortException
                              ? l10n.timerTooShort
                              : l10n.timerActionFailed,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: scheme.error)),
                      const SizedBox(height: 12),
                    ],
                    Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          if (session == null)
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  minimumSize: const Size(144, 56)),
                              key: const ValueKey('timer-start'),
                              onPressed: state.busy ? null : () => _start(),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: Text(state.error == null
                                  ? l10n.startTimer
                                  : l10n.retry),
                            ),
                          if (session?.isRunning == true)
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(144, 56)),
                              key: const ValueKey('timer-pause'),
                              onPressed: state.busy
                                  ? null
                                  : () => _perform(ref
                                      .read(studyTimerProvider.notifier)
                                      .pause),
                              icon: const Icon(Icons.pause_rounded),
                              label: Text(l10n.pauseTimer),
                            ),
                          if (session?.isPaused == true)
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  minimumSize: const Size(144, 56)),
                              key: const ValueKey('timer-resume'),
                              onPressed: state.busy
                                  ? null
                                  : () => _perform(ref
                                      .read(studyTimerProvider.notifier)
                                      .resume),
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: Text(l10n.resumeTimer),
                            ),
                          if (session != null && !session.isStopped)
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  minimumSize: const Size(144, 56)),
                              key: const ValueKey('timer-stop'),
                              onPressed: state.busy ? null : _stop,
                              icon: const Icon(Icons.stop_rounded),
                              label: Text(l10n.stopTimer),
                            ),
                          if (session?.isStopped == true)
                            FilledButton.icon(
                              style: FilledButton.styleFrom(
                                  minimumSize: const Size(144, 56)),
                              key: const ValueKey('timer-save'),
                              onPressed: state.busy ? null : _showSubject,
                              icon: const Icon(Icons.check_rounded),
                              label: Text(l10n.saveTimer),
                            ),
                        ]),
                    if (session != null) ...[
                      const SizedBox(height: 20),
                      TextButton.icon(
                        key: const ValueKey('timer-discard'),
                        onPressed: state.busy ? null : _discard,
                        style:
                            TextButton.styleFrom(foregroundColor: scheme.error),
                        icon: const Icon(Icons.delete_outline_rounded),
                        label: Text(l10n.discardTimer),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(l10n.timerBackgroundHint,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall),
                  ]),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Future<void> _start() async {
    final controller = ref.read(studyTimerProvider.notifier);
    if (ref.read(studyTimerProvider).error != null) {
      await _perform(controller.restore);
      return;
    }
    final workspace = widget.workspace;
    if (workspace != null) {
      await _perform(() => controller.start(workspace.id!, workspace.name));
    }
  }

  Future<bool> _perform(Future<bool> Function() action) async {
    if (ref.read(studyTimerProvider).busy) return false;
    final success = await action();
    if (mounted && !success) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              ref.read(studyTimerProvider).error is TimerTooShortException
                  ? l10n.timerTooShort
                  : l10n.timerActionFailed)));
    }
    return success;
  }

  Future<void> _stop() async {
    if (_dialogOpen) return;
    if (await _perform(ref.read(studyTimerProvider.notifier).stop) && mounted) {
      await _showSubject();
    }
  }

  Future<void> _showSubject() async {
    final session = ref.read(studyTimerProvider).session;
    if (_dialogOpen || session == null || !session.isStopped) return;
    _dialogOpen = true;
    try {
      await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => TimerSubjectDialog(session: session));
    } finally {
      _dialogOpen = false;
    }
  }

  Future<void> _discard() async {
    if (_dialogOpen) return;
    _dialogOpen = true;
    final l10n = AppLocalizations.of(context)!;
    bool? confirmed;
    try {
      confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: Text(l10n.discardTimer),
                content: Text(l10n.discardTimerPrompt),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(l10n.cancel)),
                  FilledButton(
                      style: FilledButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.error,
                          foregroundColor:
                              Theme.of(context).colorScheme.onError),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(l10n.delete)),
                ],
              ));
    } finally {
      _dialogOpen = false;
    }
    if (confirmed == true && mounted) {
      await _perform(ref.read(studyTimerProvider.notifier).discard);
    }
  }
}
