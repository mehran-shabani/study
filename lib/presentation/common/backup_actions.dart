import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study/l10n/generated/app_localizations.dart';
import '../../data/study_backup.dart';
import '../../data/providers.dart';
import '../../data/study_timer_provider.dart';
import '../../data/study_companion.dart';

class BackupActions extends ConsumerStatefulWidget {
  const BackupActions({super.key});
  @override
  ConsumerState<BackupActions> createState() => _BackupActionsState();
}

class _BackupActionsState extends ConsumerState<BackupActions> {
  bool _busy = false;
  Future<void> _perform(bool importing) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    if (ref.read(studyTimerProvider).busy ||
        ref.read(studyTimerProvider).session != null) {
      _message(l10n.backupFinishTimer);
      return;
    }
    setState(() => _busy = true);
    try {
      final backup = StudyBackup();
      if (importing) {
        final text = await backup.chooseFile();
        if (text == null || !mounted) return;
        final data = StudyBackup.decode(text);
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.restoreBackup),
            content: Text(
              l10n.backupMergePrompt(
                data.workspaces.length,
                data.entries.length,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(l10n.restoreBackup),
              ),
            ],
          ),
        );
        if (confirmed != true || !mounted) return;
        final count = await backup.importText(text);
        ref.invalidate(workspacesProvider);
        ref.invalidate(studyEntriesProvider);
        ref.invalidate(companionProvider);
        _message(l10n.backupImported(count));
      } else if (await backup.save()) {
        _message(l10n.backupSaved);
      }
    } catch (_) {
      _message(l10n.backupFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _message(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopupMenuButton<bool>(
      enabled: !_busy,
      tooltip: l10n.backupMenu,
      icon: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.backup_outlined),
      onSelected: _perform,
      itemBuilder: (_) => [
        PopupMenuItem(value: false, child: Text(l10n.saveBackup)),
        PopupMenuItem(value: true, child: Text(l10n.restoreBackup)),
      ],
    );
  }
}
