import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/formatters.dart';
import '../../features/auth/providers/auth_providers.dart';

/// Synchronously injected via ProviderScope in main.dart
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('sharedPreferencesProvider must be overridden in ProviderScope');
});

class OnboardingNotifier extends Notifier<bool> {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final authState = ref.watch(authStateProvider);
    final uid = authState.value?.uid;
    if (uid == null) return false;
    return prefs.getBool('hasCompletedOnboarding_$uid') ?? false;
  }

  Future<void> completeOnboarding() async {
    final user = ref.read(authRepositoryProvider).currentUser;
    final uid = user?.uid;
    if (uid == null) return;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setBool('hasCompletedOnboarding_$uid', true);
    state = true;

    if (user != null && !user.isAnonymous) {
      FirebaseFirestore.instance.collection('users').doc(uid).set({
        'hasCompletedOnboarding': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((e) {
        debugPrint('Sync: Failed to sync onboarding completion to Firestore: $e');
      });
    }
  }

  void updateState(bool value) {
    state = value;
  }
}

final onboardingProvider = NotifierProvider<OnboardingNotifier, bool>(OnboardingNotifier.new);

/// Provider to manage the user's name
class UserNameNotifier extends Notifier<String?> {
  @override
  String? build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final authState = ref.watch(authStateProvider);
    final uid = authState.value?.uid;
    if (uid == null) return null;
    return prefs.getString('userName_$uid');
  }

  Future<void> setUserName(String name) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    final uid = user?.uid;
    if (uid == null) return;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('userName_$uid', name);
    state = name;

    if (user != null && !user.isAnonymous) {
      FirebaseFirestore.instance.collection('users').doc(uid).set({
        'name': name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((e) {
        debugPrint('Sync: Failed to sync user name to Firestore: $e');
      });
    }
  }

  void updateState(String? name) {
    state = name;
  }
}

final userNameProvider = NotifierProvider<UserNameNotifier, String?>(UserNameNotifier.new);

/// Provider to manage the selected currency code (e.g. USD, INR)
class CurrencyCodeNotifier extends Notifier<String> {
  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final authState = ref.watch(authStateProvider);
    final uid = authState.value?.uid;
    if (uid == null) return 'INR';
    return prefs.getString('userCurrencyCode_$uid') ?? 'INR';
  }

  Future<void> setCurrencyCode(String code) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    final uid = user?.uid;
    if (uid == null) return;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('userCurrencyCode_$uid', code);
    state = code;

    if (user != null && !user.isAnonymous) {
      FirebaseFirestore.instance.collection('users').doc(uid).set({
        'currencyCode': code,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((e) {
        debugPrint('Sync: Failed to sync currency code to Firestore: $e');
      });
    }
  }

  void updateState(String code) {
    state = code;
  }
}

final currencyCodeProvider = NotifierProvider<CurrencyCodeNotifier, String>(CurrencyCodeNotifier.new);

/// Provider to manage the selected currency symbol (e.g. $, ₹)
class CurrencySymbolNotifier extends Notifier<String> {
  @override
  String build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final authState = ref.watch(authStateProvider);
    final uid = authState.value?.uid;
    if (uid == null) return '₹';
    final symbol = prefs.getString('userCurrencySymbol_$uid') ?? '₹';
    // Side effect: update CurrencyFormatter
    CurrencyFormatter.updateCurrencySymbol(symbol);
    return symbol;
  }

  Future<void> setCurrencySymbol(String symbol) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    final uid = user?.uid;
    if (uid == null) return;
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('userCurrencySymbol_$uid', symbol);
    CurrencyFormatter.updateCurrencySymbol(symbol);
    state = symbol;

    if (user != null && !user.isAnonymous) {
      FirebaseFirestore.instance.collection('users').doc(uid).set({
        'currencySymbol': symbol,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)).catchError((e) {
        debugPrint('Sync: Failed to sync currency symbol to Firestore: $e');
      });
    }
  }

  void updateState(String symbol) {
    CurrencyFormatter.updateCurrencySymbol(symbol);
    state = symbol;
  }
}

final currencySymbolProvider = NotifierProvider<CurrencySymbolNotifier, String>(CurrencySymbolNotifier.new);

class DeletedSystemCategoriesNotifier extends Notifier<List<String>> {
  @override
  List<String> build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final authState = ref.watch(authStateProvider);
    final uid = authState.value?.uid ?? 'guest';
    return prefs.getStringList('deletedSystemCategories_$uid') ?? [];
  }

  Future<void> deleteSystemCategory(String name) async {
    final user = ref.read(authRepositoryProvider).currentUser;
    final uid = user?.uid ?? 'guest';
    final prefs = ref.read(sharedPreferencesProvider);
    final current = state;
    if (!current.contains(name)) {
      final updated = [...current, name];
      await prefs.setStringList('deletedSystemCategories_$uid', updated);
      state = updated;
    }
  }
}

final deletedSystemCategoriesProvider = NotifierProvider<DeletedSystemCategoriesNotifier, List<String>>(DeletedSystemCategoriesNotifier.new);

