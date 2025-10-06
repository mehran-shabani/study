import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../core/utils.dart';

class EntryDialog extends ConsumerStatefulWidget {
  final int workspaceId;
  final StudyEntry? entry;

  const EntryDialog({
    super.key,
    required this.workspaceId,
    this.entry,
  });

  @override
  ConsumerState<EntryDialog> createState() => _EntryDialogState();
}

class _EntryDialogState extends ConsumerState<EntryDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _dateController;
  late TextEditingController _titleController;
  late TextEditingController _hoursController;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(
      text: widget.entry?.entryDate ?? AppUtils.today(),
    );
    _titleController = TextEditingController(text: widget.entry?.title ?? '');
    _hoursController = TextEditingController(
      text: widget.entry?.hours.toString() ?? '',
    );
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

    return AlertDialog(
      title: Text(isEdit ? l10n.editEntry : l10n.addEntry),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _dateController,
                decoration: InputDecoration(
                  labelText: l10n.entryDate,
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  hintText: 'yyyy-MM-dd',
                ),
                validator: AppUtils.validateDate,
                onTap: () => _selectDate(context),
                readOnly: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: l10n.entryTitle,
                  prefixIcon: const Icon(Icons.title_outlined),
                ),
                validator: AppUtils.validateEntryTitle,
                autofocus: !isEdit,
                maxLength: 80,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _hoursController,
                decoration: InputDecoration(
                  labelText: l10n.hours,
                  prefixIcon: const Icon(Icons.access_time_outlined),
                  hintText: '0.25 - 24.0',
                ),
                validator: AppUtils.validateHours,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _saveEntry,
          child: Text(l10n.save),
        ),
      ],
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final initialDate = _dateController.text.isEmpty
        ? DateTime.now()
        : AppUtils.parseDate(_dateController.text);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        _dateController.text = AppUtils.formatDate(picked);
      });
    }
  }

  Future<void> _saveEntry() async {
    if (!_formKey.currentState!.validate()) return;

    final entry = StudyEntry(
      id: widget.entry?.id,
      workspaceId: widget.workspaceId,
      entryDate: _dateController.text.trim(),
      title: _titleController.text.trim(),
      hours: double.parse(_hoursController.text.trim()),
    );

    final notifier = ref.read(studyEntryNotifierProvider.notifier);
    final success = widget.entry == null
        ? await notifier.createEntry(entry)
        : await notifier.updateEntry(entry);

    if (mounted && success != null) {
      Navigator.of(context).pop();
    }
  }
}
