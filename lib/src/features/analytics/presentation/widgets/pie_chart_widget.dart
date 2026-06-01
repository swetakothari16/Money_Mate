import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../providers/analytics_providers.dart';

class ExpensePieChartWidget extends ConsumerStatefulWidget {
  const ExpensePieChartWidget({super.key});

  @override
  ConsumerState<ExpensePieChartWidget> createState() => _ExpensePieChartWidgetState();
}

class _ExpensePieChartWidgetState extends ConsumerState<ExpensePieChartWidget> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final chartDataAsync = ref.watch(pieChartDataProvider);

    return chartDataAsync.when(
      data: (data) {
        if (data.isEmpty) {
          return const SizedBox(
            height: 220,
            child: Center(child: Text('No expense data to display')),
          );
        }

        return SizedBox(
          height: 220,
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            touchedIndex = -1;
                            return;
                          }
                          touchedIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 4,
                    centerSpaceRadius: 40,
                    sections: _generateSections(data),
                  ),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOutCubic,
                ),
              ),
              Expanded(
                flex: 1,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: data.length > 4 ? 4 : data.length, // Show top 4 in legend
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = data[index];
                    final color = AppColors.categoryColors[item.colorIndex % AppColors.categoryColors.length];
                    final isTouched = index == touchedIndex;
                    
                    return Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            item.categoryName,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: isTouched ? FontWeight.bold : FontWeight.normal,
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(isTouched ? 1 : 0.7),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 220, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => SizedBox(height: 220, child: Center(child: Text('Error: $e'))),
    );
  }

  List<PieChartSectionData> _generateSections(List<CategoryChartData> data) {
    return List.generate(data.length, (i) {
      final isTouched = i == touchedIndex;
      final fontSize = isTouched ? 18.0 : 12.0;
      final radius = isTouched ? 50.0 : 40.0;
      final item = data[i];
      final color = AppColors.categoryColors[item.colorIndex % AppColors.categoryColors.length];

      return PieChartSectionData(
        color: color,
        value: item.percentage,
        title: '${item.percentage.toStringAsFixed(0)}%',
        radius: radius,
        titleStyle: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: const [Shadow(color: Colors.black26, blurRadius: 2)],
        ),
      );
    });
  }
}
