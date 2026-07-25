import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../features/auth/shared/providers.dart';
import 'app_lifecycle_service.dart';

final presenceServiceProvider = Provider((ref) {
  final service = PresenceService(ref);
  
  // Listen to lifecycle changes via central provider
  ref.listen(appLifecycleStateProvider, (previous, next) {
    service.handleLifecycleChange(next);
  });

  ref.onDispose(() => service.dispose());
  return service;
});

class PresenceService {
  final Ref _ref;
  bool _isInitialized = false;
  Timer? _offlineTimer;
  bool? _lastKnownStatus;
  DateTime? _lastUpdateTime;

  PresenceService(this._ref);

  void init() {
    if (_isInitialized) return;
    _isInitialized = true;
    _cancelOfflineTimer();
    _updateStatus(true);
  }

  void dispose() {
    if (!_isInitialized) return;
    _cancelOfflineTimer();
    _updateStatus(false);
    _isInitialized = false;
  }

  /// Handles lifecycle transitions propagated from [AppLifecycleService]
  void handleLifecycleChange(AppLifecycleState state) {
    if (!_isInitialized) return;

    // Audit Note: Transient states like 'inactive' (notification shade) 
    // are ignored to prevent UI reloads and unnecessary Firestore writes.
    switch (state) {
      case AppLifecycleState.resumed:
        _cancelOfflineTimer();
        _updateStatus(true);
        break;
      case AppLifecycleState.paused:
        // User backgrounded the app. We wait 2 minutes before marking offline
        // to handle brief interruptions (phone calls, switching apps) gracefully.
        _startOfflineTimer();
        break;
      case AppLifecycleState.inactive:
        // System overlays, notification shade. Ignore.
        break;
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // App is being closed or fully hidden.
        _cancelOfflineTimer();
        _updateStatus(false);
        break;
    }
  }

  void _startOfflineTimer() {
    _cancelOfflineTimer();
    _offlineTimer = Timer(const Duration(minutes: 2), () {
      _updateStatus(false);
    });
  }

  void _cancelOfflineTimer() {
    _offlineTimer?.cancel();
    _offlineTimer = null;
  }

  Future<void> _updateStatus(bool isOnline) async {
    final user = _ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final now = DateTime.now();
    
    // REDUNDANCY CHECK: Skip if status is same and not stale (5 min heartbeat)
    final bool isStatusSame = _lastKnownStatus == isOnline;
    final bool isStale = _lastUpdateTime == null || 
                         now.difference(_lastUpdateTime!) > const Duration(minutes: 5);

    if (isStatusSame && !isStale) return;

    try {
      final firestore = _ref.read(firestoreProvider);
      final docRef = firestore.collection('users').doc(user.uid);
      
      _lastKnownStatus = isOnline;
      _lastUpdateTime = now;

      // Use a fire-and-forget approach for presence to avoid blocking UI
      unawaited(docRef.update({
        'isOnline': isOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      }).catchError((e) {
        if (kDebugMode) debugPrint('Presence write failed: $e');
      }));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error updating presence: $e');
      }
    }
  }
}
