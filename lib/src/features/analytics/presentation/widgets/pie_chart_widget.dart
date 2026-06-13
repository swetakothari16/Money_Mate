import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/icon_mapper.dart';
import '../../../../core/utils/formatters.dart';
import '../../providers/analytics_providers.dart';
import '../../../expenses/providers/expense_providers.dart';
import '../../../categories/providers/category_providers.dart';
import '../../../../core/enums/expense_category.dart';

class ExpensePieChartWidget extends ConsumerStatefulWidget {
  const ExpensePieChartWidget({super.key});

  @override
  ConsumerState<ExpensePieChartWidget> createState() => _ExpensePieChartWidgetState();
}

class _ExpensePieChartWidgetState extends ConsumerState<ExpensePieChartWidget> {
  int touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoriesAsync = ref.watch(allExpenseCategoriesProvider);
    final chartDataAsync = ref.watch(pieChartDataProvider);
    final summaryAsync = ref.watch(analyticsSummaryProvider);

    return categoriesAsync.when(
      data: (allCategories) {
        return chartDataAsync.when(
          data: (activeData) {
            // We partition the first 16 categories into a 4x4 Monefy grid surrounding the donut chart
            final categories = allCategories.take(16).toList();
            
            final topRow = <CategoryItem>[];
            final leftColumn = <CategoryItem>[];
            final rightColumn = <CategoryItem>[];
            final bottomRow = <CategoryItem>[];

            for (int i = 0; i < categories.length; i++) {
              if (i < 4) {
                topRow.add(categories[i]);
              } else if (i < 8) {
                leftColumn.add(categories[i]);
              } else if (i < 12) {
                rightColumn.add(categories[i]);
              } else {
                bottomRow.add(categories[i]);
              }
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 1. Top Row of Categories (4 items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: topRow.map((cat) {
                      final originalIndex = activeData.indexWhere((item) => item.categoryName == cat.name);
                      return Expanded(
                        child: _buildMonefyCategoryItem(cat, activeData, theme, originalIndex == touchedIndex),
                      );
                    }).toList(),
                  ),
                ),

                // 2. Middle Row (Left Column + Center Donut Chart + Right Column)
                Row(
                  children: [
                    // Left Column (4 items)
                    SizedBox(
                      width: 65,
                      height: 240,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: leftColumn.map((cat) {
                          final originalIndex = activeData.indexWhere((item) => item.categoryName == cat.name);
                          return _buildMonefyCategoryItem(cat, activeData, theme, originalIndex == touchedIndex);
                        }).toList(),
                      ),
                    ),

                    // Center Donut Chart
                    Expanded(
                      child: SizedBox(
                        height: 240,
                        child: _buildPieChart(activeData, theme, summaryAsync),
                      ),
                    ),

                    // Right Column (4 items)
                    SizedBox(
                      width: 65,
                      height: 240,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: rightColumn.map((cat) {
                          final originalIndex = activeData.indexWhere((item) => item.categoryName == cat.name);
                          return _buildMonefyCategoryItem(cat, activeData, theme, originalIndex == touchedIndex);
                        }).toList(),
                      ),
                    ),
                  ],
                ),

                // 3. Bottom Row of Categories (4 items)
                Padding(
                  padding: const EdgeInsets.only(top: 6.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: bottomRow.map((cat) {
                      final originalIndex = activeData.indexWhere((item) => item.categoryName == cat.name);
                      return Expanded(
                        child: _buildMonefyCategoryItem(cat, activeData, theme, originalIndex == touchedIndex),
                      );
                    }).toList(),
                  ),
                ),

                // 4. Balance Banner
                summaryAsync.when(
                  data: (summary) {
                    final balance = summary.balance;
                    final isPositive = balance >= 0;
                    final color = isPositive ? AppColors.income : AppColors.expense;
                    return Container(
                      margin: const EdgeInsets.only(top: 16),
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withOpacity(0.2), width: 1.2),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'BALANCE',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withOpacity(0.5),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.8,
                              fontSize: 10,
                            ),
                          ),
                          Text(
                            '${isPositive ? "+" : ""}${CurrencyFormatter.format(balance)}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w900,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
              ],
            );
          },
          loading: () => const SizedBox(height: 320, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => SizedBox(height: 320, child: Center(child: Text('Error: $e'))),
        );
      },
      loading: () => const SizedBox(height: 320, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => SizedBox(height: 320, child: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildMonefyCategoryItem(CategoryItem cat, List<CategoryChartData> activeData, ThemeData theme, bool isTouched) {
    // Find if this category is active in the current period
    final activeInfo = activeData.cast<CategoryChartData?>().firstWhere(
      (item) => item != null && item.categoryName == cat.name,
      orElse: () => null,
    );

    final color = AppColors.categoryColors[cat.colorIndex % AppColors.categoryColors.length];
    final icon = IconMapper.getIcon(cat.iconName, categoryName: cat.name);

    final isActive = activeInfo != null;
    final percentage = activeInfo?.percentage ?? 0.0;

    return AnimatedScale(
      scale: isTouched ? 1.12 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? color : theme.colorScheme.onSurface.withOpacity(0.2),
            size: 22, // Decreased from 26
          ),
          const SizedBox(height: 4),
          Text(
            ExpenseCategory.getLabel(cat.name),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(isActive ? 0.7 : 0.35),
              fontSize: 8.0, // Decreased from 9
              fontWeight: isTouched ? FontWeight.bold : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            isActive ? '${percentage.toStringAsFixed(0)}%' : '0%',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 9.5, // Decreased from 10.5
              color: isActive 
                  ? theme.colorScheme.onSurface.withOpacity(0.9)
                  : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart(
    List<CategoryChartData> data,
    ThemeData theme,
    AsyncValue<ExpenseSummary> summaryAsync,
  ) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Center Solid Circular Card Background
        Container(
          width: 80, // matches 2 * centerSpaceRadius (40)
          height: 80,
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? const Color(0xFF1E212A)
                : Colors.white,
            shape: BoxShape.circle,
          ),
        ),

        PieChart(
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
            sectionsSpace: 3,
            centerSpaceRadius: 40, // Decreased from 50
            sections: _generateSections(data, theme),
          ),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOutCubic,
        ),

        // Donut Center Text showing period's Income & Expenses with smaller decimals
        summaryAsync.when(
          data: (summary) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _formatMonefyAmount(summary.totalIncome, AppColors.income, 11), // Decreased from 14
                const SizedBox(height: 4),
                _formatMonefyAmount(summary.totalExpense, AppColors.expense, 11), // Decreased from 14
              ],
            );
          },
          loading: () => const SizedBox(
            width: 15,
            height: 15,
            child: CircularProgressIndicator(strokeWidth: 1.5),
          ),
          error: (_, __) => const SizedBox(),
        ),
      ],
    );
  }

  Widget _formatMonefyAmount(double amount, Color color, double fontSize) {
    final formatted = CurrencyFormatter.format(amount);
    final dotIndex = formatted.lastIndexOf('.');
    if (dotIndex != -1) {
      final mainPart = formatted.substring(0, dotIndex);
      final decimalPart = formatted.substring(dotIndex); // e.g. ".00"
      
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            mainPart,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: fontSize,
            ),
          ),
          Text(
            decimalPart,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: fontSize * 0.75,
            ),
          ),
        ],
      );
    }
    
    return Text(
      formatted,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w900,
        fontSize: fontSize,
      ),
    );
  }

  List<PieChartSectionData> _generateSections(List<CategoryChartData> data, ThemeData theme) {
    if (data.isEmpty) {
      return [
        PieChartSectionData(
          color: theme.colorScheme.onSurface.withOpacity(0.08),
          value: 100,
          showTitle: false,
          radius: 20.0, // Decreased from 30
        ),
      ];
    }

    return List.generate(data.length, (i) {
      final isTouched = i == touchedIndex;
      final radius = isTouched ? 25.0 : 20.0; // Decreased from 30/36
      final item = data[i];
      final color = AppColors.categoryColors[item.colorIndex % AppColors.categoryColors.length];

      return PieChartSectionData(
        color: color,
        value: item.percentage,
        showTitle: isTouched,
        title: '${item.percentage.toStringAsFixed(0)}%',
        radius: radius,
        titleStyle: const TextStyle(
          fontSize: 9, // Decreased from 11
          fontWeight: FontWeight.bold,
          color: Colors.white,
          shadows: [Shadow(color: Colors.black26, blurRadius: 2)],
        ),
      );
    });
  }
}
