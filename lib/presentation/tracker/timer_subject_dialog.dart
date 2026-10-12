import 'package:flutter/material.dart';
import 'package:study/l10n/generated/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils.dart';
import '../../data/study_timer.dart';
import '../../data/study_timer_provider.dart';

class TimerSubjectDialog extends ConsumerStatefulWidget {
  const TimerSubjectDialog({super.key, required this.session});
  final StudyTimerSession session;

  @override
  ConsumerState<TimerSubjectDialog> createState() => _TimerSubjectDialogState();
}

class _TimerSubjectDialogState extends ConsumerState<TimerSubjectDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _subject;
  bool _saving = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _subject = TextEditingController(text: widget.session.subject);
  }

  @override
  void dispose() {
    _subject.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = widget.session;
    final entries = session.entriesFor('');
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(l10n.saveTimer),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.workspaceName,
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(
                      formatTimerDuration(
                          session.elapsedAt(session.stoppedAt!)),
                      textDirection: TextDirection.ltr,
                      style: Theme.of(context).textTheme.headlineMedium),
                  const SizedBox(height: 8),
                  for (final entry in entries)
                    Text('${AppUtils.displayDate(entry.entryDate)} • '
                        '${formatTimerDuration(Duration(microseconds: (entry.hours * Duration.microsecondsPerHour).round()))}'),
                  if (entries.length > 1) ...[
                    const SizedBox(height: 8),
                    Text(l10n.timerSplitDays),
                  ],
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('timer-subject'),
                    controller: _subject,
                    enabled: !_saving,
                    autofocus: true,
                    maxLength: 80,
                    decoration: InputDecoration(
                      labelText: l10n.entryTitle,
                      hintText: l10n.entryTitleHint,
                      prefixIcon: const Icon(Icons.menu_book_outlined),
                    ),
                    validator: (value) =>
                        AppUtils.validateEntryTitle(value) == null
                            ? null
                            : l10n.requiredField,
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _save(),
                  ),
                  if (_failed)
                    Text(l10n.saveFailed,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _saveLater,
            child: Text(l10n.saveTimerLater),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? l10n.saving : l10n.save),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _failed = false;
    });
    final success =
        await ref.read(studyTimerProvider.notifier).save(_subject.text);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _failed = !success;
    });
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.sessionSaved)));
      Navigator.of(context).pop();
    }
  }

  Future<void> _saveLater() async {
    if (_saving) return;
    setState(() => _saving = true);
    final success = await ref
        .read(studyTimerProvider.notifier)
        .rememberSubject(_subject.text);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _failed = !success;
    });
    if (success) Navigator.of(context).pop();
  }
}
