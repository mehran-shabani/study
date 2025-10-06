import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../core/utils.dart';
import 'entry_dialog.dart';

class TrackerScreen extends ConsumerWidget {
  const TrackerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selectedWorkspace = ref.watch(selectedWorkspaceProvider);
    final entriesAsync = ref.watch(studyEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.tracker),
        bottom: selectedWorkspace != null
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 20,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          selectedWorkspace.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
      body: selectedWorkspace == null
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_off_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      l10n.selectWorkspace,
                      style: Theme.of(context).textTheme.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            )
          : entriesAsync.when(
              data: (entries) {
                if (entries.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.note_add_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          l10n.noEntries,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.addFirstEntry,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  );
                }

                // Group entries by date
                final groupedEntries = <String, List<StudyEntry>>{};
                for (final entry in entries) {
                  groupedEntries.putIfAbsent(entry.entryDate, () => []).add(entry);
                }

                final dates = groupedEntries.keys.toList()..sort((a, b) => b.compareTo(a));

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: dates.length,
                  itemBuilder: (context, index) {
                    final date = dates[index];
                    final dateEntries = groupedEntries[date]!;
                    final totalHours = dateEntries.fold<double>(
                      0.0,
                      (sum, entry) => sum + entry.hours,
                    );

                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primaryContainer,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(12),
                                topRight: Radius.circular(12),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 20,
                                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    date,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).colorScheme.primary,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    AppUtils.formatHours(totalHours),
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onPrimary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...dateEntries.map((entry) => _buildEntryTile(context, ref, entry)),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stack) => Center(
                child: Text('${l10n.errorOccurred}: $error'),
              ),
            ),
      floatingActionButton: selectedWorkspace != null
          ? FloatingActionButton.extended(
              onPressed: () => _showEntryDialog(context, selectedWorkspace.id!),
              icon: const Icon(Icons.add),
              label: Text(l10n.addEntry),
            )
          : null,
    );
  }

  Widget _buildEntryTile(BuildContext context, WidgetRef ref, StudyEntry entry) {
    final l10n = AppLocalizations.of(context)!;

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
        child: Icon(
          Icons.edit_note,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
      title: Text(
        entry.title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(AppUtils.formatHours(entry.hours)),
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
        content: Text(l10n.deleteConfirmation),
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
      await ref.read(studyEntryNotifierProvider.notifier).deleteEntry(entry.id!);
    }
  }
}
