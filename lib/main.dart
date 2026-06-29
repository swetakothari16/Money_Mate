import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'src/app.dart';
import 'src/core/database/isar_service.dart';
import 'src/core/providers/preferences_provider.dart';
import 'src/core/utils/formatters.dart';
import 'src/features/expenses/data/models/expense_model.dart';
import 'src/features/categories/data/models/category_model.dart';
import 'src/features/budgets/data/models/budget_model.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with fallback for offline mode if configs are missing
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase initialization skipped/failed: $e');
  }

  // Initialize databases and preferences
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(
    [ExpenseModelSchema, CategoryModelSchema, BudgetModelSchema],
    directory: dir.path,
    name: 'expense_partner_db',
  );
  
  final prefs = await SharedPreferences.getInstance();

  // Auto-login anonymously on first run if no user is currently authenticated
  final auth = FirebaseAuth.instance;
  if (auth.currentUser == null) {
    try {
      await auth.signInAnonymously();
      debugPrint('Automatically signed in anonymously.');
    } catch (e) {
      debugPrint('Automatic anonymous sign-in failed: $e');
    }
  }

  // Initialize CurrencyFormatter with saved symbol on startup
  final currentUser = auth.currentUser;
  final savedSymbol = currentUser != null
      ? (prefs.getString('userCurrencySymbol_${currentUser.uid}') ?? '₹')
      : (prefs.getString('userCurrencySymbol') ?? '₹');
  CurrencyFormatter.updateCurrencySymbol(savedSymbol);

  runApp(
    ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(isar),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const ExpensePartnerApp(),
    ),
  );
}

// Minor change for GitHub push
