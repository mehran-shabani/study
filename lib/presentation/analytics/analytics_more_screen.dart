import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:study/l10n/generated/app_localizations.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../domain/study_insights.dart';
import '../common/empty_state.dart';
import '../common/workspace_selector.dart';
import '../workspaces/workspace_dialog.dart';
import 'ai_share_card.dart';

class AnalyticsMoreScreen extends ConsumerWidget {
  const AnalyticsMoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final workspace = ref.watch(selectedWorkspaceProvider);
    final entries = ref.watch(studyEntriesProvider);
    final today = ref.watch(todayProvider);
    return Scaffold(
      key: const ValueKey('analytics-more-screen'),
      appBar: AppBar(
        title: Text(l10n.analyticsMoreTitle),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(64),
          child: WorkspaceSelector(),
        ),
      ),
      body: workspace == null
          ? EmptyState(
              icon: Icons.folder_outlined,
              title: l10n.chooseWorkspace,
              message: l10n.selectWorkspace,
              actionLabel: l10n.workspaces,
              onAction: () {
                ref.read(mainTabProvider.notifier).state = 0;
                Navigator.of(context).pop();
              },
            )
          : entries.when(
              data: (items) => _InsightsBody(
                key: ValueKey('${workspace.id}-$today'),
                workspace: workspace,
                insights: StudyInsights(
                  items,
                  workspace,
                  AppUtils.parseDate(today),
                ),
                onStudy: () {
                  ref.read(mainTabProvider.notifier).state = 1;
                  Navigator.of(context).pop();
                },
              ),
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

class _InsightsBody extends StatefulWidget {
  const _InsightsBody({
    super.key,
    required this.workspace,
    required this.insights,
    required this.onStudy,
  });
  final Workspace workspace;
  final StudyInsights insights;
  final VoidCallback onStudy;

  @override
  State<_InsightsBody> createState() => _InsightsBodyState();
}

class _InsightsBodyState extends State<_InsightsBody> {
  double? _budget;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final insights = widget.insights;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    String number(num value) => NumberFormat('0', locale).format(value);
    String hours(double value) =>
        l10n.hoursValue(AppUtils.formatHourValue(value, locale: locale));
    String minutes(int value) => l10n.insightMinutes(number(value));
    final budget = _budget ?? insights.suggestedHours;
    final plan = insights.plan(budget);
    final week = insights.recentWeek;
    final required = insights.requiredDailyHours;
    final finish = insights.estimatedFinish;
    return SafeArea(
      child: SingleChildScrollView(
        key: const ValueKey('more-insights-scroll'),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AiShareCard(insights: insights, tomorrowHours: _budget),
                const SizedBox(height: 24),
                Text(l10n.insightsIntro, style: theme.textTheme.bodyLarge),
                const SizedBox(height: 16),
                _InsightCard(
                  icon: Icons.wb_sunny_outlined,
                  title: l10n.tomorrowPlan,
                  color: theme.colorScheme.surface,
                  children: [
                    Text(
                      AppUtils.displayDate(
                        AppUtils.formatDate(insights.tomorrow),
                      ),
                      style: theme.textTheme.labelLarge,
                    ),
                    const SizedBox(height: 12),
                    if (!insights.canPlanTomorrow) ...[
                      Text(
                        insights.isUpcoming
                            ? l10n.planNotStarted(
                                AppUtils.displayDate(
                                  widget.workspace.startDate,
                                ),
                              )
                            : l10n.planFinished,
                      ),
                      TextButton.icon(
                        onPressed: () => showDialog<void>(
                          context: context,
                          builder: (_) =>
                              WorkspaceDialog(workspace: widget.workspace),
                        ),
                        icon: const Icon(Icons.edit_outlined),
                        label: Text(l10n.editWorkspace),
                      ),
                    ] else ...[
                      Text(
                        hours(budget),
                        style: theme.textTheme.headlineMedium,
                      ),
                      Text(
                        insights.recentWeek.activeDays == 0
                            ? l10n.tomorrowStartReason
                            : l10n.tomorrowHistoryReason,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.tomorrowAvailableTime,
                        style: theme.textTheme.titleSmall,
                      ),
                      Slider(
                        key: const ValueKey('tomorrow-budget'),
                        min: 0.25,
                        max: 24,
                        divisions: 95,
                        value: budget.clamp(0.25, 24),
                        label: hours(budget),
                        semanticFormatterCallback: hours,
                        onChanged: (value) => setState(() => _budget = value),
                      ),
                      if (_budget != null)
                        TextButton(
                          onPressed: () => setState(() => _budget = null),
                          child: Text(l10n.resetSuggestion),
                        ),
                      Text(
                        l10n.tomorrowDraftNote,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: 12),
                      if (plan.reviewMinutes > 0)
                        _ActionStep(
                          icon: Icons.replay_rounded,
                          title: l10n.reviewBlock(
                            plan.reviewTitle!,
                            minutes(plan.reviewMinutes),
                          ),
                          description: l10n.retrievalInstruction,
                        ),
                      _ActionStep(
                        icon: Icons.menu_book_outlined,
                        title: l10n.focusBlock(
                          plan.focusTitle ?? l10n.chooseStudySubject,
                          minutes(plan.focusMinutes),
                        ),
                        description: l10n.focusInstruction,
                      ),
                      _ActionStep(
                        icon: Icons.fact_check_outlined,
                        title: l10n.endSessionCheck,
                        description: l10n.endSessionInstruction,
                      ),
                      const SizedBox(height: 8),
                      FilledButton.icon(
                        onPressed: widget.onStudy,
                        icon: const Icon(Icons.edit_note),
                        label: Text(l10n.goToStudy),
                      ),
                    ],
                  ],
                ),
                _InsightCard(
                  icon: Icons.date_range_outlined,
                  title: l10n.completedWeek,
                  children: [
                    Text(
                      l10n.completedWeekNote,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    if (week.days.isEmpty)
                      Text(l10n.noCompletedDays)
                    else ...[
                      Text(
                        '${AppUtils.displayDate(week.days.first.date)} — '
                        '${AppUtils.displayDate(week.days.last.date)}',
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _Metric(
                            label: l10n.totalHours,
                            value: hours(week.hours),
                          ),
                          _Metric(
                            label: l10n.dailyAverage,
                            value: hours(week.average),
                          ),
                          _Metric(
                            label: l10n.activeStudyDays,
                            value:
                                '${number(week.activeDays)} / ${number(week.days.length)}',
                          ),
                          _Metric(
                            label: l10n.goalMetDays,
                            value:
                                '${number(week.goalDays)} / ${number(week.days.length)}',
                          ),
                          _Metric(
                            label: l10n.studyStreak,
                            value: l10n.insightDays(number(insights.streak)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        insights.canCompareWeeks
                            ? insights.weekChange > 0
                                  ? l10n.weekIncrease(
                                      hours(insights.weekChange),
                                    )
                                  : insights.weekChange < 0
                                  ? l10n.weekDecrease(
                                      hours(insights.weekChange.abs()),
                                    )
                                  : l10n.weekUnchanged
                            : l10n.weekComparisonPending,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final day in week.days)
                            _DayTile(
                              day: day,
                              target: widget.workspace.dailyTargetHours,
                              hours: hours(day.hours),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.missingDaysNote,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
                _InsightCard(
                  icon: Icons.replay_outlined,
                  title: l10n.reviewCandidates,
                  children: [
                    Text(l10n.reviewCandidatesNote),
                    const SizedBox(height: 12),
                    if (insights.reviewSubjects.isEmpty)
                      Text(l10n.reviewNeedsHistory)
                    else ...[
                      for (final subject in insights.reviewSubjects.take(5))
                        _ActionStep(
                          icon: Icons.bookmark_border,
                          title: subject.title,
                          description: l10n.lastStudied(
                            AppUtils.displayDate(subject.lastDate),
                            number(subject.daysAgo),
                          ),
                        ),
                      Text(
                        l10n.reviewNotMastery,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
                _InsightCard(
                  icon: Icons.flag_outlined,
                  title: l10n.goalOutlook,
                  children: [
                    Text(l10n.timeGoalNote, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 12),
                    _ActionStep(
                      icon: Icons.timelapse,
                      title: l10n.remainingStudy(
                        hours(insights.remainingHours),
                      ),
                      description: l10n.daysAfterToday(
                        number(insights.remainingDays),
                      ),
                    ),
                    if (insights.remainingHours == 0)
                      Text(l10n.timeGoalComplete)
                    else if (required == null)
                      Text(l10n.goalPeriodEnded)
                    else ...[
                      Text(l10n.requiredPace(hours(required))),
                      const SizedBox(height: 8),
                      if (required > 24)
                        Text(l10n.paceImpossible)
                      else if (required > insights.suggestedHours * 1.5)
                        Text(l10n.paceNeedsAdjustment),
                      const SizedBox(height: 8),
                      if (finish != null)
                        Text(
                          l10n.estimatedGoalDate(
                            AppUtils.displayDate(AppUtils.formatDate(finish)),
                          ),
                        )
                      else
                        Text(
                          week.days.length == 7 && week.average > 0
                              ? l10n.forecastTooDistant
                              : l10n.forecastNeedsHistory,
                        ),
                      Text(l10n.forecastNote, style: theme.textTheme.bodySmall),
                    ],
                    TextButton.icon(
                      onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) =>
                            WorkspaceDialog(workspace: widget.workspace),
                      ),
                      icon: const Icon(Icons.tune),
                      label: Text(l10n.editWorkspace),
                    ),
                  ],
                ),
                _InsightCard(
                  icon: Icons.lightbulb_outline,
                  title: l10n.betterLearning,
                  children: [
                    _ActionStep(
                      icon: Icons.psychology_outlined,
                      title: l10n.retrievalTitle,
                      description: l10n.retrievalTip,
                    ),
                    _ActionStep(
                      icon: Icons.event_repeat_outlined,
                      title: l10n.spacingTitle,
                      description: l10n.spacingTip,
                    ),
                    _ActionStep(
                      icon: Icons.checklist_outlined,
                      title: l10n.reflectionTitle,
                      description: l10n.reflectionTip,
                    ),
                    ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      title: Text(l10n.insightMethod),
                      children: [
                        Text(l10n.insightMethodDetails),
                        const SizedBox(height: 12),
                        const SelectableText(
                          'Dunlosky et al. (2013)\n'
                          'https://doi.org/10.1177/1529100612453266\n\n'
                          'The Learning Scientists — Spacing & retrieval\n'
                          'https://www.learningscientists.org/learning-scientists-podcast/'
                          '2018/3/7/episode-14-how-students-can-use-spacing-and-retrieval-practice',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.icon,
    required this.title,
    required this.children,
    this.color,
  });
  final IconData icon;
  final String title;
  final List<Widget> children;
  final Color? color;

  @override
  Widget build(BuildContext context) => Card(
    color: color,
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
}

class _ActionStep extends StatelessWidget {
  const _ActionStep({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title, description;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(description),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 140,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: Theme.of(context).textTheme.titleLarge),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ),
  );
}

class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.day,
    required this.target,
    required this.hours,
  });
  final DailyStudy day;
  final double target;
  final String hours;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${AppUtils.displayDate(day.date)}, $hours',
    excludeSemantics: true,
    child: Container(
      width: 90,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(AppUtils.displayDate(day.date).substring(5)),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: (day.hours / target).clamp(0, 1)),
          const SizedBox(height: 8),
          Text(hours, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}
