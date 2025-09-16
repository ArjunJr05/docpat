import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class AuthProvider extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  User? _user;
  bool _isLoading = true;
  String? _error;
  StreamSubscription<User?>? _authSubscription;
  bool _isInitialized = false;
  
  String? get userId => _user?.uid;
  User? get user => _user;
  bool get isAuthenticated => _user != null;
  bool get isLoading => _isLoading;
  String? get error => _error;

  AuthProvider() {
    // Defer initialization to avoid calling notifyListeners during build
    Future.microtask(() => _initializeAuth());
  }

  void _initializeAuth() async {
    // Get current user immediately
    _user = _auth.currentUser;
    
    // If user exists, we're not loading
    if (_user != null) {
      _isLoading = false;
      _isInitialized = true;
      // Save user to Firestore without blocking
      _saveUserToFirestore(_user!);
      // Notify listeners since we have initial state
      notifyListeners();
    }
    
    // Listen to auth state changes
    _authSubscription = _auth.authStateChanges().listen(
      (User? user) {
        // Only notify if this is not the initial state
        if (_isInitialized) {
          _updateAuthState(user);
        } else {
          // First time setup
          _user = user;
          _isLoading = false;
          _isInitialized = true;
          
          if (user != null) {
            _saveUserToFirestore(user);
          }
          
          // Notify listeners after the initial setup
          notifyListeners();
        }
      },
      onError: (error) {
        print('Auth stream error: $error');
        _error = error.toString();
        _isLoading = false;
        if (_isInitialized) {
          notifyListeners();
        }
      },
    );
  }

  void _updateAuthState(User? user) {
    bool shouldNotify = false;
    
    if (_user != user) {
      _user = user;
      shouldNotify = true;
    }
    
    if (_isLoading) {
      _isLoading = false;
      shouldNotify = true;
    }
    
    if (shouldNotify) {
      notifyListeners();
    }
    
    // Save user to Firestore in background
    if (user != null) {
      _saveUserToFirestore(user);
    }
  }

  Future<void> _saveUserToFirestore(User user) async {
    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      
      if (!userDoc.exists) {
        await _firestore.collection('users').doc(user.uid).set({
          'email': user.email,
          'displayName': user.displayName ?? '',
          'photoURL': user.photoURL ?? '',
          'uid': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
        print('User created in Firestore: ${user.email}');
      } else {
        await _firestore.collection('users').doc(user.uid).update({
          'lastLoginAt': FieldValue.serverTimestamp(),
        });
        print('User login updated in Firestore: ${user.email}');
      }
    } catch (e) {
      print('Firestore error: $e');
      // Don't rethrow to prevent breaking auth flow
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      print('Sign in successful: ${credential.user?.email}');
      // authStateChanges will handle the user state update
    } catch (e) {
      print('Sign in error: $e');
      _error = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> createUserWithEmailAndPassword(String email, String password) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      print('User creation successful: ${credential.user?.email}');
      // authStateChanges will handle the user state update
    } catch (e) {
      print('Create user error: $e');
      _error = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _auth.signOut();
      // authStateChanges will handle clearing the user
    } catch (e) {
      print('Sign out error: $e');
      _error = _getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
    }
  }

  String _getErrorMessage(dynamic error) {
    if (error is FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
          return 'No user found with this email.';
        case 'wrong-password':
          return 'Wrong password provided.';
        case 'email-already-in-use':
          return 'An account already exists with this email.';
        case 'weak-password':
          return 'The password provided is too weak.';
        case 'invalid-email':
          return 'The email address is not valid.';
        default:
          return error.message ?? 'An error occurred during authentication.';
      }
    }
    return error.toString();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}