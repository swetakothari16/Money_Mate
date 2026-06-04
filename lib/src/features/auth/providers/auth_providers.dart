import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories/auth_repository.dart';

/// Provider for the Authentication Repository
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

/// Stream provider for user authentication state changes
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges;
});

/// Helper provider to track if the current user session is anonymous
final isAnonymousProvider = Provider<bool>((ref) {
  final user = ref.watch(authStateProvider).value;
  return user == null || user.isAnonymous;
});
