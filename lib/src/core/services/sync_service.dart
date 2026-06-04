import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/isar_service.dart';
import '../../features/expenses/data/models/expense_model.dart';
import '../../features/categories/data/models/category_model.dart';
import '../../features/budgets/data/models/budget_model.dart';

/// Service managing offline-first data synchronization between local Isar DB and Cloud Firestore.
class SyncService {
  final Isar _isar;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription? _isarSubscription;
  StreamSubscription? _firestoreSubscription;
  StreamSubscription? _authSubscription;
  String? _currentUid;

  bool _isSyncingFromCloud = false;

  SyncService(this._isar);

  /// Initialize Firebase authentication and start bidirectional sync.
  Future<void> initializeSync() async {
    if (Firebase.apps.isEmpty) {
      debugPrint('SyncService: Firebase is not initialized. Running in offline-only mode.');
      return;
    }

    _authSubscription?.cancel();
    _authSubscription = _auth.authStateChanges().listen((user) async {
      if (user == null) {
        debugPrint('SyncService: Auth state changed: No user. Wiping local database and signing in anonymously...');
        _isarSubscription?.cancel();
        _firestoreSubscription?.cancel();
        await clearLocalData();
        _currentUid = null;

        try {
          await _auth.signInAnonymously();
        } catch (e) {
          debugPrint('SyncService: Anonymous sign-in failed: $e');
        }
        return;
      }

      final uid = user.uid;
      if (uid == _currentUid) return;

      debugPrint('SyncService: Active user switched to: $uid (Anonymous: ${user.isAnonymous})');

      // 1. Cancel previous watchers
      _isarSubscription?.cancel();
      _firestoreSubscription?.cancel();

      // 2. If transitioning to a new real email account, merge/push local data to cloud first
      if (!user.isAnonymous) {
        await _mergeLocalDataToCloud(uid);
      }

      // 3. Update current active UID
      _currentUid = uid;

      // 4. Pull down cloud data for this user
      await syncFromCloud(uid);

      // 5. Start watchers
      _listenToCloudChanges(uid);
      _listenToLocalChanges(uid);
    });
  }

  /// Push all local records to the new user's Firestore path.
  Future<void> _mergeLocalDataToCloud(String uid) async {
    try {
      final localExpenses = await _isar.expenseModels.where().findAll();
      if (localExpenses.isEmpty) return;

      debugPrint('SyncService: Merging ${localExpenses.length} local expenses to cloud user $uid');
      final batch = _firestore.batch();
      final expenseCollection =
          _firestore.collection('users').doc(uid).collection('expenses');

      for (final expense in localExpenses) {
        final docRef = expenseCollection.doc(expense.uuid);
        batch.set(docRef, expense.toMap());
      }
      await batch.commit();
      debugPrint('SyncService: Local data merge complete.');
    } catch (e) {
      debugPrint('SyncService: Failed to merge local data to cloud: $e');
    }
  }

  /// Wipe the local Isar database.
  Future<void> clearLocalData() async {
    try {
      await _isar.writeTxn(() async {
        await _isar.expenseModels.clear();
        await _isar.categoryModels.clear();
        await _isar.budgetModels.clear();
      });
      debugPrint('SyncService: Local Isar database wiped successfully.');
    } catch (e) {
      debugPrint('SyncService: Error wiping local database: $e');
    }
  }

  /// Query all remote transactions and sync them to local Isar database.
  Future<void> syncFromCloud(String uid) async {
    if (_isSyncingFromCloud) return;
    _isSyncingFromCloud = true;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('expenses')
          .get();

      final remoteDocs = snapshot.docs;

      await _isar.writeTxn(() async {
        for (final doc in remoteDocs) {
          final data = doc.data();
          final uuid = data['uuid'] as String;

          // Check if local transaction exists by UUID
          final localModel = await _isar.expenseModels
              .filter()
              .uuidEqualTo(uuid)
              .findFirst();

          final remoteModel = ExpenseModel.fromMap(data);

          if (localModel == null) {
            // New remote item, save locally
            await _isar.expenseModels.put(remoteModel);
          } else {
            // Compare modified timestamps
            if (remoteModel.updatedAt.isAfter(localModel.updatedAt)) {
              // Remote is newer, update local copy
              remoteModel.id = localModel.id; // Retain local Isar ID
              await _isar.expenseModels.put(remoteModel);
            }
          }
        }
      });
    } catch (e) {
      debugPrint('SyncService: syncFromCloud failed: $e');
    } finally {
      _isSyncingFromCloud = false;
    }
  }

  /// Listen to realtime changes in Cloud Firestore.
  void _listenToCloudChanges(String uid) {
    _firestoreSubscription?.cancel();
    _firestoreSubscription = _firestore
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .snapshots()
        .listen((snapshot) async {
      if (_isSyncingFromCloud) return;
      _isSyncingFromCloud = true;

      try {
        await _isar.writeTxn(() async {
          for (final change in snapshot.docChanges) {
            final data = change.doc.data();
            if (data == null) continue;
            final uuid = data['uuid'] as String;
            final remoteModel = ExpenseModel.fromMap(data);

            final localModel = await _isar.expenseModels
                .filter()
                .uuidEqualTo(uuid)
                .findFirst();

            if (change.type == DocumentChangeType.removed) {
              if (localModel != null) {
                await _isar.expenseModels.delete(localModel.id);
              }
            } else {
              if (localModel == null) {
                await _isar.expenseModels.put(remoteModel);
              } else if (remoteModel.updatedAt.isAfter(localModel.updatedAt)) {
                remoteModel.id = localModel.id;
                await _isar.expenseModels.put(remoteModel);
              }
            }
          }
        });
      } catch (e) {
        debugPrint('SyncService: Error processing cloud changes: $e');
      } finally {
        _isSyncingFromCloud = false;
      }
    });
  }

  /// Listen to local Isar changes and sync them to Firestore.
  void _listenToLocalChanges(String uid) {
    _isarSubscription?.cancel();
    _isarSubscription = _isar.expenseModels.watchLazy().listen((_) async {
      if (_isSyncingFromCloud) return; // Avoid infinite loops

      try {
        // Find all local transactions
        final localExpenses = await _isar.expenseModels.where().findAll();

        final batch = _firestore.batch();
        final expenseCollection =
            _firestore.collection('users').doc(uid).collection('expenses');

        // Stage all local records to be uploaded/updated
        for (final expense in localExpenses) {
          final docRef = expenseCollection.doc(expense.uuid);
          batch.set(docRef, expense.toMap());
        }

        // Delete check: if a transaction was deleted locally, delete it from the cloud
        final remoteSnapshot = await expenseCollection.get();
        final localUuids = localExpenses.map((e) => e.uuid).toSet();

        for (final doc in remoteSnapshot.docs) {
          if (!localUuids.contains(doc.id)) {
            batch.delete(doc.reference);
          }
        }

        await batch.commit();
      } catch (e) {
        debugPrint('SyncService: Error syncing local changes to Cloud: $e');
      }
    });
  }

  /// Dispose listeners.
  void dispose() {
    _isarSubscription?.cancel();
    _firestoreSubscription?.cancel();
    _authSubscription?.cancel();
  }
}

/// Provider for SyncService
final syncServiceProvider = Provider<SyncService>((ref) {
  final isar = ref.watch(isarProvider);
  final syncService = SyncService(isar);

  // Start synchronization
  syncService.initializeSync();

  ref.onDispose(() => syncService.dispose());
  return syncService;
});
