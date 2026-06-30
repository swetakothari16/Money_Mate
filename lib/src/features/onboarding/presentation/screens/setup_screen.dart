import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../core/providers/preferences_provider.dart';
import '../../../budgets/providers/budget_providers.dart';
import '../../../budgets/data/models/budget_model.dart';
import '../../../../shared/widgets/glass_card.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // State for Step 1
  final _nameController = TextEditingController();
  
  // State for Step 2
  String _selectedCurrencyCode = 'INR';
  String _selectedCurrencySymbol = '₹';
  final List<Map<String, String>> _currencies = [
    {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee'},
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
    {'code': 'AED', 'symbol': 'د.إ', 'name': 'UAE Dirham'},
    {'code': 'SGD', 'symbol': '\$', 'name': 'Singapore Dollar'},
    {'code': 'CAD', 'symbol': '\$', 'name': 'Canadian Dollar'},
    {'code': 'AUD', 'symbol': '\$', 'name': 'Australian Dollar'},
  ];

  // State for Step 3
  final _budgetController = TextEditingController(text: '25000');
  bool _isSaving = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage == 0 && _nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }
    
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }
  
  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Future<void> _submit() async {
    if (_nameController.text.trim().isEmpty) return;
    
    final budgetLimit = double.tryParse(_budgetController.text.replaceAll(',', '')) ?? 0.0;
    if (budgetLimit <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid budget limit')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final userNameNotifier = ref.read(userNameProvider.notifier);
      final currencyCodeNotifier = ref.read(currencyCodeProvider.notifier);
      final currencySymbolNotifier = ref.read(currencySymbolProvider.notifier);
      final onboardingNotifier = ref.read(onboardingProvider.notifier);

      // Save configurations
      await userNameNotifier.setUserName(_nameController.text.trim());
      await currencyCodeNotifier.setCurrencyCode(_selectedCurrencyCode);
      await currencySymbolNotifier.setCurrencySymbol(_selectedCurrencySymbol);
      
      // Calculate start/end dates for a monthly budget
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, 1);
      final end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      // Create Overall Monthly Budget
      await ref.read(budgetListProvider.notifier).addBudget(
        name: 'Overall Monthly Budget',
        limitAmount: budgetLimit,
        period: BudgetPeriod.monthly,
        category: null,
        startDate: start,
        endDate: end,
      );
      
      // Complete onboarding
      await onboardingNotifier.completeOnboarding();

      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving setup: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : theme.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            // AppBar replacement
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                      onPressed: _prevPage,
                    )
                  else
                    const SizedBox(width: 48), // Placeholder
                  Expanded(
                    child: Text(
                      _currentPage == 0 
                        ? 'Personalization' 
                        : _currentPage == 1 
                          ? 'Currency' 
                          : 'Budget Setup',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 48), // Placeholder
                ],
              ),
            ),
            
            // Progress indicators
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
              child: Row(
                children: List.generate(3, (index) {
                  return Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4.0),
                      height: 4,
                      decoration: BoxDecoration(
                        color: index <= _currentPage ? primary : primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Disable swipe
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  _buildPersonalizeStep(theme, isDark),
                  _buildCurrencyStep(theme, isDark),
                  _buildBudgetStep(theme, isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalizeStep(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
            'Let\'s personalize your experience',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.onSurfaceDark : theme.colorScheme.onSurface,
            ),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 12),
          Text(
            'Start your financial journey with an identity that feels like you.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 48),
          
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: theme.colorScheme.surface.withOpacity(0.5),
                        child: Icon(
                          Icons.person_rounded,
                          size: 64,
                          color: theme.colorScheme.primary.withOpacity(0.5),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.income,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: theme.colorScheme.surface,
                            width: 2,
                          ),
                        ),
                        child: const Icon(
                          Icons.auto_awesome,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                Text(
                  'What should we call you?',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _nameController,
                  keyboardType: TextInputType.name,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    hintText: 'Rahul',
                    prefixIcon: const Icon(Icons.person_outline_rounded),
                    filled: true,
                    fillColor: theme.colorScheme.surface.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline_rounded, 
                        size: 20, 
                        color: theme.colorScheme.primary
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'We\'ll use your name to personalize your dashboard, notifications, and reports. This can be changed later in settings.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ).animate().slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOutCubic).fadeIn(),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
            ),
            child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrencyStep(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
            'Choose your preferred currency',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.onSurfaceDark : theme.colorScheme.onSurface,
            ),
          ).animate().fadeIn(delay: 100.ms),
          const SizedBox(height: 12),
          Text(
            'All your expenses, budgets, and savings goals will be calculated in this currency. You can change this later.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 32),
          
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: _currencies.length,
              itemBuilder: (context, index) {
                final c = _currencies[index];
                final isSelected = _selectedCurrencyCode == c['code'];
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCurrencyCode = c['code']!;
                      _selectedCurrencySymbol = c['symbol']!;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isSelected 
                        ? theme.colorScheme.primary.withOpacity(0.15) 
                        : isDark ? AppColors.surfaceDark : theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(AppDimens.radiusLg),
                      border: Border.all(
                        color: isSelected 
                          ? theme.colorScheme.primary 
                          : isDark ? Colors.white10 : Colors.black12,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected ? [] : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 16,
                              backgroundColor: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                              child: Text(
                                c['code']!.substring(0, 2),
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Text(
                                  c['symbol']!,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? theme.colorScheme.primary : null,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  c['code']!,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? theme.colorScheme.primary : null,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              c['name']!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                        if (isSelected)
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Icon(
                              Icons.check_circle_rounded,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ).animate().slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOutCubic).fadeIn(),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _nextPage,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
            ),
            child: const Text('Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetStep(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Piggy Bank Placeholder
          Center(
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.savings_rounded,
                      size: 80,
                      color: AppColors.income,
                    ),
                  ),
                ),
                Positioned(
                  top: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                        )
                      ],
                    ),
                    child: const Icon(Icons.add, size: 16, color: Colors.black54),
                  ),
                ),
              ],
            ),
          ).animate().scale(delay: 100.ms, duration: 400.ms, curve: Curves.easeOutBack),
          
          const SizedBox(height: 24),
          Text(
            'Set your monthly budget',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? AppColors.onSurfaceDark : theme.colorScheme.onSurface,
            ),
          ).animate().fadeIn(delay: 200.ms),
          const SizedBox(height: 12),
          Text(
            'Establishing a limit helps our AI provide better insights and spending alerts.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ).animate().fadeIn(delay: 300.ms),
          const SizedBox(height: 32),
          
          // Budget Input GlassCard
          GlassCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _selectedCurrencySymbol,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IntrinsicWidth(
                      child: TextFormField(
                        controller: _budgetController,
                        keyboardType: TextInputType.number,
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                        decoration: const InputDecoration(
                          hintText: '25000',
                          border: InputBorder.none,
                          filled: false,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ],
                ),
                Divider(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                  indent: 40,
                  endIndent: 40,
                  thickness: 2,
                ),
                const SizedBox(height: 4),
                Text(
                  'MAXIMUM MONTHLY SPENDING',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ).animate().slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOutCubic).fadeIn(),
          
          const SizedBox(height: 24),
          Text(
            'Quick Selection',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 12),
          
          // Chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildQuickChip('10,000', '10K', theme, isDark),
              _buildQuickChip('20,000', '20K', theme, isDark),
              _buildQuickChip('30,000', '30K', theme, isDark),
              _buildQuickChip('50,000', '50K', theme, isDark),
              _buildQuickChip('100,000', '1L', theme, isDark, fullWidth: true),
            ],
          ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isSaving ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
              ),
            ),
            child: _isSaving 
              ? const SizedBox(
                  width: 24, height: 24, 
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Start Tracking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_ios_rounded, size: 16),
                  ],
                ),
          ),
          const SizedBox(height: 12),
          Text(
            'By continuing, you agree to our Terms of Financial Service',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withOpacity(0.4),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQuickChip(String value, String label, ThemeData theme, bool isDark, {bool fullWidth = false}) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _budgetController.text = value.replaceAll(',', '');
        });
      },
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
          ),
        ),
        child: Text(
          '$_selectedCurrencySymbol$label',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ),
    );
  }
}
