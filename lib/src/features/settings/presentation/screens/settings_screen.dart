import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.lg),
        children: [
          // ─── Profile Card ──────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(AppDimens.lg),
            decoration: BoxDecoration(
              gradient: AppColors.cardGradientDark,
              borderRadius: BorderRadius.circular(AppDimens.radiusLg),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withOpacity(0.1),
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                  child: Icon(
                    Icons.person_rounded,
                    size: 28,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(width: AppDimens.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Money Mate User',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Manage your profile',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.onSurface.withOpacity(0.3),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: AppDimens.lg),

          // ─── General Section ───────────────────────────────────────
          _SectionTitle(title: 'General'),
          const SizedBox(height: AppDimens.sm),
          _SettingsTile(
            icon: Icons.palette_outlined,
            title: 'Appearance',
            subtitle: 'Dark mode',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.attach_money_rounded,
            title: 'Currency',
            subtitle: 'INR (₹)',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.category_outlined,
            title: 'Categories',
            subtitle: 'Manage categories',
            onTap: () {},
          ),

          const SizedBox(height: AppDimens.lg),

          // ─── Data Section ──────────────────────────────────────────
          _SectionTitle(title: 'Data'),
          const SizedBox(height: AppDimens.sm),
          _SettingsTile(
            icon: Icons.cloud_upload_outlined,
            title: 'Export Data',
            subtitle: 'CSV, PDF',
            onTap: () {},
          ),
          _SettingsTile(
            icon: Icons.backup_outlined,
            title: 'Backup & Restore',
            subtitle: 'Keep your data safe',
            onTap: () {},
          ),

          const SizedBox(height: AppDimens.lg),

          // ─── About Section ─────────────────────────────────────────
          _SectionTitle(title: 'About'),
          const SizedBox(height: AppDimens.sm),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'About Money Mate',
            subtitle: 'Version 1.0.0',
            onTap: () {},
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: ListTile(
        onTap: onTap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimens.radiusMd),
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: theme.colorScheme.primary),
        ),
        title: Text(title, style: theme.textTheme.bodyLarge),
        subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: theme.colorScheme.onSurface.withOpacity(0.3),
        ),
      ),
    );
  }
}
