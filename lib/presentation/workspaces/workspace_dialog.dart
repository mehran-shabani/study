import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../core/utils.dart';

class WorkspaceDialog extends ConsumerStatefulWidget {
  final Workspace? workspace;

  const WorkspaceDialog({super.key, this.workspace});

  @override
  ConsumerState<WorkspaceDialog> createState() => _WorkspaceDialogState();
}

class _WorkspaceDialogState extends ConsumerState<WorkspaceDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _startDateController;
  late TextEditingController _endDateController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.workspace?.name ?? '');
    _startDateController = TextEditingController(
      text: widget.workspace?.startDate ?? AppUtils.today(),
    );
    _endDateController = TextEditingController(
      text: widget.workspace?.endDate ?? AppUtils.today(),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _startDateController.dispose();
    _endDateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEdit = widget.workspace != null;

    return AlertDialog(
      title: Text(isEdit ? l10n.editWorkspace : l10n.addWorkspace),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: l10n.workspaceName,
                  prefixIcon: const Icon(Icons.label_outlined),
                ),
                validator: AppUtils.validateWorkspaceName,
                autofocus: !isEdit,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _startDateController,
                decoration: InputDecoration(
                  labelText: l10n.startDate,
                  prefixIcon: const Icon(Icons.calendar_today_outlined),
                  hintText: 'yyyy-MM-dd',
                ),
                validator: AppUtils.validateDate,
                onTap: () => _selectDate(context, _startDateController),
                readOnly: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _endDateController,
                decoration: InputDecoration(
                  labelText: l10n.endDate,
                  prefixIcon: const Icon(Icons.event_outlined),
                  hintText: 'yyyy-MM-dd',
                ),
                validator: (value) {
                  final dateError = AppUtils.validateDate(value);
                  if (dateError != null) return dateError;
                  return AppUtils.validateDateRange(
                    _startDateController.text,
                    _endDateController.text,
                  );
                },
                onTap: () => _selectDate(context, _endDateController),
                readOnly: true,
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
          onPressed: _saveWorkspace,
          child: Text(l10n.save),
        ),
      ],
    );
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final initialDate = controller.text.isEmpty
        ? DateTime.now()
        : AppUtils.parseDate(controller.text);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null) {
      setState(() {
        controller.text = AppUtils.formatDate(picked);
      });
    }
  }

  Future<void> _saveWorkspace() async {
    if (!_formKey.currentState!.validate()) return;

    final workspace = Workspace(
      id: widget.workspace?.id,
      name: _nameController.text.trim(),
      startDate: _startDateController.text.trim(),
      endDate: _endDateController.text.trim(),
    );

    final notifier = ref.read(workspaceNotifierProvider.notifier);
    final success = widget.workspace == null
        ? await notifier.createWorkspace(workspace)
        : await notifier.updateWorkspace(workspace);

    if (mounted && success != null) {
      // Auto-select newly created workspace
      if (widget.workspace == null) {
        ref.read(selectedWorkspaceIdProvider.notifier).state = success;
      }
      Navigator.of(context).pop();
    }
  }
}
