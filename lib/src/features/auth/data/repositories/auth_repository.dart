import 'package:firebase_auth/firebase_auth.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Stream of active user authentication states
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Currently logged in Firebase User
  User? get currentUser => _auth.currentUser;

  /// Check if the current user session is anonymous
  bool get isAnonymous => _auth.currentUser?.isAnonymous ?? true;

  /// Log in using Email & Password
  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  /// Sign up / Register using Email & Password
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  /// Sign out from current session
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Sign in anonymously (Guest mode)
  Future<UserCredential> signInAnonymously() async {
    return await _auth.signInAnonymously();
  }
}
