import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/providers/preferences_provider.dart';
import '../../../../shared/widgets/glass_card.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  
  String _selectedCurrencyCode = 'INR';
  String _selectedCurrencySymbol = '₹';

  final List<Map<String, String>> _currencies = [
    {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee (₹)'},
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar (\$)'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro (€)'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound (£)'},
    {'code': 'JPY', 'symbol': '¥', 'name': 'Japanese Yen (¥)'},
  ];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final userNameNotifier = ref.read(userNameProvider.notifier);
    final currencyCodeNotifier = ref.read(currencyCodeProvider.notifier);
    final currencySymbolNotifier = ref.read(currencySymbolProvider.notifier);
    final onboardingNotifier = ref.read(onboardingProvider.notifier);

    // Save configurations
    await userNameNotifier.setUserName(_nameController.text.trim());
    await currencyCodeNotifier.setCurrencyCode(_selectedCurrencyCode);
    await currencySymbolNotifier.setCurrencySymbol(_selectedCurrencySymbol);
    
    // Complete onboarding
    await onboardingNotifier.completeOnboarding();

    if (mounted) {
      context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : theme.colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppDimens.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: AppDimens.maxContentWidth),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icon header
                  Icon(
                    Icons.settings_suggest_rounded,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ).animate().scale(delay: 100.ms, duration: 400.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: AppDimens.md),
                  
                  Text(
                    'Let\'s Personalize Your App',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.onSurfaceDark : theme.colorScheme.onSurface,
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: AppDimens.xs),
                  
                  Text(
                    'Set your preferences to get started with Expense Partner',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: AppDimens.xl),

                  // Glassmorphic setup card
                  GlassCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // User Name input field
                          TextFormField(
                            controller: _nameController,
                            keyboardType: TextInputType.name,
                            textCapitalization: TextCapitalization.words,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Your Name',
                              prefixIcon: const Icon(Icons.person_outline_rounded),
                              filled: true,
                              fillColor: theme.colorScheme.surface.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Please enter your name';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppDimens.lg),

                          // Currency selector dropdown
                          DropdownButtonFormField<String>(
                            value: _selectedCurrencyCode,
                            decoration: InputDecoration(
                              labelText: 'Preferred Currency',
                              prefixIcon: const Icon(Icons.payments_outlined),
                              filled: true,
                              fillColor: theme.colorScheme.surface.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                              ),
                            ),
                            items: _currencies.map((c) {
                              return DropdownMenuItem<String>(
                                value: c['code'],
                                child: Text(c['name']!),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                final selected = _currencies.firstWhere((c) => c['code'] == value);
                                setState(() {
                                  _selectedCurrencyCode = value;
                                  _selectedCurrencySymbol = selected['symbol']!;
                                });
                              }
                            },
                          ),
                          const SizedBox(height: AppDimens.xl),

                          // Finish setup button
                          ElevatedButton(
                            onPressed: _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                              ),
                            ),
                            child: const Text('Complete Setup & Start'),
                          ),
                        ],
                      ),
                    ),
                  ).animate().slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOutCubic).fadeIn(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
