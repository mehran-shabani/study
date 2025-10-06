import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../domain/helpers.dart';

class TimelineChart extends StatelessWidget {
  final List<DailyPoint> timeline;

  const TimelineChart({super.key, required this.timeline});

  @override
  Widget build(BuildContext context) {
    if (timeline.isEmpty) {
      return const SizedBox(
        height: 250,
        child: Center(child: Text('No data')),
      );
    }

    final maxHours = timeline.map((p) => p.hours).reduce((a, b) => a > b ? a : b);
    final maxY = (maxHours * 1.2).ceilToDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          height: 250,
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY > 0 ? maxY : 10,
              lineBarsData: [
                LineChartBarData(
                  spots: _buildSpots(timeline),
                  isCurved: true,
                  color: Theme.of(context).colorScheme.primary,
                  barWidth: 3,
                  dotData: FlDotData(
                    show: timeline.length <= 31, // Only show dots for monthly view
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                  ),
                ),
              ],
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      return Text(
                        '${value.toInt()}h',
                        style: const TextStyle(fontSize: 10),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: _getInterval(timeline.length),
                    getTitlesWidget: (value, meta) {
                      final index = value.toInt();
                      if (index < 0 || index >= timeline.length) {
                        return const SizedBox.shrink();
                      }
                      final date = timeline[index].date;
                      // Show only day (last 2 digits)
                      final day = date.split('-').last;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          day,
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
                drawVerticalLine: false,
                horizontalInterval: maxY > 0 ? maxY / 5 : 2,
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
            ),
          ),
        ),
      ),
    );
  }

  List<FlSpot> _buildSpots(List<DailyPoint> timeline) {
    return List.generate(
      timeline.length,
      (index) => FlSpot(index.toDouble(), timeline[index].hours),
    );
  }

  double _getInterval(int dataPoints) {
    if (dataPoints <= 7) return 1;
    if (dataPoints <= 30) return 5;
    if (dataPoints <= 90) return 15;
    return 30;
  }
}
