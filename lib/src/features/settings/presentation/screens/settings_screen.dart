import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/providers/preferences_provider.dart';
import '../../../../core/providers/theme_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import '../../../auth/providers/auth_providers.dart';
import '../../../categories/presentation/screens/categories_screen.dart';
import '../../../expenses/providers/expense_providers.dart';
import '../../../expenses/data/models/expense_model.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);
    final user = authState.value;
    final isAnonymous = user == null || user.isAnonymous;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimens.lg,
              vertical: AppDimens.md,
            ),
            children: [
              // ─── Profile Card ──────────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(AppDimens.lg),
                decoration: BoxDecoration(
                  gradient: AppColors.cardGradientDark,
                  borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.08),
                  ),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Colors.white.withOpacity(0.15),
                      child: const Icon(
                        Icons.person_rounded,
                        size: 28,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: AppDimens.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ref.watch(userNameProvider) ?? 'Expense Partner User',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Local Profile',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutQuad),

              const SizedBox(height: AppDimens.xl),

              // ─── General Section ───────────────────────────────────────
              _SettingsSection(
                title: 'General',
                children: [
                  _SettingsTile(
                    icon: Icons.palette_rounded,
                    iconBgColor: Colors.purple.withOpacity(0.12),
                    iconColor: Colors.purple,
                    title: 'Appearance',
                    subtitle: _getThemeName(themeMode),
                    onTap: () => _showThemeDialog(context, ref, themeMode),
                  ),
                  _SettingsTile(
                    icon: Icons.attach_money_rounded,
                    iconBgColor: Colors.teal.withOpacity(0.12),
                    iconColor: Colors.teal,
                    title: 'Currency',
                    subtitle: '${ref.watch(currencyCodeProvider)} (${ref.watch(currencySymbolProvider)})',
                    onTap: () => _showCurrencyDialog(context, ref),
                  ),
                  _SettingsTile(
                    icon: Icons.category_rounded,
                    iconBgColor: Colors.amber.withOpacity(0.12),
                    iconColor: Colors.amber[800] ?? Colors.amber,
                    title: 'Categories',
                    subtitle: 'Manage categories',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CategoriesScreen(),
                      ),
                    ),
                  ),
                ],
              ),

              // ─── Data Section ──────────────────────────────────────────
              _SettingsSection(
                title: 'Data',
                children: [
                  _SettingsTile(
                    icon: Icons.import_export_rounded,
                    iconBgColor: Colors.blue.withOpacity(0.12),
                    iconColor: Colors.blue,
                    title: 'Export Data',
                    subtitle: 'CSV, PDF',
                    onTap: () => _showExportOptions(context, ref),
                  ),
                  _SettingsTile(
                    icon: Icons.receipt_long_rounded,
                    iconBgColor: Colors.cyan.withOpacity(0.12),
                    iconColor: Colors.cyan,
                    title: 'Bank Statement Import',
                    subtitle: 'Auto-import transactions from PDF',
                    onTap: () => context.push(AppRoutes.statementImport),
                  ),
                  _SettingsTile(
                    icon: Icons.settings_backup_restore_rounded,
                    iconBgColor: Colors.indigo.withOpacity(0.12),
                    iconColor: Colors.indigo,
                    title: 'Backup & Restore',
                    subtitle: 'Keep your data safe',
                    onTap: () {},
                  ),
                ],
              ),

              // ─── About Section ─────────────────────────────────────────
              _SettingsSection(
                title: 'About',
                children: [
                  _SettingsTile(
                    icon: Icons.info_rounded,
                    iconBgColor: Colors.grey.withOpacity(0.12),
                    iconColor: Colors.grey,
                    title: 'About Expense Partner',
                    subtitle: 'Version 1.0.0',
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getThemeName(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System Default';
      case ThemeMode.light:
        return 'Light Mode';
      case ThemeMode.dark:
        return 'Dark Mode';
    }
  }

  void _showThemeDialog(BuildContext context, WidgetRef ref, ThemeMode currentMode) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Appearance'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: AppDimens.md),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ThemeOption(
              title: 'System Default',
              icon: Icons.brightness_auto_rounded,
              isSelected: currentMode == ThemeMode.system,
              onTap: () => _updateTheme(context, ref, ThemeMode.system),
            ),
            _ThemeOption(
              title: 'Light Mode',
              icon: Icons.light_mode_rounded,
              isSelected: currentMode == ThemeMode.light,
              onTap: () => _updateTheme(context, ref, ThemeMode.light),
            ),
            _ThemeOption(
              title: 'Dark Mode',
              icon: Icons.dark_mode_rounded,
              isSelected: currentMode == ThemeMode.dark,
              onTap: () => _updateTheme(context, ref, ThemeMode.dark),
            ),
          ],
        ),
      ),
    );
  }

  void _updateTheme(BuildContext context, WidgetRef ref, ThemeMode mode) async {
    await ref.read(themeModeProvider.notifier).setThemeMode(mode);
    if (context.mounted) Navigator.pop(context);
  }

  void _showCurrencyDialog(BuildContext context, WidgetRef ref) {
    final selectedCode = ref.read(currencyCodeProvider);
    final currencies = [
      {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee (₹)'},
      {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar (\$)'},
      {'code': 'EUR', 'symbol': '€', 'name': 'Euro (€)'},
      {'code': 'GBP', 'symbol': '£', 'name': 'British Pound (£)'},
      {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen (¥)'},
    ];

    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Select Currency'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: AppDimens.md),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: currencies.map((c) {
              final isSelected = c['code'] == selectedCode;
              return ListTile(
                leading: SizedBox(
                  width: 32,
                  child: Text(
                    c['symbol']!,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                title: Text(
                  c['name']!,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                  ),
                ),
                trailing: isSelected
                    ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
                    : null,
                onTap: () async {
                  await ref.read(currencyCodeProvider.notifier).setCurrencyCode(c['code']!);
                  await ref.read(currencySymbolProvider.notifier).setCurrencySymbol(c['symbol']!);
                  if (context.mounted) Navigator.pop(context);
                },
              );
            }).toList(),
          ),
        );
      },
    );
  }

  void _showExportOptions(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: const Text('Export Transactions'),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.table_chart_rounded, color: Colors.blue),
                ),
                title: const Text('Export to CSV'),
                subtitle: const Text('Best for Microsoft Excel or Google Sheets'),
                onTap: () {
                  Navigator.pop(context);
                  _exportData(context, ref, 'csv');
                },
              ),
              const SizedBox(height: AppDimens.sm),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.red),
                ),
                title: const Text('Export to PDF'),
                subtitle: const Text('Beautiful print-ready styled table report'),
                onTap: () {
                  Navigator.pop(context);
                  _exportData(context, ref, 'pdf');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _exportData(BuildContext context, WidgetRef ref, String format) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final expensesAsync = ref.read(expenseListProvider);
      final expenses = expensesAsync.value ?? [];

      if (expenses.isEmpty) {
        if (context.mounted) Navigator.pop(context); // Close loading
        _showErrorDialog(context, 'No transactions found to export.');
        return;
      }

      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final Directory exportDir = await _getExportDirectory();
      final String fileName = 'expense_partner_export_$dateStr.$format';
      final String filePath = '${exportDir.path}/$fileName';
      final File file = File(filePath);

      if (format == 'csv') {
        final csvData = _generateCsv(expenses);
        await file.writeAsString(csvData);
      } else {
        final pdfBytes = await _generatePdf(expenses);
        await file.writeAsBytes(pdfBytes);
      }

      if (context.mounted) {
        Navigator.pop(context); // Close loading
        _showSuccessDialog(context, format.toUpperCase(), filePath);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Close loading
        _showErrorDialog(context, 'Failed to export data: $e');
      }
    }
  }

  Future<Directory> _getExportDirectory() async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      final dir = await getDownloadsDirectory();
      if (dir != null) return dir;
    }
    return await getApplicationDocumentsDirectory();
  }

  String _generateCsv(List<ExpenseModel> expenses) {
    final csvBuffer = StringBuffer();
    csvBuffer.writeln('Date,Title,Amount,Type,Category,Note,Payment Method');

    for (final e in expenses) {
      final dateStr = DateFormat('yyyy-MM-dd HH:mm').format(e.date);
      final cleanTitle = e.title.replaceAll('"', '""');
      final cleanNote = (e.note ?? '').replaceAll('"', '""');
      csvBuffer.writeln(
        '$dateStr,"$cleanTitle",${e.amount},${e.type.name.toUpperCase()},${e.category},"$cleanNote",${e.paymentMethod.name}'
      );
    }
    return csvBuffer.toString();
  }

  Future<List<int>> _generatePdf(List<ExpenseModel> expenses) async {
    final pdfDocument = PdfDocument();
    final page = pdfDocument.pages.add();

    final fontTitle = PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold);
    final fontHeader = PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold);
    final fontBody = PdfStandardFont(PdfFontFamily.helvetica, 10);

    page.graphics.drawString(
      'Expense Partner Transactions Report',
      fontTitle,
      brush: PdfSolidBrush(PdfColor(17, 24, 39)), // Near black
      bounds: const Rect.fromLTWH(0, 0, 0, 0),
    );

    final genDate = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    double totalIncome = 0;
    double totalExpense = 0;
    for (final e in expenses) {
      if (e.type == TransactionType.income) {
        totalIncome += e.amount;
      } else if (e.type == TransactionType.expense) {
        totalExpense += e.amount;
      }
    }

    page.graphics.drawString(
      'Generated: $genDate\n'
      'Total Transactions: ${expenses.length}\n'
      'Total Income: \$${totalIncome.toStringAsFixed(2)}  |  Total Expense: \$${totalExpense.toStringAsFixed(2)}\n'
      'Net Balance: \$${(totalIncome - totalExpense).toStringAsFixed(2)}',
      fontBody,
      brush: PdfSolidBrush(PdfColor(107, 114, 128)),
      bounds: const Rect.fromLTWH(0, 30, 0, 0),
    );

    final grid = PdfGrid();
    grid.columns.add(count: 6);
    grid.headers.add(1);

    final headerRow = grid.headers[0];
    headerRow.cells[0].value = 'Date';
    headerRow.cells[1].value = 'Title';
    headerRow.cells[2].value = 'Category';
    headerRow.cells[3].value = 'Payment';
    headerRow.cells[4].value = 'Type';
    headerRow.cells[5].value = 'Amount';

    for (int i = 0; i < headerRow.cells.count; i++) {
      headerRow.cells[i].style.backgroundBrush = PdfSolidBrush(PdfColor(16, 185, 129)); // Emerald Green
      headerRow.cells[i].style.textBrush = PdfBrushes.white;
      headerRow.cells[i].style.font = fontHeader;
    }

    for (final e in expenses) {
      final row = grid.rows.add();
      row.cells[0].value = DateFormat('yyyy-MM-dd').format(e.date);
      row.cells[1].value = e.title;
      row.cells[2].value = e.category;
      row.cells[3].value = e.paymentMethod.name.toUpperCase();
      row.cells[4].value = e.type.name.toUpperCase();
      row.cells[5].value = '${e.type == TransactionType.income ? "+" : "-"}\$${e.amount.toStringAsFixed(2)}';

      final amountColor = e.type == TransactionType.income ? PdfColor(16, 185, 129) : PdfColor(239, 68, 68);
      row.cells[5].style.textBrush = PdfSolidBrush(amountColor);
      row.cells[5].style.font = fontHeader;
    }

    grid.style = PdfGridStyle(
      cellPadding: PdfPaddings(left: 6, right: 6, top: 4, bottom: 4),
      font: fontBody,
    );

    grid.draw(page: page, bounds: const Rect.fromLTWH(0, 110, 0, 0));

    final bytes = await pdfDocument.save();
    pdfDocument.dispose();
    return bytes;
  }

  void _showSuccessDialog(BuildContext context, String type, String filePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.green),
            const SizedBox(width: 8),
            Text('$type Exported'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your transaction history was successfully exported to:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                filePath,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_rounded, color: Colors.red),
            const SizedBox(width: 8),
            const Text('Export Failed'),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isAnonymous;

  const _StatusBadge({required this.isAnonymous});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isAnonymous ? Colors.amber.withOpacity(0.2) : const Color(0xFF10B981).withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isAnonymous ? Colors.amber.withOpacity(0.3) : const Color(0xFF10B981).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isAnonymous ? Icons.warning_amber_rounded : Icons.cloud_done_rounded,
            size: 13,
            color: isAnonymous ? const Color(0xFFFFB020) : const Color(0xFF34D399),
          ),
          const SizedBox(width: 4),
          Text(
            isAnonymous ? 'Guest Mode' : 'Cloud Synced',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.white,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final List<Widget> itemsWithDividers = [];
    for (int i = 0; i < children.length; i++) {
      itemsWithDividers.add(children[i]);
      if (i < children.length - 1) {
        itemsWithDividers.add(
          Divider(
            height: 1,
            indent: 64, // indentation so it aligns perfectly with the list tile text (excluding icon badge)
            endIndent: 16,
            color: theme.dividerTheme.color ?? theme.colorScheme.outlineVariant.withOpacity(0.15),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.only(bottom: AppDimens.lg),
          clipBehavior: Clip.antiAlias,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimens.radiusMd),
            side: BorderSide(
              color: theme.colorScheme.outlineVariant.withOpacity(0.12),
              width: 1,
            ),
          ),
          child: Column(
            children: itemsWithDividers,
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: AppDimens.md, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconBgColor,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurface.withOpacity(0.55),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: theme.colorScheme.onSurface.withOpacity(0.3),
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.title,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.6),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle_rounded, color: theme.colorScheme.primary)
          : null,
      onTap: onTap,
    );
  }
}
