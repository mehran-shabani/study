import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../core/utils.dart';

class TitleChart extends StatelessWidget {
  final Map<String, double> titleHours;

  const TitleChart({super.key, required this.titleHours});

  @override
  Widget build(BuildContext context) {
    if (titleHours.isEmpty) {
      return const SizedBox(
        height: 250,
        child: Center(child: Text('No data')),
      );
    }

    final entries = titleHours.entries.take(10).toList(); // Top 10
    final maxHours = entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: (entries.length * 50.0) + 50,
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxHours * 1.2,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final title = entries[group.x].key;
                    final hours = rod.toY;
                    return BarTooltipItem(
                      '$title\n${AppUtils.formatHours(hours)}',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 100,
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= entries.length) {
                        return const SizedBox.shrink();
                      }
                      final title = entries[index].key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Text(
                          title.length > 15
                              ? '${title.substring(0, 15)}...'
                              : title,
                          style: const TextStyle(fontSize: 11),
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    getTitlesWidget: (value, meta) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          '${value.toInt()}h',
                          style: const TextStyle(fontSize: 10),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
              ),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                horizontalInterval: maxHours > 0 ? maxHours / 5 : 1,
              ),
              borderData: FlBorderData(
                show: true,
                border: Border(
                  left: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  bottom: BorderSide(
                    color: Theme.of(context).colorScheme.outline,
                  ),
                ),
              ),
              barGroups: List.generate(
                entries.length,
                (index) => BarChartGroupData(
                  x: index,
                  barRods: [
                    BarChartRodData(
                      toY: entries[index].value,
                      color: Theme.of(context).colorScheme.primary,
                      width: 20,
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
