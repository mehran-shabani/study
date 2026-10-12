import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:study/l10n/generated/app_localizations.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../data/models.dart';
import '../../data/providers.dart';
import '../../domain/csv_export.dart';

class ExportCsvButton extends ConsumerStatefulWidget {
  final Workspace workspace;

  const ExportCsvButton({super.key, required this.workspace});

  @override
  ConsumerState<ExportCsvButton> createState() => _ExportCsvButtonState();
}

class _ExportCsvButtonState extends ConsumerState<ExportCsvButton> {
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: AppLocalizations.of(context)!.exportCsv,
      onPressed: _exporting ? null : _export,
      icon: _exporting
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2))
          : const Icon(Icons.file_download_outlined),
    );
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    final workspace = widget.workspace;
    final l10n = AppLocalizations.of(context)!;
    final box = context.findRenderObject() as RenderBox?;
    final origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    try {
      final entries =
          await ref.read(studyEntryDaoProvider).getByWorkspace(workspace.id!);
      final directory = await getTemporaryDirectory();
      final file = File(path.join(directory.path,
          'study_${workspace.id}_${DateTime.now().microsecondsSinceEpoch}.csv'));
      await file.writeAsBytes(utf8.encode(buildStudyCsv(workspace, entries)),
          flush: true);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: '${l10n.exportCsv} - ${workspace.name}',
        sharePositionOrigin: origin,
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.exportFailed)));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }
}
