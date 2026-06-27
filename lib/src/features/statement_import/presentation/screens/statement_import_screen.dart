import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/formatters.dart';
import '../providers/statement_import_providers.dart';
import '../widgets/file_upload_zone.dart';
import '../widgets/parsed_transaction_card.dart';

class StatementImportScreen extends ConsumerWidget {
  const StatementImportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(statementImportProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            ref.read(statementImportProvider.notifier).reset();
            context.pop();
          },
        ),
        title: const Text('Bank Statement Import'),
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _buildBody(context, ref, state, theme),
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    StatementImportState state,
    ThemeData theme,
  ) {
    switch (state.status) {
      case StatementImportStatus.idle:
        return const SingleChildScrollView(
          padding: EdgeInsets.all(AppDimens.lg),
          child: Column(
            children: [
              SizedBox(height: AppDimens.md),
              FileUploadZone(),
            ],
          ),
        );

      case StatementImportStatus.parsing:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppDimens.lg),
              Text(
                'Reading PDF Statement...',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ).animate(onPlay: (controller) => controller.repeat())
               .shimmer(duration: 1500.ms, color: theme.colorScheme.primary),
              const SizedBox(height: AppDimens.xs),
              Text(
                'Extracting transaction lines & mapping categories',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        );

      case StatementImportStatus.preview:
        final selectedTxs = state.transactions.where((tx) => tx.isSelected).toList();
        final totalAmount = selectedTxs.fold<double>(0.0, (sum, tx) => sum + tx.amount);
        final allSelected = state.transactions.every((tx) => tx.isSelected);

        return Column(
          children: [
            // Summary Info Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: AppDimens.lg, vertical: AppDimens.md),
              color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.15),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.fileName ?? 'statement.pdf',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Found ${state.transactions.length} debit transactions',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      final notifier = ref.read(statementImportProvider.notifier);
                      for (final tx in state.transactions) {
                        if (allSelected) {
                          // Unselect all
                          if (tx.isSelected) notifier.toggleSelection(tx.id);
                        } else {
                          // Select all
                          if (!tx.isSelected) notifier.toggleSelection(tx.id);
                        }
                      }
                    },
                    icon: Icon(
                      allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
                      size: 18,
                    ),
                    label: Text(allSelected ? 'Deselect All' : 'Select All'),
                  ),
                ],
              ),
            ),

            // Main List
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(AppDimens.lg),
                itemCount: state.transactions.length,
                itemBuilder: (context, index) {
                  final tx = state.transactions[index];
                  return ParsedTransactionCard(
                    key: ValueKey(tx.id),
                    transaction: tx,
                  );
                },
              ),
            ),

            // Sticky Bottom Import Panel
            Container(
              padding: const EdgeInsets.all(AppDimens.lg),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
                border: Border(
                  top: BorderSide(
                    color: theme.colorScheme.outlineVariant.withOpacity(0.2),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Total to Import',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          CurrencyFormatter.format(totalAmount),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppDimens.md),
                  FilledButton(
                    onPressed: selectedTxs.isEmpty
                        ? null
                        : () => ref.read(statementImportProvider.notifier).importTransactions(),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      ),
                    ),
                    child: Text(
                      'Import (${selectedTxs.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );

      case StatementImportStatus.importing:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: AppDimens.lg),
              Text(
                'Importing Expenses...',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppDimens.xs),
              Text(
                'Saving to local database & queuing cloud sync',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
              ),
            ],
          ),
        );

      case StatementImportStatus.success:
        return Padding(
          padding: const EdgeInsets.all(AppDimens.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.check_circle_rounded,
                size: 96,
                color: theme.colorScheme.primary,
              ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
              const SizedBox(height: AppDimens.lg),
              Text(
                'Import Completed!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimens.sm),
              Text(
                'Successfully imported ${state.importedCount} transactions into your expenses database.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimens.xxl),
              FilledButton(
                onPressed: () {
                  ref.read(statementImportProvider.notifier).reset();
                  context.pop();
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                ),
                child: const Text(
                  'Finish',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );

      case StatementImportStatus.error:
        return Padding(
          padding: const EdgeInsets.all(AppDimens.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 80,
                color: theme.colorScheme.error,
              ).animate().shake(duration: 400.ms),
              const SizedBox(height: AppDimens.lg),
              Text(
                'Import Failed',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimens.md),
              Container(
                padding: const EdgeInsets.all(AppDimens.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.errorContainer.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  border: Border.all(color: theme.colorScheme.error.withOpacity(0.2)),
                ),
                child: Text(
                  state.errorMessage ?? 'An unknown error occurred while processing the statement.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: AppDimens.xxl),
              FilledButton(
                onPressed: () => ref.read(statementImportProvider.notifier).reset(),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                ),
                child: const Text('Try Another Statement'),
              ),
              const SizedBox(height: AppDimens.md),
              TextButton(
                onPressed: () {
                  ref.read(statementImportProvider.notifier).reset();
                  context.pop();
                },
                child: const Text('Cancel'),
              ),
            ],
          ),
        );

      case StatementImportStatus.passwordRequired:
        return PasswordPromptForm(
          errorMessage: state.errorMessage,
          onSubmit: (password) {
            ref.read(statementImportProvider.notifier).parseWithPassword(password);
          },
          onCancel: () {
            ref.read(statementImportProvider.notifier).reset();
          },
        );
    }
  }
}

class PasswordPromptForm extends StatefulWidget {
  final String? errorMessage;
  final ValueChanged<String> onSubmit;
  final VoidCallback onCancel;

  const PasswordPromptForm({
    super.key,
    this.errorMessage,
    required this.onSubmit,
    required this.onCancel,
  });

  @override
  State<PasswordPromptForm> createState() => _PasswordPromptFormState();
}

class _PasswordPromptFormState extends State<PasswordPromptForm> {
  final _controller = TextEditingController();
  bool _obscureText = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(AppDimens.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: 80,
            color: theme.colorScheme.primary,
          ).animate().scale(duration: 400.ms, curve: Curves.elasticOut),
          const SizedBox(height: AppDimens.lg),
          Text(
            'Password Protected Statement',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimens.md),
          Container(
            padding: const EdgeInsets.all(AppDimens.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2)),
            ),
            child: Text(
              widget.errorMessage ?? 'Please enter the password to open this statement.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppDimens.xl),
          TextField(
            controller: _controller,
            obscureText: _obscureText,
            decoration: InputDecoration(
              labelText: 'Password',
              hintText: 'Enter PDF password',
              prefixIcon: const Icon(Icons.key_rounded),
              suffixIcon: IconButton(
                icon: Icon(_obscureText ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                onPressed: () => setState(() => _obscureText = !_obscureText),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
            ),
          ),
          const SizedBox(height: AppDimens.xl),
          FilledButton(
            onPressed: () {
              final password = _controller.text.trim();
              if (password.isNotEmpty) {
                widget.onSubmit(password);
              }
            },
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
            ),
            child: const Text(
              'Unlock & Import',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: AppDimens.md),
          TextButton(
            onPressed: widget.onCancel,
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }
}
