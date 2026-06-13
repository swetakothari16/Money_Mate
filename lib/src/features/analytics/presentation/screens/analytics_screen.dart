import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../providers/analytics_providers.dart';
import '../widgets/pie_chart_widget.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final period = ref.watch(analyticsPeriodProvider);

    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Expense Partner',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'All accounts',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(analyticsExpensesProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg, vertical: AppDimens.sm),
          child: Column(
            children: [
              // 1. Month / Period Switcher
              Container(
                margin: const EdgeInsets.only(bottom: AppDimens.md),
                padding: const EdgeInsets.symmetric(horizontal: AppDimens.sm),
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withOpacity(0.02),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _buildPeriodSwitcher(context, ref, period),
              ).animate().fadeIn(duration: 400.ms),

              // 2. Monefy Grid + Donut Card
              GlassCard(
                padding: const EdgeInsets.all(AppDimens.md),
                child: const ExpensePieChartWidget(),
              ).animate().fadeIn(duration: 500.ms).scale(begin: const Offset(0.98, 0.98)),
              
              const SizedBox(height: AppDimens.xxl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodSwitcher(BuildContext context, WidgetRef ref, AnalyticsPeriod period) {
    final theme = Theme.of(context);
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          icon: Icon(Icons.chevron_left_rounded, color: theme.colorScheme.primary),
          onPressed: () {
            final current = ref.read(analyticsPeriodProvider);
            final index = (current.index - 1) % AnalyticsPeriod.values.length;
            ref.read(analyticsPeriodProvider.notifier).state = AnalyticsPeriod.values[index];
          },
        ),
        Text(
          _periodLabel(period).toUpperCase(),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w900,
            color: theme.colorScheme.primary,
            letterSpacing: 1.5,
            fontSize: 14,
          ),
        ),
        IconButton(
          icon: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.primary),
          onPressed: () {
            final current = ref.read(analyticsPeriodProvider);
            final index = (current.index + 1) % AnalyticsPeriod.values.length;
            ref.read(analyticsPeriodProvider.notifier).state = AnalyticsPeriod.values[index];
          },
        ),
      ],
    );
  }

  String _periodLabel(AnalyticsPeriod period) {
    switch (period) {
      case AnalyticsPeriod.thisWeek:
        return 'This Week';
      case AnalyticsPeriod.thisMonth:
        return _monthName(DateTime.now().month);
      case AnalyticsPeriod.lastMonth:
        final now = DateTime.now();
        final prevMonth = DateTime(now.year, now.month - 1, 1);
        return _monthName(prevMonth.month);
      case AnalyticsPeriod.thisYear:
        return 'This Year';
    }
  }

  String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[(month - 1) % 12];
  }
}
