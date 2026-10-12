import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study/l10n/generated/app_localizations.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../common/export_csv_button.dart';
import '../common/workspace_selector.dart';
import '../common/empty_state.dart';
import 'today_progress_card.dart';
import '../../core/utils.dart';
import 'entry_dialog.dart';
import 'study_timer_actions.dart';
import '../../data/study_timer.dart';

class TrackerScreen extends ConsumerWidget {
  const TrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selectedWorkspace = ref.watch(selectedWorkspaceProvider);
    final entriesAsync = ref.watch(studyEntriesProvider);
    final today = ref.watch(todayProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tracker),
        actions: [
          if (selectedWorkspace != null)
            ExportCsvButton(workspace: selectedWorkspace),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(64),
          child: WorkspaceSelector(),
        ),
      ),
      body: selectedWorkspace == null
          ? EmptyState(
              icon: Icons.folder_outlined,
              title: l10n.chooseWorkspace,
              message: l10n.selectWorkspace,
              actionLabel: l10n.workspaces,
              onAction: () => ref.read(mainTabProvider.notifier).state = 0,
            )
          : entriesAsync.when(
              data: (entries) {
                final todayHours = entries
                    .where((entry) => entry.entryDate == today)
                    .fold<double>(0, (sum, entry) => sum + entry.hours);
                final grouped = <String, List<StudyEntry>>{};
                for (final entry in entries) {
                  grouped.putIfAbsent(entry.entryDate, () => []).add(entry);
                }
                final dates = grouped.keys.toList()
                  ..sort((a, b) => b.compareTo(a));
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 240),
                  itemCount: dates.isEmpty ? 2 : dates.length + 2,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return TodayProgressCard(
                          workspace: selectedWorkspace,
                          hours: todayHours,
                          date: today);
                    }
                    if (index == 1) {
                      if (dates.isEmpty) {
                        return EmptyState(
                            icon: Icons.menu_book_outlined,
                            title: l10n.noEntries,
                            message: l10n.addFirstEntry,
                            actionLabel: l10n.addEntry,
                            onAction: () => _showEntryDialog(
                                context, selectedWorkspace.id!));
                      }
                      return Padding(
                          padding: const EdgeInsets.only(top: 24, bottom: 12),
                          child: Text(l10n.history,
                              style: Theme.of(context).textTheme.titleMedium));
                    }
                    final date = dates[index - 2];
                    return _buildDayCard(context, ref, date, grouped[date]!);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => EmptyState(
                icon: Icons.refresh,
                title: l10n.loadFailed,
                actionLabel: l10n.retry,
                onAction: () => ref.invalidate(studyEntriesProvider),
              ),
            ),
      floatingActionButtonLocation: const _RightAlignedFabLocation(),
      floatingActionButton: StudyTimerActions(
        workspace: selectedWorkspace,
        onManual: () {
          if (selectedWorkspace != null) {
            _showEntryDialog(context, selectedWorkspace.id!);
          }
        },
      ),
    );
  }

  Widget _buildDayCard(BuildContext context, WidgetRef ref, String date,
      List<StudyEntry> entries) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final hours = entries.fold<double>(0, (sum, entry) => sum + entry.hours);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(spacing: 12, runSpacing: 4, children: [
              Text(
                  date == AppUtils.today()
                      ? l10n.today
                      : AppUtils.displayDate(date),
                  style: theme.textTheme.titleSmall),
              Text(
                  l10n.hoursValue(AppUtils.formatHourValue(hours,
                      locale: Localizations.localeOf(context).toString())),
                  style: theme.textTheme.bodySmall),
            ])),
        const Divider(height: 1),
        for (final entry in entries) _buildEntryTile(context, ref, entry),
      ]),
    );
  }

  Widget _buildEntryTile(
      BuildContext context, WidgetRef ref, StudyEntry entry) {
    final l10n = AppLocalizations.of(context)!;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        child: Icon(
          Icons.edit_note,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
      onTap: () => _showEntryDialog(context, entry.workspaceId, entry),
      title: Text(
        entry.title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(entry.hours < 0.25
          ? '${l10n.duration}: ${formatTimerDuration(Duration(microseconds: (entry.hours * Duration.microsecondsPerHour).round()))}'
          : l10n.hoursValue(AppUtils.formatHourValue(entry.hours,
              locale: Localizations.localeOf(context).toString()))),
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          if (value == 'edit') {
            await _showEntryDialog(context, entry.workspaceId, entry);
          } else if (value == 'delete') {
            await _deleteEntry(context, ref, entry);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'edit',
            child: Row(
              children: [
                const Icon(Icons.edit),
                const SizedBox(width: 8),
                Text(l10n.edit),
              ],
            ),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                const Icon(Icons.delete),
                const SizedBox(width: 8),
                Text(l10n.delete),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showEntryDialog(
    BuildContext context,
    int workspaceId, [
    StudyEntry? entry,
  ]) async {
    await showDialog(
      context: context,
      builder: (context) => EntryDialog(
        workspaceId: workspaceId,
        entry: entry,
      ),
    );
  }

  Future<void> _deleteEntry(
    BuildContext context,
    WidgetRef ref,
    StudyEntry entry,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteEntry),
        content: Text(l10n.deleteSessionPrompt(entry.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.no),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.yes),
          ),
        ],
      ),
    );

    if (confirmed == true && entry.id != null) {
      final success = await ref
          .read(studyEntryNotifierProvider.notifier)
          .deleteEntry(entry.id!);
      if (context.mounted && !success) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.deleteFailed)));
      }
    }
  }
}

/// Keep both action buttons on the physical right, including Persian layouts.
class _RightAlignedFabLocation extends FloatingActionButtonLocation {
  const _RightAlignedFabLocation();

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry geometry) {
    final standard = FloatingActionButtonLocation.endFloat.getOffset(geometry);
    return Offset(
      geometry.scaffoldSize.width -
          geometry.floatingActionButtonSize.width -
          geometry.minInsets.right -
          kFloatingActionButtonMargin,
      standard.dy,
    );
  }
}
