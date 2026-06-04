import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/providers/preferences_provider.dart';
import '../../../auth/providers/auth_providers.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final authState = ref.watch(authStateProvider);
    final user = authState.value;
    final isAnonymous = user == null || user.isAnonymous;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppDimens.lg),
        children: [
          // ─── Profile Card ──────────────────────────────────────────
          InkWell(
            onTap: isAnonymous ? () => context.go('/login') : null,
            borderRadius: BorderRadius.circular(AppDimens.radiusLg),
            child: Container(
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
                      isAnonymous ? Icons.person_outline_rounded : Icons.person_rounded,
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
                          isAnonymous ? (ref.watch(userNameProvider) ?? 'Offline Guest') : (user.email ?? 'Expense Partner User'),
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isAnonymous ? 'Sign in to back up data' : 'Cloud sync active',
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
            ),
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: AppDimens.lg),

          // ─── Account Section ───────────────────────────────────────
          _SectionTitle(title: 'Account'),
          const SizedBox(height: AppDimens.sm),
          if (isAnonymous)
            _SettingsTile(
              icon: Icons.cloud_queue_rounded,
              title: 'Back up Data / Register',
              subtitle: 'Save your data to a secure cloud account',
              onTap: () => context.go('/login'),
            ),
          _SettingsTile(
            icon: Icons.logout_rounded,
            title: 'Sign Out',
            subtitle: isAnonymous ? 'Wipe guest session & return to login' : 'Wipe local cache & log out',
            onTap: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Sign Out'),
                  content: Text(
                    isAnonymous
                        ? 'Are you sure you want to sign out? This will wipe your local guest data and return you to the login page.'
                        : 'Are you sure you want to sign out? This will wipe your local offline database and reset your profile settings. Your cloud data is safe and will be restored when you sign in again.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sign Out', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                // Reset preferences
                final prefs = ref.read(sharedPreferencesProvider);
                await prefs.remove('userName');
                await prefs.remove('userCurrencyCode');
                await prefs.remove('userCurrencySymbol');
                await prefs.remove('hasCompletedOnboarding');
                // Set default currency symbol back
                CurrencyFormatter.updateCurrencySymbol('₹');

                await ref.read(authRepositoryProvider).signOut();
              }
            },
          ),

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
            subtitle: '${ref.watch(currencyCodeProvider)} (${ref.watch(currencySymbolProvider)})',
            onTap: () => _showCurrencyDialog(context, ref),
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
            title: 'About Expense Partner',
            subtitle: 'Version 1.0.0',
            onTap: () {},
          ),
        ],
      ),
    );
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
      builder: (context) => AlertDialog(
        title: const Text('Select Currency'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: currencies.map((c) {
            final isSelected = c['code'] == selectedCode;
            return RadioListTile<String>(
              value: c['code']!,
              groupValue: selectedCode,
              title: Text(c['name']!),
              selected: isSelected,
              onChanged: (val) async {
                if (val != null) {
                  await ref.read(currencyCodeProvider.notifier).setCurrencyCode(val);
                  await ref.read(currencySymbolProvider.notifier).setCurrencySymbol(c['symbol']!);
                  if (context.mounted) Navigator.pop(context);
                }
              },
            );
          }).toList(),
        ),
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
