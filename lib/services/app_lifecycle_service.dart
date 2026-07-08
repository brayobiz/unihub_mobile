import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unihub_mobile/core/utils/app_logger.dart';

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
    AppLogger.info('AppLifecycleService Initialized', 'LIFECYCLE');
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    AppLogger.info('App Lifecycle State Changed: ${state.name}', 'LIFECYCLE');
    
    switch (state) {
      case AppLifecycleState.resumed:
        _handleResumed();
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
    // e.g. checking for forced updates, refreshing critical session data, etc.
  }

  void _handlePaused() {
    // Perform any necessary cleanup or save state logic when app goes to background
  }
}
