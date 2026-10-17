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
    final compactActions =
        MediaQuery.sizeOf(context).width < 400 ||
        MediaQuery.textScalerOf(context).scale(14) > 18;
    void openMore() => Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AnalyticsMoreScreen()),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.analytics),
        actions: [
          if (selectedWorkspace != null)
            if (compactActions)
              IconButton(
                key: const ValueKey('analytics-more'),
                tooltip: l10n.analyticsMoreTitle,
                onPressed: openMore,
                icon: const Icon(Icons.auto_awesome_outlined),
              )
            else
              TextButton.icon(
                key: const ValueKey('analytics-more'),
                onPressed: openMore,
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
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1080),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final wide = constraints.maxWidth >= 900;
                                final width = wide
                                    ? (constraints.maxWidth - 24) / 2
                                    : constraints.maxWidth;
                                return Wrap(
                                  spacing: 24,
                                  runSpacing: 24,
                                  children: [
                                    SizedBox(
                                      width: width,
                                      child: _ChartSection(
                                        title: l10n.dailyTimeline,
                                        icon: Icons.show_chart_rounded,
                                        child: TimelineChart(
                                          timeline: timeline,
                                        ),
                                      ),
                                    ),
                                    SizedBox(
                                      width: width,
                                      child: _ChartSection(
                                        title: l10n.hoursByTitle,
                                        icon: Icons.menu_book_outlined,
                                        child: TitleChart(
                                          titleHours: titleHours,
                                        ),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
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

class _ChartSection extends StatelessWidget {
  const _ChartSection({
    required this.title,
    required this.icon,
    required this.child,
  });
  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(title, style: Theme.of(context).textTheme.titleLarge),
          ),
        ],
      ),
      const SizedBox(height: 12),
      child,
    ],
  );
}
