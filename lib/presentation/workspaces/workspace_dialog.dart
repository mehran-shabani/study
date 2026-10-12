import 'package:flutter/material.dart';
import '../common/jalali_date_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study/l10n/generated/app_localizations.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../core/utils.dart';
import '../../core/constants.dart';

class WorkspaceDialog extends ConsumerStatefulWidget {
  final Workspace? workspace;

  const WorkspaceDialog({super.key, this.workspace});

  @override
  ConsumerState<WorkspaceDialog> createState() => _WorkspaceDialogState();
}

class _WorkspaceDialogState extends ConsumerState<WorkspaceDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _saveError;
  late TextEditingController _nameController;
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;
  late TextEditingController _targetController;
  late DateTime _startDate;
  late DateTime _endDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.workspace?.name ?? '');
    _startDate =
        AppUtils.parseDate(widget.workspace?.startDate ?? AppUtils.today());
    _endDate =
        AppUtils.parseDate(widget.workspace?.endDate ?? AppUtils.today());
    _startDateController = TextEditingController(
      text: AppUtils.displayDate(AppUtils.formatDate(_startDate)),
    );
    _endDateController = TextEditingController(
      text: AppUtils.displayDate(AppUtils.formatDate(_endDate)),
    );
    _targetController = TextEditingController(
      text: (widget.workspace?.dailyTargetHours ??
              AppConstants.avgDailyTargetHours)
          .toString(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = widget.workspace != null;

    return PopScope(
        canPop: !_saving,
        child: AlertDialog(
          title: Text(isEdit ? l10n.editWorkspace : l10n.addWorkspace),
          content: SizedBox(
              width: 400,
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        enabled: !_saving,
                        decoration: InputDecoration(
                          labelText: l10n.workspaceName,
                          hintText: l10n.nameHint,
                          prefixIcon: const Icon(Icons.label_outlined),
                        ),
                        validator: (value) =>
                            AppUtils.validateWorkspaceName(value) == null
                                ? null
                                : l10n.requiredField,
                        maxLength: AppConstants.maxWorkspaceNameLength,
                        textInputAction: TextInputAction.next,
                        autofocus: !isEdit,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _startDateController,
                        enabled: !_saving,
                        decoration: InputDecoration(
                          labelText: l10n.startDate,
                          prefixIcon: const Icon(Icons.calendar_today_outlined),
                          hintText: l10n.jalaliDateHint,
                        ),
                        validator: (_) => AppUtils.validateDate(
                            AppUtils.formatDate(_startDate)),
                        onTap: () => _selectDate(context, _startDateController),
                        readOnly: true,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _endDateController,
                        enabled: !_saving,
                        decoration: InputDecoration(
                          labelText: l10n.endDate,
                          prefixIcon: const Icon(Icons.event_outlined),
                          hintText: l10n.jalaliDateHint,
                        ),
                        validator: (value) {
                          final dateError = AppUtils.validateDate(
                              AppUtils.formatDate(_endDate));
                          if (dateError != null) return dateError;
                          return _endDate.isBefore(_startDate)
                              ? l10n.invalidDateRange
                              : null;
                        },
                        onTap: () => _selectDate(context, _endDateController),
                        readOnly: true,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _targetController,
                        enabled: !_saving,
                        decoration: InputDecoration(
                          labelText: l10n.dailyTargetHours,
                          prefixIcon: const Icon(Icons.flag_outlined),
                          helperText: l10n.targetRange,
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (value) =>
                            AppUtils.validateHours(value) == null
                                ? null
                                : l10n.targetRange,
                      ),
                      if (_saveError != null) ...[
                        const SizedBox(height: 12),
                        Text(_saveError!,
                            style: TextStyle(
                                color: Theme.of(context).colorScheme.error)),
                      ],
                    ],
                  ),
                ),
              )),
          actions: [
            TextButton(
              onPressed: _saving ? null : () => Navigator.of(context).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: _saving ? null : _saveWorkspace,
              child: Text(_saving ? l10n.saving : l10n.save),
            ),
          ],
        ));
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final isStart = controller == _startDateController;
    final picked = await selectJalaliDate(
      context,
      initialDate: isStart ? _startDate : _endDate,
    );

    if (picked != null && mounted) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
        controller.text = AppUtils.displayDate(AppUtils.formatDate(picked));
      });
    }
  }

  Future<void> _saveWorkspace() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _saving = true;
      _saveError = null;
    });

    final workspace = Workspace(
      id: widget.workspace?.id,
      name: _nameController.text.trim(),
      startDate: AppUtils.formatDate(_startDate),
      endDate: AppUtils.formatDate(_endDate),
      dailyTargetHours:
          double.parse(AppUtils.normalizeNumber(_targetController.text)),
    );

    final notifier = ref.read(workspaceNotifierProvider.notifier);

    bool operationSucceeded = false;
    int? createdWorkspaceId;

    if (widget.workspace == null) {
      createdWorkspaceId = await notifier.createWorkspace(workspace);
      operationSucceeded = createdWorkspaceId != null;
    } else {
      operationSucceeded = await notifier.updateWorkspace(workspace);
    }

    if (!mounted) return;
    setState(() {
      _saving = false;
      _saveError = operationSucceeded ? null : l10n.saveFailed;
    });
    if (operationSucceeded) {
      // Auto-select newly created workspace
      if (widget.workspace == null) {
        ref.read(selectedWorkspaceIdProvider.notifier).state =
            createdWorkspaceId;
        ref.read(mainTabProvider.notifier).state = 1;
      }
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l10n.planSaved)));
      Navigator.of(context).pop();
    }
  }
}
