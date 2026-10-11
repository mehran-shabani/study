import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models.dart';
import '../../data/study_timer.dart';
import '../../data/study_timer_provider.dart';
import 'timer_subject_dialog.dart';

/// A smaller clock centered above Log study, like Drive's camera/+ buttons.
class StudyTimerActions extends ConsumerStatefulWidget {
  const StudyTimerActions({super.key, this.workspace, required this.onManual});
  final Workspace? workspace;
  final VoidCallback onManual;

  @override
  ConsumerState<StudyTimerActions> createState() => _StudyTimerActionsState();
}

class _StudyTimerActionsState extends ConsumerState<StudyTimerActions> {
  Timer? _ticker;
  bool _dialogOpen = false;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studyTimerProvider);
    final session = state.session;
    final l10n = AppLocalizations.of(context)!;
    if (session?.isRunning == true) {
      _ticker ??= Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
    if (widget.workspace == null && session == null) {
      return const SizedBox.shrink();
    }
    final elapsed = session == null
        ? null
        : formatTimerDuration(
            session.elapsedAt(ref.read(timerClockProvider)()));
    final tooltip = session == null
        ? (state.error == null ? l10n.startTimer : l10n.retry)
        : (session.isRunning ? l10n.stopTimer : l10n.saveTimer);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (session != null) ...[
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 160),
          child: Material(
            color: Theme.of(context).colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: state.busy ? null : _onTimerTap,
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(session.workspaceName,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(elapsed!,
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(session.isRunning ? l10n.stopTimer : l10n.saveTimer,
                      style: Theme.of(context).textTheme.labelSmall),
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
      FloatingActionButton.small(
        key: const ValueKey('study-timer-button'),
        heroTag: 'study-timer',
        tooltip: tooltip,
        onPressed: state.busy ? null : _onTimerTap,
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
        child: state.busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
            : Stack(clipBehavior: Clip.none, children: [
                const Icon(Icons.schedule_outlined),
                if (session != null)
                  Positioned(
                    right: -5,
                    bottom: -5,
                    child: Icon(
                        session.isRunning ? Icons.stop_circle : Icons.save,
                        size: 14),
                  ),
              ]),
      ),
      if (widget.workspace != null) ...[
        const SizedBox(height: 12),
        FloatingActionButton.extended(
          key: const ValueKey('log-study-button'),
          heroTag: 'log-study',
          onPressed: widget.onManual,
          icon: const Icon(Icons.add),
          label: Text(l10n.addEntry),
        ),
      ],
    ]);
  }

  Future<void> _onTimerTap() async {
    if (_dialogOpen) return;
    final state = ref.read(studyTimerProvider);
    if (state.busy) return;
    final controller = ref.read(studyTimerProvider.notifier);
    bool success;
    if (state.session == null) {
      if (state.error != null) {
        success = await controller.restore();
      } else {
        final workspace = widget.workspace;
        if (workspace == null) return;
        success = await controller.start(workspace.id!, workspace.name);
      }
    } else {
      success = await controller.stop();
    }
    if (!mounted) return;
    if (!success) {
      final l10n = AppLocalizations.of(context)!;
      final error = ref.read(studyTimerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(error is TimerTooShortException
              ? l10n.timerTooShort
              : l10n.timerActionFailed)));
      return;
    }
    final session = ref.read(studyTimerProvider).session;
    if (session != null && !session.isRunning) {
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
  }
}
