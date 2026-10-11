import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../../core/utils.dart';

/// Ranked subject bars with readable labels and exact study durations.
class TitleChart extends StatelessWidget {
  final Map<String, double> titleHours;

  const TitleChart({super.key, required this.titleHours});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final entries = titleHours.entries.take(10).toList();
    if (entries.isEmpty) return Text(l10n.noDataAvailable);
    final maxHours =
        entries.map((entry) => entry.value).reduce((a, b) => a > b ? a : b);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: Text(entry.key,
                                  style:
                                      Theme.of(context).textTheme.titleSmall)),
                          const SizedBox(width: 12),
                          Flexible(
                              child: Text(l10n.hoursValue(
                                  AppUtils.formatHourValue(entry.value,
                                      locale: locale)))),
                        ]),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: maxHours > 0
                          ? (entry.value / maxHours).clamp(0.0, 1.0)
                          : 0,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(8),
                      semanticsLabel: entry.key,
                      semanticsValue: l10n.hoursValue(AppUtils.formatHourValue(
                          entry.value,
                          locale: locale)),
                    ),
                  ]),
            ),
        ]),
      ),
    );
  }
}
