import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
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
    final locale = Localizations.localeOf(context).toString();
    String duration(double value) =>
        l10n.hoursValue(AppUtils.formatHourValue(value, locale: locale));
    final totalHours =
        entries.fold<double>(0.0, (sum, entry) => sum + entry.hours);

    final startDate = AppUtils.parseDate(workspace.startDate);
    final endDate = AppUtils.parseDate(workspace.endDate);
    final days = AppUtils.daysBetween(startDate, endDate);
    final expectedHours = days * workspace.dailyTargetHours;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.overallProgress,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
                '${l10n.dailyTarget}: ${duration(workspace.dailyTargetHours)}'),
            const SizedBox(height: 20),
            Center(
              child: SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 160,
                      height: 160,
                      child: CircularProgressIndicator(
                        value: progress / 100,
                        strokeWidth: 16,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest
                            .withOpacity(0.3),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getProgressColor(context, progress),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${progress.toStringAsFixed(1)}%',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _getProgressColor(context, progress),
                              ),
                        ),
                        Text(
                          l10n.overallProgress,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat(
                  context,
                  l10n.totalHours,
                  duration(totalHours),
                  Icons.schedule,
                ),
                _buildStat(
                  context,
                  l10n.expectedHours,
                  duration(expectedHours),
                  Icons.flag,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(
      BuildContext context, String label, String value, IconData icon) {
    return Expanded(
        child: Column(
      children: [
        Icon(
          icon,
          size: 32,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    ));
  }

  Color _getProgressColor(BuildContext context, double progress) {
    if (progress >= 75) {
      return Colors.green;
    } else if (progress >= 50) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
}
