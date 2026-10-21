import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study/l10n/generated/app_localizations.dart';
import '../../core/design_tokens.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../data/study_companion.dart';
import '../../data/study_timer_provider.dart';
import '../common/empty_state.dart';
import '../common/workspace_selector.dart';
import '../tracker/study_timer_screen.dart';
import '../tracker/today_progress_card.dart';
import 'companion_catalog.dart';
import 'companion_editors.dart';
import 'focus_games_screen.dart';
import 'session_preparation.dart';

class CompanionScreen extends ConsumerStatefulWidget {
  const CompanionScreen({super.key});
  @override
  ConsumerState<CompanionScreen> createState() => _CompanionScreenState();
}

class _CompanionScreenState extends ConsumerState<CompanionScreen> {
  String? _browsingDate;
  bool _openingGame = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final workspace = ref.watch(selectedWorkspaceProvider);
    final today = ref.watch(todayProvider);
    final date = _browsingDate ?? today;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.myDay),
        actions: [
          IconButton(
            tooltip: l.companionWarmup,
            icon: const Icon(Icons.extension_outlined),
            onPressed: () => _games(),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(64),
          child: WorkspaceSelector(),
        ),
      ),
      body: workspace == null
          ? ListView(
              padding: const EdgeInsets.all(StudyDesign.page),
              children: [
                _hero(l),
                const SizedBox(height: 24),
                EmptyState(
                  icon: Icons.school_outlined,
                  title: l.companionSetup,
                  message: l.companionSetupHint,
                  actionLabel: l.workspaces,
                  onAction: () => ref.read(mainTabProvider.notifier).state = 0,
                ),
                const SizedBox(height: 20),
                _gamesCard(l),
              ],
            )
          : _planBody(workspace, today, date, l),
    );
  }

  Widget _planBody(
    Workspace workspace,
    String today,
    String date,
    AppLocalizations l,
  ) {
    final state = ref.watch(companionProvider(workspace.id!));
    if (state.loading) return const Center(child: CircularProgressIndicator());
    if (state.loadFailed) {
      return EmptyState(
        icon: Icons.refresh,
        title: l.loadFailed,
        actionLabel: l.retry,
        onAction: ref.read(companionProvider(workspace.id!).notifier).load,
      );
    }
    final plan = state.plan;
    final day = plan.day(date);
    final selected = plan.selectedCourse;
    final todayEntries = ref.watch(studyEntriesProvider);
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: StudyDesign.contentWidth),
        child: ListView(
          key: const PageStorageKey('companion-day'),
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            _hero(l),
            const SizedBox(height: 20),
            if (state.busy) const LinearProgressIndicator(),
            if (state.error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  l.saveFailed,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            _section(
              l.companionCourses,
              action: TextButton.icon(
                key: const ValueKey('manage-courses'),
                onPressed: state.busy
                    ? null
                    : () => _edit(workspace.id!, date, CompanionEdit.courses),
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: Text(l.companionCustomize),
              ),
            ),
            if (plan.courses.isEmpty)
              _panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.medical_services_outlined),
                    const SizedBox(height: 12),
                    Text(
                      l.companionNoCourses,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(l.companionNoCoursesHint),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: state.busy
                          ? null
                          : () => _edit(
                              workspace.id!,
                              date,
                              CompanionEdit.courses,
                            ),
                      child: Text(l.companionCustomize),
                    ),
                  ],
                ),
              )
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: plan.courses
                    .map(
                      (course) => ChoiceChip(
                        avatar: Icon(
                          course.priority == 3
                              ? Icons.flag_outlined
                              : Icons.menu_book_outlined,
                          size: 18,
                        ),
                        label: Text(courseLabel(course, l)),
                        selected: course.id == selected?.id,
                        onSelected: state.busy
                            ? null
                            : (_) async {
                                final success = await _update(
                                  workspace.id!,
                                  (p) =>
                                      p.copyWith(selectedCourseId: course.id),
                                );
                                if (success && mounted) {
                                  ref
                                      .read(
                                        selectedStudySubjectProvider(
                                          workspace.id!,
                                        ).notifier,
                                      )
                                      .state = courseLabel(
                                    course,
                                    l,
                                  );
                                }
                              },
                      ),
                    )
                    .toList(),
              ),
              if (selected != null) _courseDetail(workspace, selected, date, l),
            ],
            const SizedBox(height: 20),
            _section(l.companionEnergy),
            _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.companionEnergyHint),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final (index, label) in [
                        l.companionTired,
                        l.companionSteady,
                        l.companionReady,
                      ].indexed)
                        ChoiceChip(
                          label: Text(label),
                          selected: day.energy == index + 1,
                          onSelected: state.busy
                              ? null
                              : (_) => _update(
                                  workspace.id!,
                                  (p) => p.withDay(
                                    date,
                                    p.day(date).copyWith(energy: index + 1),
                                  ),
                                ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (date == today)
              todayEntries.when(
                data: (entries) => TodayProgressCard(
                  workspace: workspace,
                  hours: entries
                      .where(
                        (e) =>
                            e.entryDate == today &&
                            e.workspaceId == workspace.id,
                      )
                      .fold<double>(0, (sum, e) => sum + e.hours),
                  date: today,
                ),
                loading: () => const LinearProgressIndicator(),
                error: (_, __) => TextButton.icon(
                  onPressed: () => ref.invalidate(studyEntriesProvider),
                  icon: const Icon(Icons.refresh),
                  label: Text(l.retry),
                ),
              ),
            const SizedBox(height: 20),
            _section(
              l.companionTodayPlan,
              action: IconButton(
                tooltip: l.companionAddTask,
                icon: const Icon(Icons.add_circle_outline),
                onPressed: state.busy || plan.courses.isEmpty
                    ? null
                    : () => _edit(workspace.id!, date, CompanionEdit.task),
              ),
            ),
            _dateNavigation(date, today, l),
            const SizedBox(height: 8),
            _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l.companionPlanHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 20,
                    runSpacing: 8,
                    children: [
                      _metric(
                        companionNumber(
                          context,
                          day.tasks.fold<int>(0, (sum, t) => sum + t.minutes),
                        ),
                        l.companionPlannedMinutes,
                      ),
                      _metric(
                        '${companionNumber(context, day.tasks.where((t) => t.done).length)} / ${companionNumber(context, day.tasks.length)}',
                        l.companionCompleted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (day.tasks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(l.companionEmptyTasks),
                    ),
                  for (final task in day.tasks)
                    _taskTile(workspace, date, task, state.busy, l),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const ValueKey('add-daily-task'),
                    onPressed: state.busy || plan.courses.isEmpty
                        ? null
                        : () => _edit(workspace.id!, date, CompanionEdit.task),
                    icon: const Icon(Icons.add),
                    label: Text(l.companionAddTask),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _gamesCard(l),
            const SizedBox(height: 20),
            _panel(
              tinted: true,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.spa_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l.companionBreaks,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(l.companionBreakHint),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _section(
              l.companionEvening,
              action: IconButton(
                tooltip: l.edit,
                onPressed: state.busy
                    ? null
                    : () =>
                          _edit(workspace.id!, date, CompanionEdit.reflection),
                icon: const Icon(Icons.edit_outlined),
              ),
            ),
            _panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (day.reflection.isNotEmpty) ...[
                    Text(
                      l.companionSavedReflection,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(day.reflection),
                    const SizedBox(height: 16),
                  ],
                  if (day.tomorrow.isNotEmpty) ...[
                    Text(
                      l.companionTomorrow,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(day.tomorrow),
                    const SizedBox(height: 16),
                  ],
                  OutlinedButton.icon(
                    onPressed: state.busy
                        ? null
                        : () => _edit(
                            workspace.id!,
                            date,
                            CompanionEdit.reflection,
                          ),
                    icon: const Icon(Icons.nights_stay_outlined),
                    label: Text(l.companionEvening),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(AppLocalizations l) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [c.primaryContainer, c.surfaceContainerLow],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.monitor_heart_outlined,
                size: 20,
                color: c.onPrimaryContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l.companionEyebrow,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: c.onPrimaryContainer,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            l.companionGreeting,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: c.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l.companionIntro,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: c.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, {Widget? action}) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        if (action != null) action,
      ],
    ),
  );
  Widget _panel({required Widget child, bool tinted = false}) => Card(
    color: tinted ? Theme.of(context).colorScheme.secondaryContainer : null,
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
  Widget _metric(String number, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        number,
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      Text(label, style: Theme.of(context).textTheme.bodySmall),
    ],
  );

  Widget _courseDetail(
    Workspace workspace,
    MedicalCourse course,
    String date,
    AppLocalizations l,
  ) {
    final today = AppUtils.parseDate(ref.watch(todayProvider));
    final days = course.examDate == null
        ? null
        : DateTime.utc(
            AppUtils.parseDate(course.examDate!).year,
            AppUtils.parseDate(course.examDate!).month,
            AppUtils.parseDate(course.examDate!).day,
          ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
    final session = ref.watch(studyTimerProvider).session;
    final priorities = [l.companionLow, l.companionNormal, l.companionHigh];
    return _panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      courseLabel(course, l),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${l.companionPriority}: ${priorities[course.priority - 1]}',
                    ),
                    if (days != null)
                      Text(
                        days == 0
                            ? l.companionExamToday
                            : days < 0
                            ? l.companionExamPast
                            : '${companionNumber(context, days)} ${l.companionDaysLeft}',
                      ),
                    if (course.examDate != null)
                      Text(
                        AppUtils.displayDate(course.examDate!),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: l.companionCourseSettings,
                icon: const Icon(Icons.tune_outlined),
                onPressed: ref.watch(companionProvider(workspace.id!)).busy
                    ? null
                    : () => _edit(
                        workspace.id!,
                        date,
                        CompanionEdit.course,
                        course: course,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('prepare-study'),
            onPressed: () => _prepare(
              workspace,
              courseLabel(course, l),
              energyMinutes(
                ref
                    .read(companionProvider(workspace.id!))
                    .plan
                    .day(date)
                    .energy,
              ),
            ),
            icon: Icon(
              session == null ? Icons.play_arrow_rounded : Icons.timer_outlined,
            ),
            label: Text(
              session == null ? l.companionPrepare : l.companionContinue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dateNavigation(String date, String today, AppLocalizations l) => Row(
    children: [
      IconButton(
        tooltip: l.companionPreviousDay,
        icon: const BackButtonIcon(),
        onPressed: () => setState(() {
          final d = AppUtils.parseDate(date);
          _browsingDate = AppUtils.formatDate(
            DateTime(d.year, d.month, d.day - 1),
          );
        }),
      ),
      Expanded(
        child: Text(
          date == today ? l.today : AppUtils.displayDate(date),
          textAlign: TextAlign.center,
        ),
      ),
      TextButton(
        onPressed: date == today
            ? null
            : () => setState(() => _browsingDate = null),
        child: Text(l.today),
      ),
      IconButton(
        tooltip: l.companionNextDay,
        icon: const Icon(Icons.arrow_forward),
        onPressed: () => setState(() {
          final d = AppUtils.parseDate(date);
          _browsingDate = AppUtils.formatDate(
            DateTime(d.year, d.month, d.day + 1),
          );
        }),
      ),
    ],
  );

  Widget _taskTile(
    Workspace workspace,
    String date,
    DailyTask task,
    bool busy,
    AppLocalizations l,
  ) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: task.done,
              onChanged: busy
                  ? null
                  : (_) => _update(
                      workspace.id!,
                      (p) => p.withDay(
                        date,
                        p
                            .day(date)
                            .copyWith(
                              tasks: p
                                  .day(date)
                                  .tasks
                                  .map((t) => t.id == task.id ? t.toggle() : t)
                                  .toList(),
                            ),
                      ),
                    ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        decoration: task.done
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    Text(
                      '${task.subject} · ${methodLabel(task.method, l)} · ${l.minutesValue(companionNumber(context, task.minutes))}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: l.companionDeleteTask,
              enabled: !busy,
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'delete',
                  child: Text(l.companionDeleteTask),
                ),
              ],
              onSelected: (_) => _update(
                workspace.id!,
                (p) => p.withDay(
                  date,
                  p
                      .day(date)
                      .copyWith(
                        tasks: p
                            .day(date)
                            .tasks
                            .where((t) => t.id != task.id)
                            .toList(),
                      ),
                ),
              ),
            ),
          ],
        ),
        if (!task.done)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () => _prepare(
                workspace,
                '${task.subject} · ${task.title}',
                task.minutes,
                method: task.method,
              ),
              icon: Icon(methodIcon(task.method), size: 18),
              label: Text(l.companionPrepare),
            ),
          ),
        const Divider(),
      ],
    ),
  );

  Widget _gamesCard(AppLocalizations l) => _panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.extension_outlined,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l.companionWarmup,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(l.companionGamesHint),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ActionChip(
              avatar: const Icon(Icons.grid_view_rounded, size: 18),
              label: Text(l.companionSchulte),
              onPressed: () => _games(kind: FocusGameKind.numbers),
            ),
            ActionChip(
              avatar: const Icon(Icons.touch_app_outlined, size: 18),
              label: Text(l.companionGo),
              onPressed: () => _games(kind: FocusGameKind.response),
            ),
            ActionChip(
              avatar: const Icon(Icons.pattern_outlined, size: 18),
              label: Text(l.companionMemory),
              onPressed: () => _games(kind: FocusGameKind.memory),
            ),
          ],
        ),
      ],
    ),
  );

  Future<void> _games({FocusGameKind? kind}) async {
    if (_openingGame) return;
    _openingGame = true;
    try {
      final timer = ref.read(studyTimerProvider.notifier);
      await timer.ready;
      if (!mounted) return;
      final running = ref.read(studyTimerProvider).session?.isRunning == true;
      if (running && !await timer.pause()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.timerActionFailed),
            ),
          );
        }
        return;
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) =>
              FocusGamesScreen(initialGame: kind, studyPaused: running),
        ),
      );
    } finally {
      _openingGame = false;
    }
  }

  Future<void> _edit(
    int id,
    String date,
    CompanionEdit kind, {
    MedicalCourse? course,
  }) => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => CompanionEditor(
      workspaceId: id,
      date: date,
      kind: kind,
      course: course,
    ),
  );
  Future<bool> _update(int id, CompanionPlan Function(CompanionPlan) change) =>
      ref.read(companionProvider(id).notifier).update(change);
  void _prepare(
    Workspace workspace,
    String subject,
    int minutes, {
    String method = 'read',
  }) {
    if (ref.read(studyTimerProvider).session != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => StudyTimerScreen(workspace: workspace),
        ),
      );
      return;
    }
    final limited = subject.length > 80 ? subject.substring(0, 80) : subject;
    ref.read(selectedStudySubjectProvider(workspace.id!).notifier).state =
        limited;
    showDialog<void>(
      context: context,
      builder: (_) => SessionPreparation(
        workspace: workspace,
        subject: limited,
        minutes: minutes,
        method: method,
      ),
    );
  }
}
