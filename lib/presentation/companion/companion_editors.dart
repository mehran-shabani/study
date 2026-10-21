import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study/l10n/generated/app_localizations.dart';
import '../../core/utils.dart';
import '../../data/study_companion.dart';
import '../common/jalali_date_picker.dart';
import 'companion_catalog.dart';

enum CompanionEdit { courses, course, task, reflection }

/// Editors keep their draft on failed writes and only close after persistence.
class CompanionEditor extends ConsumerStatefulWidget {
  const CompanionEditor({
    super.key,
    required this.workspaceId,
    required this.date,
    required this.kind,
    this.course,
  });
  final int workspaceId;
  final String date;
  final CompanionEdit kind;
  final MedicalCourse? course;
  @override
  ConsumerState<CompanionEditor> createState() => _CompanionEditorState();
}

class _CompanionEditorState extends ConsumerState<CompanionEditor> {
  final _form = GlobalKey<FormState>();
  final _custom = TextEditingController();
  final _title = TextEditingController();
  final _reflection = TextEditingController();
  final _tomorrow = TextEditingController();
  late List<MedicalCourse> _courses;
  late String _stage;
  String? _courseId;
  String? _examDate;
  int _priority = 2;
  int _minutes = 25;
  String _method = 'read';
  bool _saving = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    final plan = ref.read(companionProvider(widget.workspaceId)).plan;
    final day = plan.day(widget.date);
    _courses = [...plan.courses];
    _stage = plan.stage;
    _courseId = plan.selectedCourse?.id;
    _priority = widget.course?.priority ?? 2;
    _examDate = widget.course?.examDate;
    _minutes = energyMinutes(day.energy);
    _reflection.text = day.reflection;
    _tomorrow.text = day.tomorrow;
  }

  @override
  void dispose() {
    _custom.dispose();
    _title.dispose();
    _reflection.dispose();
    _tomorrow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final title = switch (widget.kind) {
      CompanionEdit.courses => l.companionCourses,
      CompanionEdit.course => l.companionCourseSettings,
      CompanionEdit.task => l.companionAddTask,
      CompanionEdit.reflection => l.companionEvening,
    };
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 480,
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              child: AbsorbPointer(
                absorbing: _saving,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.kind == CompanionEdit.courses)
                      ..._coursePicker(l),
                    if (widget.kind == CompanionEdit.course)
                      ..._courseSettings(l),
                    if (widget.kind == CompanionEdit.task) ..._taskFields(l),
                    if (widget.kind == CompanionEdit.reflection) ...[
                      TextFormField(
                        controller: _reflection,
                        maxLength: 1000,
                        minLines: 3,
                        maxLines: 6,
                        decoration: InputDecoration(
                          labelText: l.companionReflection,
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _tomorrow,
                        maxLength: 1000,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: l.companionTomorrow,
                          alignLabelWithHint: true,
                        ),
                      ),
                    ],
                    if (_failed)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          l.saveFailed,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? l.saving : l.save),
          ),
        ],
      ),
    );
  }

  List<Widget> _coursePicker(AppLocalizations l) {
    final catalog = medicalCatalog(l).entries.toList();
    const clinical = {
      'internal',
      'surgery',
      'pediatrics',
      'obgyn',
      'psychiatry',
      'neurology',
      'publicHealth',
    };
    catalog.sort((a, b) {
      final clinicalStage = _stage != 'basic';
      final aRank = clinical.contains(a.key) == clinicalStage ? 0 : 1;
      final bRank = clinical.contains(b.key) == clinicalStage ? 0 : 1;
      return aRank.compareTo(bRank);
    });
    return [
      DropdownButtonFormField<String>(
        initialValue: _stage,
        isExpanded: true,
        decoration: InputDecoration(labelText: l.companionStage),
        items: [
          DropdownMenuItem(value: 'basic', child: Text(l.companionBasic)),
          DropdownMenuItem(value: 'clinical', child: Text(l.companionClinical)),
          DropdownMenuItem(value: 'intern', child: Text(l.companionIntern)),
        ],
        onChanged: (v) => setState(() => _stage = v!),
      ),
      const SizedBox(height: 16),
      Text(l.companionCourseHint),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final item in catalog)
            FilterChip(
              label: Text(item.value),
              selected: _courses.any((c) => c.id == item.key),
              onSelected: (selected) => setState(() {
                if (selected) {
                  _courses.add(MedicalCourse(id: item.key, name: item.value));
                } else {
                  _courses.removeWhere((c) => c.id == item.key);
                }
              }),
            ),
          for (final course in _courses.where(
            (c) => !medicalCatalog(l).containsKey(c.id),
          ))
            InputChip(
              label: Text(course.name),
              onDeleted: () => setState(
                () => _courses.removeWhere((c) => c.id == course.id),
              ),
            ),
        ],
      ),
      const SizedBox(height: 20),
      TextField(
        key: const ValueKey('custom-course'),
        controller: _custom,
        maxLength: 60,
        decoration: InputDecoration(labelText: l.companionCustomCourse),
        onSubmitted: (_) => _addCustom(),
      ),
      Align(
        alignment: AlignmentDirectional.centerEnd,
        child: TextButton.icon(
          onPressed: _addCustom,
          icon: const Icon(Icons.add),
          label: Text(l.companionAddCourse),
        ),
      ),
    ];
  }

  void _addCustom() {
    final name = _custom.text.trim();
    if (name.isEmpty || name.length > 60) return;
    if (_courses.any((c) => c.name.toLowerCase() == name.toLowerCase())) return;
    setState(() {
      _courses.add(
        MedicalCourse(
          id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
          name: name,
        ),
      );
      _custom.clear();
    });
  }

  List<Widget> _courseSettings(AppLocalizations l) => [
    Text(
      courseLabel(widget.course!, l),
      style: Theme.of(context).textTheme.titleLarge,
    ),
    const SizedBox(height: 20),
    DropdownButtonFormField<int>(
      initialValue: _priority,
      isExpanded: true,
      decoration: InputDecoration(labelText: l.companionPriority),
      items: [
        DropdownMenuItem(value: 1, child: Text(l.companionLow)),
        DropdownMenuItem(value: 2, child: Text(l.companionNormal)),
        DropdownMenuItem(value: 3, child: Text(l.companionHigh)),
      ],
      onChanged: (v) => setState(() => _priority = v!),
    ),
    const SizedBox(height: 16),
    OutlinedButton.icon(
      key: const ValueKey('course-exam-date'),
      onPressed: () async {
        final picked = await selectJalaliDate(
          context,
          initialDate: _examDate == null
              ? DateTime.now()
              : AppUtils.parseDate(_examDate!),
        );
        if (picked != null && mounted) {
          setState(() => _examDate = AppUtils.formatDate(picked));
        }
      },
      icon: const Icon(Icons.event_outlined),
      label: Text(
        _examDate == null ? l.companionExam : AppUtils.displayDate(_examDate!),
      ),
    ),
    if (_examDate != null)
      TextButton(
        onPressed: () => setState(() => _examDate = null),
        child: Text(l.companionNoExam),
      ),
  ];

  List<Widget> _taskFields(AppLocalizations l) => [
    DropdownButtonFormField<String>(
      initialValue: _courseId,
      isExpanded: true,
      decoration: InputDecoration(labelText: l.companionCourses),
      items: _courses
          .map(
            (c) => DropdownMenuItem(
              value: c.id,
              child: Text(
                courseLabel(c, l),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      validator: (v) => v == null ? l.requiredField : null,
      onChanged: (v) => setState(() => _courseId = v),
    ),
    const SizedBox(height: 16),
    TextFormField(
      key: const ValueKey('daily-task-title'),
      controller: _title,
      maxLength: 80,
      decoration: InputDecoration(
        labelText: l.companionTaskTitle,
        hintText: l.companionTaskHint,
      ),
      validator: (v) => v == null || v.trim().isEmpty ? l.requiredField : null,
    ),
    const SizedBox(height: 12),
    Text(l.companionMethod),
    Wrap(
      spacing: 8,
      runSpacing: 4,
      children: studyMethods
          .map(
            (m) => ChoiceChip(
              label: Text(methodLabel(m, l)),
              selected: m == _method,
              onSelected: (_) => setState(() => _method = m),
            ),
          )
          .toList(),
    ),
    const SizedBox(height: 12),
    Text(l.companionMinutes),
    Wrap(
      spacing: 8,
      children: [15, 25, 50]
          .map(
            (m) => ChoiceChip(
              label: Text(l.minutesValue(companionNumber(context, m))),
              selected: m == _minutes,
              onSelected: (_) => setState(() => _minutes = m),
            ),
          )
          .toList(),
    ),
  ];

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    // Include a custom course still in the input when Save is pressed directly.
    if (widget.kind == CompanionEdit.courses) _addCustom();
    setState(() {
      _saving = true;
      _failed = false;
    });
    final l = AppLocalizations.of(context)!;
    final success = await ref
        .read(companionProvider(widget.workspaceId).notifier)
        .update((plan) {
          switch (widget.kind) {
            case CompanionEdit.courses:
              return CompanionPlan(
                stage: _stage,
                courses: [..._courses],
                days: plan.days,
                selectedCourseId:
                    _courses.any((c) => c.id == plan.selectedCourseId)
                    ? plan.selectedCourseId
                    : _courses.firstOrNull?.id,
              );
            case CompanionEdit.course:
              return plan.copyWith(
                courses: plan.courses
                    .map(
                      (c) => c.id == widget.course!.id
                          ? MedicalCourse(
                              id: c.id,
                              name: c.name,
                              priority: _priority,
                              examDate: _examDate,
                            )
                          : c,
                    )
                    .toList(),
              );
            case CompanionEdit.task:
              final day = plan.day(widget.date);
              final course = _courses.firstWhere((c) => c.id == _courseId);
              return plan.withDay(
                widget.date,
                day.copyWith(
                  tasks: [
                    ...day.tasks,
                    DailyTask(
                      id: '${DateTime.now().microsecondsSinceEpoch}',
                      subject: courseLabel(course, l),
                      title: _title.text.trim(),
                      minutes: _minutes,
                      method: _method,
                    ),
                  ],
                ),
              );
            case CompanionEdit.reflection:
              return plan.withDay(
                widget.date,
                plan
                    .day(widget.date)
                    .copyWith(
                      reflection: _reflection.text.trim(),
                      tomorrow: _tomorrow.text.trim(),
                    ),
              );
          }
        });
    if (!mounted) return;
    setState(() {
      _saving = false;
      _failed = !success;
    });
    if (success) Navigator.pop(context);
  }
}
