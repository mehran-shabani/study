import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:study/l10n/generated/app_localizations.dart';
import '../../core/utils.dart';
import '../../data/models.dart';

class ProgressCard extends StatelessWidget {
  final double progress;
  final List<StudyEntry> entries;
  final Workspace workspace;

  const ProgressCard({
    super.key,
    required this.progress,
    required this.entries,
    required this.workspace,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();
    String duration(double value) =>
        l10n.hoursValue(AppUtils.formatHourValue(value, locale: locale));
    final totalHours = entries.fold<double>(
      0,
      (sum, entry) => sum + entry.hours,
    );
    final days = AppUtils.daysBetween(
      AppUtils.parseDate(workspace.startDate),
      AppUtils.parseDate(workspace.endDate),
    );
    final percent = NumberFormat('0.#', locale).format(progress);
    final ring = Semantics(
      label: l10n.progressPercentage(percent),
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 144,
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: (progress / 100).clamp(0, 1),
                strokeWidth: 12,
                strokeCap: StrokeCap.round,
                backgroundColor: colors.primaryContainer,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '$percent%',
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: colors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    final stats = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _stat(
          context,
          l10n.totalHours,
          duration(totalHours),
          Icons.schedule_rounded,
        ),
        const SizedBox(width: 12),
        _stat(
          context,
          l10n.expectedHours,
          duration(days * workspace.dailyTargetHours),
          Icons.flag_outlined,
        ),
      ],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.overallProgress, style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '${l10n.dailyTarget}: ${duration(workspace.dailyTargetHours)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${AppUtils.displayDate(workspace.startDate)} — ${AppUtils.displayDate(workspace.endDate)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            LayoutBuilder(
              builder: (context, constraints) => constraints.maxWidth >= 580
                  ? Row(
                      children: [
                        ring,
                        const SizedBox(width: 32),
                        Expanded(child: stats),
                      ],
                    )
                  : Column(children: [ring, const SizedBox(height: 28), stats]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: theme.colorScheme.primary, size: 22),
            const SizedBox(height: 12),
            Text(value, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
