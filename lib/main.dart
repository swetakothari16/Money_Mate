import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';

import 'src/app.dart';
import 'src/core/database/isar_service.dart';
import 'src/core/providers/preferences_provider.dart';
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
    name: 'money_mate_db',
  );
  
  final prefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(isar),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: const MoneyMateApp(),
    ),
  );
}
