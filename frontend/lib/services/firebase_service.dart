import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../models/reminder.dart';

class FirebaseService {
  static final FirebaseService _instance = FirebaseService._internal();
  factory FirebaseService() => _instance;
  FirebaseService._internal();

  bool _initialized = false; // guard against double init

  FirebaseAuth? _auth;
  FirebaseFirestore? _fire;

  Future<void> init() async {
    if (_initialized) return; // ← skip if already done

    try {
      if (kIsWeb) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'AIzaSyCCqBpg77z5wgD3diJbMKX3rSeEXt0wTOA',
            authDomain: 'reminder-ad122.firebaseapp.com',
            projectId: 'reminder-ad122',
            storageBucket: 'reminder-ad122.appspot.com',
            messagingSenderId: '12752982245',
            appId: '1:12752982245:web:1a2b3c4d5e6f7g8h9i0j',
          ),
        );
      } else {
        await Firebase.initializeApp();
      }
    } on FirebaseException catch (e) {
      debugPrint('Firebase initialization failed: ${e.code} ${e.message}');
      rethrow;
    }

    _auth = FirebaseAuth.instance;
    _fire = FirebaseFirestore.instance;
    _initialized = true;
  }

  User? get currentUser => _auth?.currentUser;

  void _validateEmailAndPassword(String email, String password) {
    if (email.isEmpty ||
        !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      throw Exception('Enter a valid email address.');
    }
    if (password.length < 6) {
      throw Exception('Password must be at least 6 characters.');
    }
  }

  Future<UserCredential> signInWithEmail(
      String email, String password) async {
    _validateEmailAndPassword(email, password);
    try {
      return await _auth!
          .signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      final message = '${e.code}: ${e.message ?? 'Authentication failed.'}';
      debugPrint('Firebase sign in failed: $message');
      throw Exception(message);
    }
  }

  Future<UserCredential> registerWithEmail(
      String email, String password) async {
    _validateEmailAndPassword(email, password);
    try {
      final cred = await _auth!
          .createUserWithEmailAndPassword(email: email, password: password);
      final user = cred.user;
      if (user != null) {
        final bytes = utf8.encode(password);
        final digest = sha256.convert(bytes);
        final hash = digest.toString();
        await _fire!.collection('users').doc(user.uid).set({
          'email': email,
          'passwordHash': hash,
          'createdAt': DateTime.now().toIso8601String(),
        });
      }
      return cred;
    } on FirebaseAuthException catch (e) {
      final message =
          '${e.code}: ${e.message ?? 'Registration failed.'}';
      debugPrint('Firebase registration failed: $message');
      throw Exception(message);
    }
  }

  Future<void> signOut() => _auth!.signOut();

  Future<void> upsertReminder(Reminder r) async {
    final user = _auth?.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
          code: 'no-current-user',
          message: 'Must be signed in to save a reminder.');
    }
    await _fire!
        .collection('users')
        .doc(user.uid)
        .collection('reminders')
        .doc(r.id)
        .set(r.toFirestore());
  }

  Future<List<Reminder>> fetchAllReminders() async {
    final user = _auth?.currentUser;
    if (user == null) return [];
    final snap = await _fire!
        .collection('users')
        .doc(user.uid)
        .collection('reminders')
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      return Reminder.fromMap({
        ...data,
        'userId': data['userId'] as String? ?? user.uid,
      });
    }).toList();
  }

  Future<void> deleteReminder(String id) async {
    final user = _auth?.currentUser;
    if (user == null) return;
    await _fire!
        .collection('users')
        .doc(user.uid)
        .collection('reminders')
        .doc(id)
        .delete();
  }
}