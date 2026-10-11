import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models.dart';
import '../../data/study_timer_provider.dart';
import 'study_timer_screen.dart';

/// Physical right alignment is intentional in both Persian and English.
class StudyTimerActions extends ConsumerWidget {
  const StudyTimerActions({super.key, this.workspace, required this.onManual});
  final Workspace? workspace;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(studyTimerProvider);
    final session = state.session;
    final l10n = AppLocalizations.of(context)!;
    if (workspace == null && session == null) return const SizedBox.shrink();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      textDirection: TextDirection.ltr,
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: FloatingActionButton(
            key: const ValueKey('study-timer-button'),
            heroTag: 'study-timer',
            tooltip: l10n.studyTimer,
            backgroundColor: timerButtonPink,
            foregroundColor: timerButtonInk,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => StudyTimerScreen(workspace: workspace))),
            child: Stack(clipBehavior: Clip.none, children: [
              const Icon(Icons.schedule_rounded, size: 34),
              if (session != null)
                Positioned(
                  right: -5,
                  bottom: -5,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                        color: timerButtonPink, shape: BoxShape.circle),
                    child: Icon(
                        session.isPaused
                            ? Icons.pause_rounded
                            : session.isStopped
                                ? Icons.check_rounded
                                : Icons.play_arrow_rounded,
                        size: 16),
                  ),
                ),
            ]),
          ),
        ),
        if (workspace != null) ...[
          const SizedBox(height: 12),
          FloatingActionButton.extended(
            key: const ValueKey('log-study-button'),
            heroTag: 'log-study',
            onPressed: onManual,
            icon: const Icon(Icons.add),
            label: Text(l10n.addEntry),
          ),
        ],
      ],
    );
  }
}
