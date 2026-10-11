import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../core/utils.dart';
import '../../data/models.dart';
import '../workspaces/workspace_dialog.dart';

class TodayProgressCard extends StatelessWidget {
  final Workspace workspace;
  final double hours;
  final String date;

  const TodayProgressCard(
      {super.key,
      required this.workspace,
      required this.hours,
      required this.date});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toString();
    final target = workspace.dailyTargetHours;
    final reached = hours >= target;
    final progress = target > 0 ? (hours / target).clamp(0.0, 1.0) : 0.0;
    String number(double value) =>
        AppUtils.formatHourValue(value, locale: locale);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Wrap(
              spacing: 12,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(l10n.today, style: theme.textTheme.titleMedium),
                Text(AppUtils.displayDate(date),
                    style: theme.textTheme.bodySmall),
              ]),
          const SizedBox(height: 12),
          Text(l10n.hoursValue(number(hours)),
              style: theme.textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          Text('${l10n.dailyTarget}: ${l10n.hoursValue(number(target))}'),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
            semanticsLabel: l10n.todayProgress,
            semanticsValue: '${(progress * 100).round()}%',
          ),
          const SizedBox(height: 12),
          Text(
              reached
                  ? l10n.goalReached
                  : l10n.remainingToday(
                      number((target - hours).clamp(0.0, target).toDouble())),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          if (hours == 0) ...[
            const SizedBox(height: 4),
            Text(l10n.goalHint),
          ],
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton.icon(
              onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => WorkspaceDialog(workspace: workspace)),
              icon: const Icon(Icons.tune, size: 18),
              label: Text(l10n.dailyTarget),
            ),
          ),
        ]),
      ),
    );
  }
}
