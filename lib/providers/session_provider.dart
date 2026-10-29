import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// Holds the signed-in Firebase user and their live Firestore profile.
class SessionProvider extends ChangeNotifier {
  final AuthService auth = AuthService();
  final FirestoreService _fs = FirestoreService.instance;

  StreamSubscription<User?>? _authSub;
  StreamSubscription<AppUser?>? _userSub;

  User? firebaseUser;
  AppUser? appUser;
  bool initializing = true;
  bool profileLoading = false;

  /// Shown on the auth screen after a forced sign-out (e.g. suspension).
  String? signOutReason;

  SessionProvider() {
    _authSub = auth.authStateChanges().listen(_onAuth);
  }

  bool get emailVerified => firebaseUser?.emailVerified ?? false;

  void _onAuth(User? user) {
    firebaseUser = user;
    _userSub?.cancel();
    appUser = null;
    if (user == null) {
      initializing = false;
      profileLoading = false;
      notifyListeners();
      return;
    }
    profileLoading = true;
    notifyListeners();
    _userSub = _fs.userStream(user.uid).listen((u) {
      appUser = u;
      profileLoading = false;
      initializing = false;
      if (u != null && u.suspended) {
        signOutReason =
            'Your account has been suspended. Please contact support.';
        auth.signOut();
      }
      notifyListeners();
    }, onError: (Object e) {
      profileLoading = false;
      initializing = false;
      notifyListeners();
    });
  }

  Future<void> refreshEmailVerified() async {
    await auth.reloadAndCheckVerified();
    firebaseUser = auth.currentUser;
    notifyListeners();
  }

  Future<void> signOut() async {
    signOutReason = null;
    await auth.signOut();
  }

  void clearSignOutReason() {
    signOutReason = null;
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _userSub?.cancel();
    super.dispose();
  }
}
