import 'package:flutter/foundation.dart';

/// Environment configuration for the app.
/// Use --dart-define or --dart-define-from-file to set these values.
class EnvConfig {
  /// Dify AI API Key
  static const String difyApiKey = String.fromEnvironment(
    'DIFY_API_KEY',
    defaultValue: 'app-xXRlCxQxyZzkgRlj8x6Oi9cN', // Fallback for development
  );

  /// Whether to use mock AI responses
  static const bool useMockAi = bool.fromEnvironment(
    'USE_MOCK_AI',
    defaultValue: false,
  );

  /// AdMob Application ID (Placeholder for now)
  static const String admobAppId = String.fromEnvironment(
    'ADMOB_APP_ID',
    defaultValue: 'ca-app-pub-3940256099942544~3347511713', // Test ID
  );

  /// Is production environment
  static bool get isProduction => kReleaseMode;
}
