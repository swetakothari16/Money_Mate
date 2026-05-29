import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../providers/analytics_providers.dart';
import '../../../../core/utils/formatters.dart';

class MonthlyTrendChartWidget extends ConsumerWidget {
  const MonthlyTrendChartWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final trendAsync = ref.watch(monthlyTrendProvider);

    return trendAsync.when(
      data: (points) {
        if (points.isEmpty) {
          return const SizedBox(
            height: 200,
            child: Center(child: Text('No data for this period')),
          );
        }

        // Find max amount to set Y axis boundary
        double maxAmount = 0;
        for (final p in points) {
          if (p.amount > maxAmount) maxAmount = p.amount;
        }
        if (maxAmount == 0) maxAmount = 100; // default if all 0

        return SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxAmount > 4 ? maxAmount / 4 : 1,
                getDrawingHorizontalLine: (value) {
                  return FlLine(
                    color: theme.colorScheme.onSurface.withOpacity(0.05),
                    strokeWidth: 1,
                  );
                },
              ),
              titlesData: FlTitlesData(
                show: true,
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: (points.length / 5).ceilToDouble(),
                    getTitlesWidget: (value, meta) {
                      if (value < 1 || value > points.length) return const SizedBox();
                      return Text(
                        value.toInt().toString(),
                        style: TextStyle(
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                          fontSize: 10,
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: maxAmount > 4 ? maxAmount / 4 : 1,
                    reservedSize: 40,
                    getTitlesWidget: (value, meta) {
                      if (value == 0) return const SizedBox();
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          CurrencyFormatter.formatCompact(value),
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                            fontSize: 10,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: 1,
              maxX: points.length.toDouble(),
              minY: 0,
              maxY: maxAmount * 1.1,
              lineBarsData: [
                LineChartBarData(
                  spots: points.map((p) => FlSpot(p.day.toDouble(), p.amount)).toList(),
                  isCurved: true,
                  gradient: AppColors.expenseGradient,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.expense.withOpacity(0.3),
                        AppColors.expense.withOpacity(0.0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
            swapAnimationDuration: const Duration(milliseconds: 800),
            swapAnimationCurve: Curves.easeInOutCubic,
          ),
        );
      },
      loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => SizedBox(height: 200, child: Center(child: Text('Error: $e'))),
    );
  }
}
