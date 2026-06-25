import 'package:flutter/material.dart';

class AuthProvider extends ChangeNotifier {
  bool isLoading = false;

  Future<void> signInWithGoogle() async {
    isLoading = true;
    notifyListeners();

    try {
      // Firebase logic later
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {}

  Future<bool> isLoggedIn() async {
    return false;
  }
}