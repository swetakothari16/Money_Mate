import 'package:intl/intl.dart';

import '../constants/app_constants.dart';

/// Utility for formatting currency amounts.
class CurrencyFormatter {
  CurrencyFormatter._();

  static final _formatter = NumberFormat.currency(
    symbol: AppConstants.defaultCurrencySymbol,
    decimalDigits: 2,
  );

  static String format(double amount) => _formatter.format(amount);

  static String formatCompact(double amount) {
    if (amount.abs() >= 1e6) {
      return '${AppConstants.defaultCurrencySymbol}${(amount / 1e6).toStringAsFixed(1)}M';
    }
    if (amount.abs() >= 1e3) {
      return '${AppConstants.defaultCurrencySymbol}${(amount / 1e3).toStringAsFixed(1)}K';
    }
    return format(amount);
  }
}

/// Utility for formatting dates.
class DateFormatter {
  DateFormatter._();

  static String short(DateTime date) =>
      DateFormat(AppConstants.dateFormatShort).format(date);

  static String full(DateTime date) =>
      DateFormat(AppConstants.dateFormatFull).format(date);

  static String month(DateTime date) =>
      DateFormat(AppConstants.dateFormatMonth).format(date);

  static String relative(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return short(date);
  }
}
