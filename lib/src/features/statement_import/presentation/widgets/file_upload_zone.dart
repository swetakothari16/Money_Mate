import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_dimens.dart';
import '../providers/statement_import_providers.dart';

class FileUploadZone extends ConsumerWidget {
  const FileUploadZone({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppDimens.xl),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.15),
        borderRadius: BorderRadius.circular(AppDimens.radiusLg),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.3),
          width: 2,
          style: BorderStyle.solid, // Flutter doesn't have native dashed border without custom painter, solid is clean & beautiful
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated Upload Icon
          Container(
            padding: const EdgeInsets.all(AppDimens.lg),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.upload_file_rounded,
              size: 48,
              color: theme.colorScheme.primary,
            ),
          ).animate(onPlay: (controller) => controller.repeat(reverse: true))
           .move(begin: const Offset(0, -4), end: const Offset(0, 4), duration: 1500.ms, curve: Curves.easeInOut),
          
          const SizedBox(height: AppDimens.lg),
          
          Text(
            'Import Bank Statement',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: AppDimens.xs),
          
          Text(
            'Upload a PDF bank statement to extract and auto-categorize your expenses.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: AppDimens.xl),
          
          // Features Info List
          _FeatureRow(
            icon: Icons.check_circle_outline_rounded,
            text: 'Filters out salary, credits & refunds automatically',
            iconColor: theme.colorScheme.primary,
          ),
          const SizedBox(height: 8),
          _FeatureRow(
            icon: Icons.auto_awesome_outlined,
            text: 'Auto-maps merchants to categories (Food, Travel, etc.)',
            iconColor: theme.colorScheme.primary,
          ),
          const SizedBox(height: 8),
          _FeatureRow(
            icon: Icons.security_outlined,
            text: 'Local parsing: your bank data never leaves your device',
            iconColor: theme.colorScheme.primary,
          ),
          
          const SizedBox(height: AppDimens.xl),
          
          // Action Buttons
          FilledButton.icon(
            onPressed: () => ref.read(statementImportProvider.notifier).pickAndParseFile(),
            icon: const Icon(Icons.file_open_rounded),
            label: const Text('Select PDF File'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
            ),
          ),
          
          const SizedBox(height: AppDimens.md),
          
          // Test Utility Button
          OutlinedButton.icon(
            onPressed: () => ref.read(statementImportProvider.notifier).generateAndParseMockStatement(),
            icon: const Icon(Icons.science_outlined),
            label: const Text('Try with Mock Statement'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
              side: BorderSide(
                color: theme.colorScheme.outlineVariant,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color iconColor;

  const _FeatureRow({
    required this.icon,
    required this.text,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
        ),
      ],
    );
  }
}
