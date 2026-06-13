import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimens.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../providers/auth_providers.dart';
import '../../../../core/providers/preferences_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final authRepo = ref.read(authRepositoryProvider);

    try {
      if (_isSignUp) {
        await authRepo.signUpWithEmail(
          _emailController.text,
          _passwordController.text,
        );
      } else {
        final credential = await authRepo.signInWithEmail(
          _emailController.text,
          _passwordController.text,
        );

        // Fetch and restore user profile from Firestore if it exists
        final uid = credential.user?.uid;
        if (uid != null) {
          try {
            final doc = await FirebaseFirestore.instance
                .collection('users')
                .doc(uid)
                .get()
                .timeout(const Duration(seconds: 4));
            if (doc.exists) {
              final data = doc.data();
              if (data != null) {
                final name = data['name'] as String?;
                final currencyCode = data['currencyCode'] as String?;
                final currencySymbol = data['currencySymbol'] as String?;
                final hasCompleted = data['hasCompletedOnboarding'] as bool? ?? false;

                final prefs = ref.read(sharedPreferencesProvider);
                if (name != null) {
                  await prefs.setString('userName_$uid', name);
                  ref.read(userNameProvider.notifier).updateState(name);
                }
                if (currencyCode != null) {
                  await prefs.setString('userCurrencyCode_$uid', currencyCode);
                  ref.read(currencyCodeProvider.notifier).updateState(currencyCode);
                }
                if (currencySymbol != null) {
                  await prefs.setString('userCurrencySymbol_$uid', currencySymbol);
                  ref.read(currencySymbolProvider.notifier).updateState(currencySymbol);
                }
                if (hasCompleted) {
                  await prefs.setBool('hasCompletedOnboarding_$uid', true);
                  ref.read(onboardingProvider.notifier).updateState(true);
                }
              }
            }
          } catch (e) {
            debugPrint('Error restoring user profile from Firestore on login: $e');
          }
        }
      }
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      setState(() {
        _errorMessage = _cleanFirebaseError(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _continueAsGuest() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authRepositoryProvider).signInAnonymously();
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      setState(() {
        _errorMessage = _cleanFirebaseError(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _cleanFirebaseError(String rawError) {
    if (rawError.contains('email-already-in-use')) {
      return 'This email address is already in use.';
    } else if (rawError.contains('wrong-password') || rawError.contains('user-not-found') || rawError.contains('invalid-credential')) {
      return 'Invalid email or password.';
    } else if (rawError.contains('invalid-email')) {
      return 'Please enter a valid email address.';
    } else if (rawError.contains('weak-password')) {
      return 'The password must be at least 6 characters.';
    } else if (rawError.contains('network-request-failed')) {
      return 'Network connection error. Please check your internet connection.';
    }
    return 'An unexpected error occurred. Please try again.';
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
                  // ─── Header Logo & Text ─────────────────────────────────────
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ).animate().scale(delay: 100.ms, duration: 400.ms, curve: Curves.easeOutBack),
                  const SizedBox(height: AppDimens.md),
                  Text(
                    'Expense Partner',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.onSurfaceDark : theme.colorScheme.onSurface,
                    ),
                  ).animate().fadeIn(delay: 200.ms),
                  const SizedBox(height: AppDimens.xs),
                  Text(
                    _isSignUp ? 'Create an account to backup your data' : 'Log in to sync your expenses across devices',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ).animate().fadeIn(delay: 300.ms),
                  const SizedBox(height: AppDimens.xl),

                  // ─── Glassmorphic Card Form ────────────────────────────────
                  GlassCard(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(AppDimens.sm),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.errorContainer.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(AppDimens.radiusSm),
                                border: Border.all(color: theme.colorScheme.error.withOpacity(0.3)),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            const SizedBox(height: AppDimens.md),
                          ],

                          // Email Input
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'Email Address',
                              prefixIcon: const Icon(Icons.email_outlined),
                              filled: true,
                              fillColor: theme.colorScheme.surface.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your email';
                              }
                              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                                return 'Please enter a valid email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppDimens.md),

                          // Password Input
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline_rounded),
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                                onPressed: () {
                                  setState(() {
                                    _obscurePassword = !_obscurePassword;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: theme.colorScheme.surface.withOpacity(0.05),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppDimens.lg),

                          // Submit Button
                          ElevatedButton(
                            onPressed: _isLoading ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: theme.colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : Text(_isSignUp ? 'Create Account' : 'Log In'),
                          ),

                          const SizedBox(height: AppDimens.md),

                          // Switch Auth Mode
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    setState(() {
                                      _isSignUp = !_isSignUp;
                                      _errorMessage = null;
                                    });
                                  },
                            child: Text(
                              _isSignUp ? 'Already have an account? Log In' : 'New here? Create an account',
                              style: TextStyle(color: theme.colorScheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate().slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOutCubic).fadeIn(),

                  const SizedBox(height: AppDimens.lg),

                  // ─── Divider ───────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(child: Divider(color: theme.colorScheme.onSurface.withOpacity(0.1))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AppDimens.md),
                        child: Text(
                          'OR',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                          ),
                        ),
                      ),
                      Expanded(child: Divider(color: theme.colorScheme.onSurface.withOpacity(0.1))),
                    ],
                  ).animate().fadeIn(delay: 400.ms),

                  const SizedBox(height: AppDimens.lg),

                  // ─── Continue as Guest Button ──────────────────────────────
                  OutlinedButton(
                    onPressed: _isLoading ? null : _continueAsGuest,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: theme.colorScheme.onSurface.withOpacity(0.15)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppDimens.radiusMd),
                      ),
                    ),
                    child: Text(
                      'Continue as Guest (Offline Mode)',
                      style: TextStyle(color: theme.colorScheme.onSurface),
                    ),
                  ).animate().fadeIn(delay: 500.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
