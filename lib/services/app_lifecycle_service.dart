import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unihub_mobile/core/utils/app_logger.dart';
import '../features/auth/presentation/controllers/auth_controller.dart';
import '../features/auth/shared/providers.dart';

/// Provides the current application lifecycle state.
/// Centralizes lifecycle tracking to prevent redundant WidgetsBindingObservers.
final appLifecycleStateProvider = StateProvider<AppLifecycleState>((ref) => AppLifecycleState.resumed);

final appLifecycleServiceProvider = Provider((ref) {
  final service = AppLifecycleService(ref);
  return service;
});

class AppLifecycleService with WidgetsBindingObserver {
  final Ref _ref;
  bool _isInitialized = false;

  AppLifecycleService(this._ref);

  void init() {
    if (_isInitialized) return;
    WidgetsBinding.instance.addObserver(this);
    _isInitialized = true;
    AppLogger.info('🚀 AppLifecycleService Initialized', 'LIFECYCLE');
  }

  void dispose() {
    if (!_isInitialized) return;
    WidgetsBinding.instance.removeObserver(this);
    _isInitialized = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Audit Note: Opening the notification shade triggers 'inactive'. 
    // We only want to notify the rest of the app if there's a significant change
    // to avoid UI flickers and redundant refreshes.
    final previousState = _ref.read(appLifecycleStateProvider);
    if (previousState == state) return;

    // Update the global provider
    _ref.read(appLifecycleStateProvider.notifier).state = state;
    
    AppLogger.info('📱 App Lifecycle State: ${state.name.toUpperCase()}', 'LIFECYCLE');
    
    switch (state) {
      case AppLifecycleState.resumed:
        if (previousState == AppLifecycleState.inactive) {
          // Returning from notification shade/overlay. Usually no refresh needed.
          AppLogger.info('App Resumed from Inactive (Overlay closed)', 'LIFECYCLE');
        } else {
          _handleResumed();
        }
        break;
      case AppLifecycleState.paused:
        _handlePaused();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _handleResumed() {
    // Perform any necessary refresh logic when app returns to foreground
    
    // Automatic Email Verification Detection (Phase 2.2)
    final user = _ref.read(firebaseAuthProvider).currentUser;
    if (user != null && !user.emailVerified) {
      AppLogger.info('App Resumed: Checking verification status...', 'AUTH');
      _ref.read(authControllerProvider.notifier).checkVerificationStatus();
    }
  }

  void _handlePaused() {
    // Perform any necessary cleanup when app goes to background
  }
}
