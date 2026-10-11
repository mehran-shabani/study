import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../core/utils.dart';
import '../common/jalali_date_picker.dart';

class EntryDialog extends ConsumerStatefulWidget {
  final int workspaceId;
  final StudyEntry? entry;

  const EntryDialog({super.key, required this.workspaceId, this.entry});

  @override
  ConsumerState<EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends ConsumerState<EntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _dateController;
  late DateTime _entryDate;
  late TextEditingController _titleController;
  late TextEditingController _hoursController;
  bool _saving = false;
  String? _saveError;

  @override
  void initState() {
    super.initState();
    _entryDate =
        AppUtils.parseDate(widget.entry?.entryDate ?? AppUtils.today());
    _dateController = TextEditingController(
        text: AppUtils.displayDate(AppUtils.formatDate(_entryDate)));
    _titleController = TextEditingController(text: widget.entry?.title ?? '');
    _hoursController =
        TextEditingController(text: widget.entry?.hours.toString() ?? '');
  }

  @override
  void dispose() {
    _dateController.dispose();
    _titleController.dispose();
    _hoursController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = widget.entry != null;
    final locale = Localizations.localeOf(context).toString();
    final entries =
        ref.watch(studyEntriesProvider).valueOrNull ?? <StudyEntry>[];
    final subjects = entries
        .where((e) => e.workspaceId == widget.workspaceId)
        .map((e) => e.title)
        .toSet()
        .take(5)
        .toList();
    return PopScope(
      canPop: !_saving,
      child: AlertDialog(
        title: Text(isEdit ? l10n.editEntry : l10n.addEntry),
        content: SizedBox(
          width: 400,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _titleController,
                      enabled: !_saving,
                      decoration: InputDecoration(
                          labelText: l10n.entryTitle,
                          hintText: l10n.entryTitleHint,
                          prefixIcon: const Icon(Icons.menu_book_outlined)),
                      validator: (value) =>
                          AppUtils.validateEntryTitle(value) == null
                              ? null
                              : l10n.requiredField,
                      autofocus: !isEdit,
                      textInputAction: TextInputAction.next,
                      maxLength: 80,
                    ),
                    if (!isEdit && subjects.isNotEmpty) ...[
                      Text(l10n.recentSubjects,
                          style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 6),
                      Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: subjects
                              .map((title) => ActionChip(
                                    label: Text(title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                    onPressed: _saving
                                        ? null
                                        : () => _titleController.text = title,
                                  ))
                              .toList()),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _hoursController,
                      enabled: !_saving,
                      decoration: InputDecoration(
                          labelText: l10n.duration,
                          helperText: l10n.hoursHint,
                          suffixText: l10n.hours,
                          prefixIcon: const Icon(Icons.schedule)),
                      validator: (value) =>
                          AppUtils.validateHours(value) == null
                              ? null
                              : l10n.targetRange,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => setState(() {}),
                      onFieldSubmitted: (_) => _saveEntry(),
                    ),
                    const SizedBox(height: 12),
                    Text(l10n.quickDuration,
                        style: Theme.of(context).textTheme.bodySmall),
                    Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [15, 30, 60, 90, 120]
                            .map((minutes) => ChoiceChip(
                                  label: Text(l10n.minutesValue(
                                      NumberFormat.decimalPattern(locale)
                                          .format(minutes))),
                                  selected: double.tryParse(
                                          AppUtils.normalizeNumber(
                                              _hoursController.text)) ==
                                      minutes / 60,
                                  onSelected: _saving
                                      ? null
                                      : (_) => setState(() => _hoursController
                                          .text = (minutes / 60).toString()),
                                ))
                            .toList()),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _dateController,
                      enabled: !_saving,
                      decoration: InputDecoration(
                          labelText: l10n.entryDate,
                          prefixIcon:
                              const Icon(Icons.calendar_today_outlined)),
                      onTap: () => _selectDate(context),
                      readOnly: true,
                    ),
                    Wrap(spacing: 8, children: [
                      TextButton(
                          onPressed:
                              _saving ? null : () => _setDate(DateTime.now()),
                          child: Text(l10n.today)),
                      TextButton(
                          onPressed: _saving
                              ? null
                              : () {
                                  final now = DateTime.now();
                                  _setDate(DateTime(
                                      now.year, now.month, now.day - 1));
                                },
                          child: Text(l10n.yesterday)),
                    ]),
                    if (_saveError != null)
                      Text(_saveError!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error)),
                  ]),
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: Text(l10n.cancel)),
          FilledButton(
              onPressed: _saving ? null : _saveEntry,
              child: Text(_saving ? l10n.saving : l10n.save)),
        ],
      ),
    );
  }

  void _setDate(DateTime date) {
    setState(() {
      _entryDate = date;
      _dateController.text = AppUtils.displayDate(AppUtils.formatDate(date));
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final picked = await selectJalaliDate(context, initialDate: _entryDate);
    if (picked != null && mounted) _setDate(picked);
  }

  Future<void> _saveEntry() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _saving = true;
      _saveError = null;
    });
    final entry = StudyEntry(
        id: widget.entry?.id,
        workspaceId: widget.workspaceId,
        entryDate: AppUtils.formatDate(_entryDate),
        title: _titleController.text.trim(),
        hours: double.parse(AppUtils.normalizeNumber(_hoursController.text)));
    final notifier = ref.read(studyEntryNotifierProvider.notifier);
    final success = widget.entry == null
        ? await notifier.createEntry(entry) != null
        : await notifier.updateEntry(entry);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _saveError = success ? null : l10n.saveFailed;
    });
    if (success) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.sessionSaved)));
      Navigator.of(context).pop();
    }
  }
}
