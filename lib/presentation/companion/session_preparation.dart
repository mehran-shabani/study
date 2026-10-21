import 'package:flutter/material.dart';
import 'package:study/l10n/generated/app_localizations.dart';
import '../../data/models.dart';
import '../../data/study_companion.dart';
import '../tracker/study_timer_screen.dart';
import 'companion_catalog.dart';

class SessionPreparation extends StatefulWidget {
  const SessionPreparation({
    super.key,
    required this.workspace,
    required this.subject,
    required this.minutes,
    this.method = 'read',
  });
  final Workspace workspace;
  final String subject;
  final int minutes;
  final String method;
  @override
  State<SessionPreparation> createState() => _SessionPreparationState();
}

class _SessionPreparationState extends State<SessionPreparation> {
  final _ready = <int>{};
  late int _minutes = widget.minutes;
  late String _method = widget.method;
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.companionPrepare),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.subject,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(l.companionPrepareHint),
              const SizedBox(height: 16),
              for (final (index, label) in [
                l.companionChecklistDesk,
                l.companionChecklistPhone,
                l.companionChecklistGoal,
              ].indexed)
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(label),
                  value: _ready.contains(index),
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      _ready.add(index);
                    } else {
                      _ready.remove(index);
                    }
                  }),
                ),
              const SizedBox(height: 12),
              Text(l.companionMethod),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: studyMethods
                    .map(
                      (m) => ChoiceChip(
                        label: Text(methodLabel(m, l)),
                        selected: m == _method,
                        onSelected: (_) => setState(() => _method = m),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              Text(methodPrompt(_method, l)),
              const SizedBox(height: 16),
              Text(l.companionMinutes),
              Wrap(
                spacing: 8,
                children: [15, 25, 50]
                    .map(
                      (m) => ChoiceChip(
                        label: Text(
                          l.minutesValue(companionNumber(context, m)),
                        ),
                        selected: m == _minutes,
                        onSelected: (_) => setState(() => _minutes = m),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l.cancel),
        ),
        FilledButton.icon(
          key: const ValueKey('prepared-start'),
          onPressed: () {
            final navigator = Navigator.of(context);
            navigator.pop();
            navigator.push(
              MaterialPageRoute<void>(
                builder: (_) => StudyTimerScreen(
                  workspace: widget.workspace,
                  initialSubject: widget.subject,
                  initialFocusMinutes: _minutes,
                ),
              ),
            );
          },
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(l.companionStart),
        ),
      ],
    );
  }
}
