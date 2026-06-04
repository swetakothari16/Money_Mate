import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/formatters.dart';

/// Synchronously injected via ProviderScope in main.dart
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in ProviderScope');
});

class OnboardingNotifier extends Notifier<bool> {
  static const _key = 'hasCompletedOnboarding';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return prefs.getBool(_key) ?? false;
  }

  Future<void> completeOnboarding() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool(_key, true);
    state = true;
  }
}

final onboardingProvider = NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);

/// Provider to manage the user's name
class UserNameNotifier extends StateNotifier<String?> {
  final SharedPreferences _prefs;
  static const _key = 'userName';

  UserNameNotifier(this._prefs) : super(_prefs.getString(_key));

  Future<void> setUserName(String name) async {
    await _prefs.setString(_key, name);
    state = name;
  }
}

final userNameProvider = StateNotifierProvider<UserNameNotifier, String?>((ref) {
  return UserNameNotifier(ref.watch(sharedPreferencesProvider));
});

/// Provider to manage the selected currency code (e.g. USD, INR)
class CurrencyCodeNotifier extends StateNotifier<String> {
  final SharedPreferences _prefs;
  static const _key = 'userCurrencyCode';

  CurrencyCodeNotifier(this._prefs) : super(_prefs.getString(_key) ?? 'INR');

  Future<void> setCurrencyCode(String code) async {
    await _prefs.setString(_key, code);
    state = code;
  }
}

final currencyCodeProvider = StateNotifierProvider<CurrencyCodeNotifier, String>((ref) {
  return CurrencyCodeNotifier(ref.watch(sharedPreferencesProvider));
});

/// Provider to manage the selected currency symbol (e.g. $, ₹)
class CurrencySymbolNotifier extends StateNotifier<String> {
  final SharedPreferences _prefs;
  static const _key = 'userCurrencySymbol';

  CurrencySymbolNotifier(this._prefs) : super(_prefs.getString(_key) ?? '₹');

  Future<void> setCurrencySymbol(String symbol) async {
    await _prefs.setString(_key, symbol);
    CurrencyFormatter.updateCurrencySymbol(symbol);
    state = symbol;
  }
}

final currencySymbolProvider = StateNotifierProvider<CurrencySymbolNotifier, String>((ref) {
  return CurrencySymbolNotifier(ref.watch(sharedPreferencesProvider));
});
