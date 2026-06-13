import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:expense_partner/src/core/providers/preferences_provider.dart';
import 'package:expense_partner/src/features/auth/providers/auth_providers.dart';
import 'package:expense_partner/src/features/auth/data/repositories/auth_repository.dart';
import 'package:expense_partner/src/features/auth/presentation/screens/login_screen.dart';
import 'package:expense_partner/src/features/expenses/providers/expense_providers.dart';
import 'package:expense_partner/src/features/expenses/presentation/screens/add_expense_screen.dart';
import 'package:expense_partner/src/features/expenses/data/models/expense_model.dart';
import 'package:expense_partner/src/features/categories/providers/category_providers.dart';
import 'package:expense_partner/src/features/categories/data/models/category_model.dart';
import 'package:expense_partner/src/features/categories/presentation/screens/categories_screen.dart';

// ─── Fakes for Authentication ───────────────────────────────────────────────

class FakeUser implements User {
  @override
  final String uid;
  @override
  final String? email;
  @override
  final bool isAnonymous;

  FakeUser({required this.uid, this.email, this.isAnonymous = false});

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeUserCredential implements UserCredential {
  @override
  final User? user;

  FakeUserCredential(this.user);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeAuthRepository implements AuthRepository {
  User? _currentUser;
  final _controller = StreamController<User?>.broadcast();
  
  bool signUpCalled = false;
  bool signInCalled = false;
  bool signInAnonymouslyCalled = false;
  String? lastEmail;
  String? lastPassword;

  FakeAuthRepository() {
    _currentUser = null;
  }

  @override
  User? get currentUser => _currentUser;

  @override
  Stream<User?> get authStateChanges => _controller.stream;

  @override
  bool get isAnonymous => _currentUser?.isAnonymous ?? true;

  @override
  Future<UserCredential> signInWithEmail(String email, String password) async {
    signInCalled = true;
    lastEmail = email;
    lastPassword = password;
    _currentUser = FakeUser(uid: 'fake_uid', email: email);
    _controller.add(_currentUser);
    return FakeUserCredential(_currentUser!);
  }

  @override
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    signUpCalled = true;
    lastEmail = email;
    lastPassword = password;
    _currentUser = FakeUser(uid: 'fake_uid', email: email);
    _controller.add(_currentUser);
    return FakeUserCredential(_currentUser!);
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }

  @override
  Future<UserCredential> signInAnonymously() async {
    signInAnonymouslyCalled = true;
    _currentUser = FakeUser(uid: 'fake_guest_uid', email: null, isAnonymous: true);
    _controller.add(_currentUser);
    return FakeUserCredential(_currentUser!);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// ─── Fakes for Data / Expenses ───────────────────────────────────────────────

class FakeExpenseListNotifier extends ExpenseListNotifier {
  final List<ExpenseModel> _expenses = [];
  bool addExpenseCalled = false;
  String? lastTitle;
  double? lastAmount;

  @override
  Future<List<ExpenseModel>> build() async {
    return _expenses;
  }

  @override
  Future<int> addExpense({
    required String title,
    required double amount,
    required DateTime date,
    required TransactionType type,
    required String category,
    String? note,
    PaymentMethod paymentMethod = PaymentMethod.cash,
    List<String> tags = const [],
    bool isRecurring = false,
    String? receiptPath,
  }) async {
    addExpenseCalled = true;
    lastTitle = title;
    lastAmount = amount;

    final expense = ExpenseModel()
      ..title = title
      ..amount = amount
      ..date = date
      ..type = type
      ..category = category
      ..note = note
      ..paymentMethod = paymentMethod
      ..tags = tags
      ..isRecurring = isRecurring
      ..receiptPath = receiptPath
      ..uuid = 'fake-uuid'
      ..createdAt = DateTime.now()
      ..updatedAt = DateTime.now();
      
    _expenses.add(expense);
    state = AsyncData(_expenses);
    return 1;
  }
}

class FakeCategoryListNotifier extends CategoryListNotifier {
  @override
  Future<List<CategoryModel>> build() async {
    return [];
  }
}

// ─── Widget Test Entry Point ────────────────────────────────────────────────

void main() {
  testWidgets('Email Signup Flow - Should call signUpWithEmail on AuthRepository', (WidgetTester tester) async {
    // Set screen size to avoid off-screen issues
    tester.view.physicalSize = const Size(500, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // 1. Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final fakeAuthRepo = FakeAuthRepository();

    // 2. Pump LoginScreen wrapped in ProviderScope overriding Auth and SharedPrefs
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Verify initial state
    expect(find.text('Log In'), findsWidgets);

    // Switch mode to Signup
    await tester.tap(find.text('New here? Create an account'));
    await tester.pumpAndSettle();

    // Verify text switched to Signup
    expect(find.text('Create Account'), findsWidgets);

    // Enter email and password
    await tester.enterText(find.byType(TextFormField).first, 'user@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    await tester.pump();

    // Tap Signup Button
    await tester.tap(find.text('Create Account').first);
    await tester.pump();

    // Verify FakeAuthRepository was triggered with input data
    expect(fakeAuthRepo.signUpCalled, isTrue);
    expect(fakeAuthRepo.lastEmail, equals('user@example.com'));
    expect(fakeAuthRepo.lastPassword, equals('password123'));
  });

  testWidgets('Email Login Flow - Should call signInWithEmail on AuthRepository', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fakeAuthRepo = FakeAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Verify in Log In mode initially
    expect(find.text('Log In'), findsWidgets);

    // Enter email and password
    await tester.enterText(find.byType(TextFormField).first, 'user@example.com');
    await tester.enterText(find.byType(TextFormField).last, 'password123');
    
    // Unfocus and settle
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    // Tap Log In button
    await tester.tap(find.text('Log In').first);
    await tester.pumpAndSettle();

    // Verify signInWithEmail was called
    expect(fakeAuthRepo.signInCalled, isTrue);
    expect(fakeAuthRepo.lastEmail, equals('user@example.com'));
    expect(fakeAuthRepo.lastPassword, equals('password123'));
  });

  testWidgets('Continue as Guest Flow - Should call signInAnonymously on AuthRepository', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fakeAuthRepo = FakeAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Tap Continue as Guest
    await tester.tap(find.text('Continue as Guest (Offline Mode)'));
    await tester.pumpAndSettle();

    // Verify signInAnonymously was called
    expect(fakeAuthRepo.signInAnonymouslyCalled, isTrue);
  });

  testWidgets('Auth Form Validation - Should show errors for invalid inputs', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fakeAuthRepo = FakeAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Tap Log In without typing anything
    await tester.tap(find.text('Log In').first);
    await tester.pumpAndSettle();

    // Should show validation errors and NOT call sign in
    expect(find.text('Please enter your email'), findsOneWidget);
    expect(find.text('Please enter your password'), findsOneWidget);
    expect(fakeAuthRepo.signInCalled, isFalse);

    // Type invalid email and too short password
    await tester.enterText(find.byType(TextFormField).first, 'bademail');
    await tester.enterText(find.byType(TextFormField).last, '123');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    // Tap Log In
    await tester.tap(find.text('Log In').first);
    await tester.pumpAndSettle();

    expect(find.text('Please enter a valid email address'), findsOneWidget);
    expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    expect(fakeAuthRepo.signInCalled, isFalse);
  });

  testWidgets('Add Expense Flow - Should call addExpense on ExpenseListNotifier', (WidgetTester tester) async {
    // Set screen size to avoid off-screen issues
    tester.view.physicalSize = const Size(500, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeExpenseNotifier = FakeExpenseListNotifier();

    // Pump AddExpenseScreen overriding the async notifier and the category provider synchronously
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseListProvider.overrideWith(() => fakeExpenseNotifier),
          allExpenseCategoriesProvider.overrideWithValue(
            const AsyncValue.data([
              CategoryItem(name: 'food', iconName: 'restaurant', colorIndex: 0),
            ]),
          ),
        ],
        child: const MaterialApp(
          home: AddExpenseScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title field is present
    expect(find.text('Add Transaction'), findsOneWidget);

    // Enter amount
    final amountField = find.byType(TextFormField).first;
    await tester.enterText(amountField, '250.00');

    // Enter title
    final titleField = find.byType(TextFormField).last;
    await tester.enterText(titleField, 'Dinner');
    
    // Unfocus to stop the blinking cursor animation
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    // Tap on category picker list tile
    await tester.tap(find.text('Select Category'));
    // Wait for the bottom sheet to open fully
    await tester.pumpAndSettle();

    // Tap the 'food' category item inside the picker sheet
    await tester.tap(find.text('food'));
    await tester.pumpAndSettle();

    // Tap Save button
    await tester.tap(find.text('Save Transaction'));
    await tester.pumpAndSettle();

    // Verify FakeExpenseListNotifier was triggered with correct parameters
    expect(fakeExpenseNotifier.addExpenseCalled, isTrue);
    expect(fakeExpenseNotifier.lastTitle, equals('Dinner'));
    expect(fakeExpenseNotifier.lastAmount, equals(250.00));
  });

  testWidgets('Add Expense Form Validation - Should require amount, title, and category', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final fakeExpenseNotifier = FakeExpenseListNotifier();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          expenseListProvider.overrideWith(() => fakeExpenseNotifier),
          allExpenseCategoriesProvider.overrideWithValue(
            const AsyncValue.data([
              CategoryItem(name: 'food', iconName: 'restaurant', colorIndex: 0),
            ]),
          ),
        ],
        child: const MaterialApp(
          home: AddExpenseScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Save directly
    await tester.tap(find.text('Save Transaction'));
    await tester.pumpAndSettle();

    // Should show validation errors for amount and title, and not call addExpense
    expect(find.text('Enter amount'), findsOneWidget);
    expect(find.text('Enter a title'), findsOneWidget);
    expect(fakeExpenseNotifier.addExpenseCalled, isFalse);

    // Enter invalid amount, title, but no category
    final amountField = find.byType(TextFormField).first;
    await tester.enterText(amountField, 'abc');
    final titleField = find.byType(TextFormField).last;
    await tester.enterText(titleField, 'Lunch');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Transaction'));
    await tester.pumpAndSettle();

    expect(find.text('Invalid amount'), findsOneWidget);
    expect(fakeExpenseNotifier.addExpenseCalled, isFalse);

    // Enter valid amount, but still no category selected
    await tester.enterText(amountField, '15.50');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save Transaction'));
    await tester.pumpAndSettle();

    // Snackbar should show 'Please select a category'
    expect(find.text('Please select a category'), findsOneWidget);
    expect(fakeExpenseNotifier.addExpenseCalled, isFalse);
  });

  testWidgets('Delete System Category - Should add to deletedSystemCategories', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(500, 1500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final fakeAuthRepo = FakeAuthRepository();
    // Pre-populate user
    await fakeAuthRepo.signInAnonymously();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(fakeAuthRepo),
          sharedPreferencesProvider.overrideWithValue(prefs),
          categoryListProvider.overrideWith(() => FakeCategoryListNotifier()),
        ],
        child: const MaterialApp(
          home: CategoriesScreen(),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify 'Food & Dining' (which is the label for food) is present
    expect(find.text('Food & Dining'), findsOneWidget);

    // Tap delete on Food & Dining
    // Food & Dining card is the first tile
    await tester.tap(find.byType(IconButton).first);
    await tester.pumpAndSettle();

    // Verify dialog is shown
    expect(find.text('Delete Category'), findsOneWidget);

    // Confirm delete
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    // Verify 'Food & Dining' is no longer present
    expect(find.text('Food & Dining'), findsNothing);
  });
}
