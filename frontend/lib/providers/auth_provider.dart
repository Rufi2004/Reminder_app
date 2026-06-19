import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firebase_service.dart';

class AuthProvider extends ChangeNotifier {
  final FirebaseService _firebase = FirebaseService();

  bool _initialized = false;
  bool get initialized => _initialized;

  // Reads directly from Firebase — always reflects the persisted session
  bool get isLoggedIn => _firebase.currentUser != null;

  // Returns the current user's email for display in UI
  String? get currentUserEmail => _firebase.currentUser?.email;

  Future<void> init() async {
    // init() sets up FirebaseAuth and FirebaseFirestore instances.
    // Firebase Auth automatically persists the session to disk on Android,
    // so currentUser is non-null on restart if the user was previously logged in.
    await _firebase.init();

    // Listen to auth state changes so any part of the UI that watches
    // AuthProvider rebuilds when the user signs in or out.
    FirebaseAuth.instance.authStateChanges().listen((_) {
      notifyListeners();
    });

    _initialized = true;
    notifyListeners();
  }

  Future<void> signIn(String email, String password) async {
    try {
      await _firebase.signInWithEmail(email, password);
      notifyListeners();
    } on Exception {
      rethrow;
    }
  }

  Future<void> register(String email, String password) async {
    try {
      await _firebase.registerWithEmail(email, password);
      notifyListeners();
    } on Exception {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _firebase.signOut();
    notifyListeners();
  }
}