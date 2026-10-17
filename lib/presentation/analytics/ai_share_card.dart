import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:study/l10n/generated/app_localizations.dart';
import '../../domain/study_ai_report.dart';
import '../../domain/study_insights.dart';

class AiShareCard extends StatelessWidget {
  const AiShareCard({super.key, required this.insights, this.tomorrowHours});

  final StudyInsights insights;
  final double? tomorrowHours;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: AlignmentDirectional.topStart,
          end: AlignmentDirectional.bottomEnd,
          colors: [colors.primaryContainer, colors.secondaryContainer],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: colors.surface.withValues(alpha: 0.7),
                foregroundColor: colors.primary,
                child: const Icon(Icons.auto_awesome_outlined),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.aiShareTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.aiShareIntro,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colors.onPrimaryContainer,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('share-with-ai'),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _AiShareDialog(
                prompt: buildStudyAiPrompt(
                  insights,
                  instructions: l10n.aiAnalysisPrompt,
                  tomorrowHours: tomorrowHours,
                ),
                subject: '${l10n.aiShareTitle} · ${insights.workspace.name}',
              ),
            ),
            icon: const Icon(Icons.ios_share_rounded, size: 20),
            label: Text(l10n.shareWithAi, textAlign: TextAlign.center),
          ),
        ],
      ),
    );
  }
}

class _AiShareDialog extends StatefulWidget {
  const _AiShareDialog({required this.prompt, required this.subject});
  final String prompt;
  final String subject;

  @override
  State<_AiShareDialog> createState() => _AiShareDialogState();
}

class _AiShareDialogState extends State<_AiShareDialog> {
  late final _reportBytes = utf8.encode(widget.prompt);
  // Keep large histories out of Android's bounded intent text payload.
  bool get _shareAsFile => _reportBytes.length > 64 * 1024;
  bool _busy = false;
  bool _failed = false;
  String? _feedback;

  Future<void> _send({required bool copy, Rect? origin}) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _feedback = null;
    });
    try {
      if (copy) {
        await Clipboard.setData(ClipboardData(text: widget.prompt));
        if (mounted) {
          setState(() {
            _feedback = l10n.aiPromptCopied;
            _failed = false;
          });
        }
      } else if (_shareAsFile) {
        await Share.shareXFiles(
          [
            XFile.fromData(
              _reportBytes,
              mimeType: 'text/plain',
              name: 'study-ai-report.txt',
            ),
          ],
          subject: widget.subject,
          sharePositionOrigin: origin,
        );
      } else {
        await Share.share(
          widget.prompt,
          subject: widget.subject,
          sharePositionOrigin: origin,
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _feedback = copy ? l10n.aiCopyFailed : l10n.aiShareFailed;
          _failed = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 720,
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.aiPreviewTitle,
                      style: theme.textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(l10n.aiShareHint),
                      if (_shareAsFile) ...[
                        const SizedBox(height: 8),
                        Text(l10n.aiLongReportHint),
                      ],
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: theme.colorScheme.outlineVariant,
                          ),
                        ),
                        child: SelectableText(
                          widget.prompt,
                          key: const ValueKey('ai-prompt-preview'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_feedback != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    _feedback!,
                    style: TextStyle(
                      color: _failed ? theme.colorScheme.error : null,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              if (_busy) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 12),
              ],
              OverflowBar(
                spacing: 12,
                overflowSpacing: 8,
                alignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    key: const ValueKey('copy-ai-prompt'),
                    onPressed: _busy ? null : () => _send(copy: true),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: Text(l10n.aiCopyPrompt),
                  ),
                  Builder(
                    builder: (buttonContext) => FilledButton.icon(
                      key: const ValueKey('send-ai-prompt'),
                      onPressed: _busy
                          ? null
                          : () {
                              final box =
                                  buttonContext.findRenderObject()
                                      as RenderBox?;
                              _send(
                                copy: false,
                                origin: box == null
                                    ? null
                                    : box.localToGlobal(Offset.zero) & box.size,
                              );
                            },
                      icon: const Icon(Icons.ios_share_rounded, size: 18),
                      label: Text(l10n.aiShareAction),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
