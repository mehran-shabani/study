import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study/l10n/generated/app_localizations.dart';
import '../../data/providers.dart';

/// Change the active plan without leaving the study/report screen.
class WorkspaceSelector extends ConsumerWidget {
  const WorkspaceSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workspaces = ref.watch(workspacesProvider);
    final selectedId = ref.watch(selectedWorkspaceIdProvider);
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: workspaces.when(
        data: (plans) => plans.isEmpty
            ? const SizedBox.shrink()
            : DropdownButtonHideUnderline(
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: plans.any((plan) => plan.id == selectedId)
                      ? selectedId
                      : null,
                  hint: Text(l10n.chooseWorkspace),
                  icon: const Icon(Icons.expand_more),
                  items: plans
                      .map((plan) => DropdownMenuItem<int>(
                            value: plan.id,
                            child: Row(children: [
                              const Icon(Icons.folder_outlined, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                  child: Text(plan.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis)),
                            ]),
                          ))
                      .toList(),
                  onChanged: (id) =>
                      ref.read(selectedWorkspaceIdProvider.notifier).state = id,
                ),
              ),
        loading: () => const LinearProgressIndicator(),
        error: (_, __) => const SizedBox.shrink(),
      ),
    );
  }
}
