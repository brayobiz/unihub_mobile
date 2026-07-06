import 'package:flutter/foundation.dart';
import 'dart:developer' as developer;
import 'package:firebase_crashlytics/firebase_crashlytics.dart';

class AppLogger {
  static void info(String message, [String? tag]) {
    _log(message, name: tag ?? 'INFO', level: 0);
  }

  static void warning(String message, [String? tag]) {
    _log(message, name: tag ?? 'WARNING', level: 900); // 900 is warning level
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace, String? tag]) {
    _log(
      message, 
      name: tag ?? 'ERROR', 
      level: 1000, // 1000 is error level
      error: error,
      stackTrace: stackTrace,
    );
    
    // In production, we send to a crash reporting service
    if (kReleaseMode) {
      FirebaseCrashlytics.instance.recordError(error, stackTrace, reason: message);
    }
  }

  static void notification(String message, {bool isError = false}) {
    final prefix = isError ? '🔔❌' : '🔔✅';
    _log('$prefix $message', name: 'NOTIFICATION');
  }

  static void _log(String message, {String name = '', int level = 0, dynamic error, StackTrace? stackTrace}) {
    if (kDebugMode) {
      // Use developer.log for better integration with IDE logging consoles
      developer.log(
        message,
        name: name,
        level: level,
        error: error,
        stackTrace: stackTrace,
        time: DateTime.now(),
      );
    } else if (level >= 900) {
      // In production, we only print warnings and errors to console if necessary (though usually disabled)
      // Actually, we should use a proper logging framework for production.
      debugPrint('[$name] $message');
      if (error != null) debugPrint('Error: $error');
    }
  }
}
