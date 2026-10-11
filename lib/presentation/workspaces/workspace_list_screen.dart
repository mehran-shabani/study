import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../data/models.dart';
import '../../core/utils.dart';
import '../../data/providers.dart';
import 'workspace_dialog.dart';
import '../common/empty_state.dart';

class WorkspaceListScreen extends ConsumerWidget {
  const WorkspaceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final workspacesAsync = ref.watch(workspacesProvider);
    final selectedWorkspaceId = ref.watch(selectedWorkspaceIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.workspaces),
      ),
      body: workspacesAsync.when(
        data: (workspaces) {
          if (workspaces.isEmpty) {
            return EmptyState(
                icon: Icons.event_note_outlined,
                title: l10n.noWorkspaces,
                message: l10n.createFirstWorkspace,
                actionLabel: l10n.addWorkspace,
                onAction: () => _showWorkspaceDialog(context, null));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: workspaces.length,
            itemBuilder: (context, index) {
              final workspace = workspaces[index];
              final isSelected = workspace.id == selectedWorkspaceId;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                color: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: ListTile(
                  onTap: () {
                    ref.read(selectedWorkspaceIdProvider.notifier).state =
                        workspace.id;
                    ref.read(mainTabProvider.notifier).state = 1;
                  },
                  leading: CircleAvatar(
                    backgroundColor: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.secondaryContainer,
                    child: Icon(
                      isSelected
                          ? Icons.check_circle_outline
                          : Icons.folder_outlined,
                      color: isSelected
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                  ),
                  title: Text(
                    '${workspace.name}${isSelected ? ' • ${l10n.activePlan}' : ''}',
                    style: TextStyle(
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  subtitle: Text(
                    '${l10n.from}: ${AppUtils.displayDate(workspace.startDate)} ${l10n.to}: ${AppUtils.displayDate(workspace.endDate)}\n'
                    '${l10n.dailyTarget}: ${l10n.hoursValue(AppUtils.formatHourValue(workspace.dailyTargetHours, locale: Localizations.localeOf(context).toString()))}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) async {
                      if (value == 'edit') {
                        await _showWorkspaceDialog(context, workspace);
                      } else if (value == 'delete') {
                        await _deleteWorkspace(context, ref, workspace);
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
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => EmptyState(
            icon: Icons.refresh,
            title: l10n.loadFailed,
            actionLabel: l10n.retry,
            onAction: () => ref.invalidate(workspacesProvider)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showWorkspaceDialog(context, null),
        icon: const Icon(Icons.add),
        label: Text(l10n.addWorkspace),
      ),
    );
  }

  Future<void> _showWorkspaceDialog(
    BuildContext context,
    Workspace? workspace,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => WorkspaceDialog(workspace: workspace),
    );
  }

  Future<void> _deleteWorkspace(
    BuildContext context,
    WidgetRef ref,
    Workspace workspace,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deleteWorkspace),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.deleteConfirmation),
            const SizedBox(height: 8),
            Text(
              l10n.deleteWorkspaceWarning,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ],
        ),
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

    if (confirmed == true && workspace.id != null) {
      final success = await ref
          .read(workspaceNotifierProvider.notifier)
          .deleteWorkspace(workspace.id!);
      if (success && ref.read(selectedWorkspaceIdProvider) == workspace.id) {
        ref.read(selectedWorkspaceIdProvider.notifier).state = null;
      }
      if (context.mounted && !success) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.deleteFailed)));
      }
    }
  }
}
