import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/shared/providers.dart';

final presenceServiceProvider = Provider((ref) => PresenceService(ref));

class PresenceService with WidgetsBindingObserver {
  final Ref _ref;
  bool _isInitialized = false;

  PresenceService(this._ref);

  void init() {
    if (_isInitialized) return;
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
    _updateStatus(true);
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _updateStatus(false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateStatus(true);
    } else {
      _updateStatus(false);
    }
  }

  Future<void> _updateStatus(bool isOnline) async {
    final user = _ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    try {
      await _ref.read(firestoreProvider).collection('users').doc(user.uid).update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error updating presence: $e');
    }
  }
}
