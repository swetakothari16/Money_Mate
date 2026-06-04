import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../../../core/utils/formatters.dart';
import '../../providers/analytics_providers.dart';
import '../widgets/pie_chart_widget.dart';

class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final period = ref.watch(analyticsPeriodProvider);
    final avgSpendAsync = ref.watch(averageDailySpendProvider);
    final topCategoryAsync = ref.watch(topSpendingCategoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analytics'),
        actions: [
          _PeriodSelector(
            currentPeriod: period,
            onChanged: (p) => ref.read(analyticsPeriodProvider.notifier).state = p,
          ),
          const SizedBox(width: AppDimens.md),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(analyticsExpensesProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppDimens.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ─── Insights Row ──────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: avgSpendAsync.when(
                      data: (avg) => _InsightCard(
                        title: 'Daily Average',
                        value: CurrencyFormatter.formatCompact(avg),
                        icon: Icons.show_chart_rounded,
                        color: AppColors.income,
                      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1),
                      loading: () => const _InsightCardSkeleton(),
                      error: (e, _) => const SizedBox(),
                    ),
                  ),
                  const SizedBox(width: AppDimens.md),
                  Expanded(
                    child: topCategoryAsync.when(
                      data: (cat) => _InsightCard(
                        title: 'Top Category',
                        value: cat?.categoryName ?? '-',
                        subtitle: cat != null ? '${cat.percentage}% of total' : '',
                        icon: Icons.star_rounded,
                        color: AppColors.expense,
                      ).animate().fadeIn(duration: 400.ms, delay: 100.ms).slideY(begin: 0.1),
                      loading: () => const _InsightCardSkeleton(),
                      error: (e, _) => const SizedBox(),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: AppDimens.xl),

              // ─── Category Breakdown ────────────────────────────────────
              Text(
                'Expense Breakdown',
                style: theme.textTheme.titleMedium,
              ).animate().fadeIn(duration: 500.ms, delay: 400.ms),
              const SizedBox(height: AppDimens.md),
              GlassCard(
                padding: const EdgeInsets.all(AppDimens.lg),
                child: const ExpensePieChartWidget(),
              ).animate().fadeIn(duration: 500.ms, delay: 500.ms).scale(begin: const Offset(0.95, 0.95)),
              
              const SizedBox(height: AppDimens.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Private Widgets ─────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final AnalyticsPeriod currentPeriod;
  final ValueChanged<AnalyticsPeriod> onChanged;

  const _PeriodSelector({
    required this.currentPeriod,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<AnalyticsPeriod>(
      initialValue: currentPeriod,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _periodName(currentPeriod),
              style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down, size: 16, color: Theme.of(context).colorScheme.primary),
          ],
        ),
      ),
      itemBuilder: (context) => AnalyticsPeriod.values.map((period) {
        return PopupMenuItem(
          value: period,
          child: Text(_periodName(period)),
        );
      }).toList(),
      onSelected: onChanged,
    );
  }

  String _periodName(AnalyticsPeriod period) {
    switch (period) {
      case AnalyticsPeriod.thisWeek:
        return 'This Week';
      case AnalyticsPeriod.thisMonth:
        return 'This Month';
      case AnalyticsPeriod.lastMonth:
        return 'Last Month';
      case AnalyticsPeriod.thisYear:
        return 'This Year';
    }
  }
}

class _InsightCard extends StatelessWidget {
  final String title;
  final String value;
  final String? subtitle;
  final IconData icon;
  final Color color;

  const _InsightCard({
    required this.title,
    required this.value,
    this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(AppDimens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimens.md),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _InsightCardSkeleton extends StatelessWidget {
  const _InsightCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      padding: const EdgeInsets.all(AppDimens.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 28, height: 28, decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Container(width: 80, height: 14, color: Colors.grey.withOpacity(0.2)),
            ],
          ),
          const SizedBox(height: AppDimens.md),
          Container(width: 100, height: 24, color: Colors.grey.withOpacity(0.2)),
        ],
      ),
    );
  }
}
