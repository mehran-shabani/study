import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study/l10n/generated/app_localizations.dart';
import '../../data/providers.dart';
import '../common/export_csv_button.dart';
import '../common/workspace_selector.dart';
import '../common/empty_state.dart';
import '../../domain/helpers.dart';
import 'progress_card.dart';
import 'timeline_chart.dart';
import 'title_chart.dart';
import 'analytics_more_screen.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selectedWorkspace = ref.watch(selectedWorkspaceProvider);
    final entriesAsync = ref.watch(studyEntriesProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.analytics),
        actions: [
          if (selectedWorkspace != null)
            TextButton.icon(
              key: const ValueKey('analytics-more'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const AnalyticsMoreScreen(),
                ),
              ),
              icon: const Icon(Icons.auto_awesome_outlined, size: 18),
              label: Text(l10n.analyticsMore),
            ),
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
                final progress = calcProgress(entries, selectedWorkspace);
                final timeline = buildTimeline(entries, selectedWorkspace);
                final titleHours = aggHoursByTitle(entries);

                return SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProgressCard(
                        progress: progress,
                        entries: entries,
                        workspace: selectedWorkspace,
                      ),
                      if (entries.isEmpty)
                        EmptyState(
                          icon: Icons.menu_book_outlined,
                          title: l10n.noEntries,
                          message: l10n.addFirstEntry,
                          actionLabel: l10n.addEntry,
                          onAction: () =>
                              ref.read(mainTabProvider.notifier).state = 1,
                        )
                      else ...[
                        const SizedBox(height: 24),
                        Text(
                          l10n.dailyTimeline,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        TimelineChart(timeline: timeline),
                        const SizedBox(height: 24),
                        Text(
                          l10n.hoursByTitle,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 12),
                        TitleChart(titleHours: titleHours),
                      ],
                    ],
                  ),
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
    );
  }
}
