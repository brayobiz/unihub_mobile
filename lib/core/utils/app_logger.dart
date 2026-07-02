import 'package:flutter/foundation.dart';

class AppLogger {
  static void info(String message, [String? tag]) {
    debugPrint('ℹ️ [${tag ?? 'INFO'}] $message');
  }

  static void warning(String message, [String? tag]) {
    debugPrint('⚠️ [${tag ?? 'WARNING'}] $message');
  }

  static void error(String message, [dynamic error, StackTrace? stackTrace, String? tag]) {
    debugPrint('❌ [${tag ?? 'ERROR'}] $message');
    if (error != null) debugPrint('   Error: $error');
    if (stackTrace != null) debugPrint('   StackTrace: $stackTrace');
  }

  static void notification(String message, {bool isError = false}) {
    final prefix = isError ? '🔔❌' : '🔔✅';
    debugPrint('$prefix [NOTIFICATION] $message');
  }
}
