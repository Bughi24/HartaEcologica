import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // 1. Înregistrare (Register)
  Future<User?> registerWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      return result.user;
    } catch (e) {
      debugPrint("Eroare la înregistrare: ${e.toString()}");
      return null;
    }
  }

  // 2. Autentificare (Login)
  Future<User?> loginWithEmail(String email, String password) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
          email: email, password: password);
      return result.user;
    } catch (e) {
      debugPrint("Eroare la login: ${e.toString()}");
      return null;
    }
  }

  // 3. Logout
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // 4. Verificare stare utilizator (E logat sau nu?)
  Stream<User?> get user {
    return _auth.authStateChanges();
  }
}