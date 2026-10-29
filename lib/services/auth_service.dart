import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_user.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  @override
  String toString() => message;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  Future<void> signUp({
    required String name,
    required String email,
    required String password,
    required String role,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
      final user = cred.user!;
      await user.updateDisplayName(name.trim());
      await _db.collection('users').doc(user.uid).set({
        'name': name.trim(),
        'email': email.trim().toLowerCase(),
        'role': role,
        'photo': '',
        'verificationStatus': VerificationStatus.none,
        'suspended': false,
        'isDemo': false,
        'matchingUnlocked': false,
        'freeListingsUsed': 0,
        'lifestyle': const Lifestyle().toMap(),
        'privacy': const PrivacySettings().toMap(),
        'savedRooms': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });
      try {
        await user.sendEmailVerification();
      } catch (_) {
        // Non-fatal: user can resend from the verify screen.
      }
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  Future<void> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
          email: email.trim(), password: password);
      final snap = await _db.collection('users').doc(cred.user!.uid).get();
      if (snap.data()?['suspended'] == true) {
        await _auth.signOut();
        throw AuthException(
            'Your account has been suspended. Please contact support.');
      }
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  Future<void> resendVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  /// Reloads the Firebase user and returns whether the email is verified.
  Future<bool> reloadAndCheckVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<void> signOut() => _auth.signOut();

  Future<void> reauthenticate(String password) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;
    try {
      await user.reauthenticateWithCredential(
          EmailAuthProvider.credential(email: user.email!, password: password));
    } on FirebaseAuthException catch (e) {
      throw AuthException(_message(e));
    }
  }

  /// Deletes the auth user. Throws [FirebaseAuthException] with code
  /// `requires-recent-login` so the UI can ask for the password again.
  Future<void> deleteAuthUser() async {
    await _auth.currentUser?.delete();
  }

  static String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'An account with this email already exists. Try logging in instead.';
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Incorrect email or password.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'Network error. Check your internet connection.';
      case 'requires-recent-login':
        return 'Please confirm your password to continue.';
      default:
        return e.message ?? 'Something went wrong (${e.code}).';
    }
  }
}
