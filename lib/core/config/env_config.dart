import 'package:flutter/foundation.dart';

/// Environment configuration for the app.
/// Use --dart-define or --dart-define-from-file to set these values.
class EnvConfig {
  /// Gemini AI API Key (from Google AI Studio)
  /// To provide this, use: --dart-define=AI_API_KEY=your_key_here
  static const String aiApiKey = String.fromEnvironment(
    'AI_API_KEY',
    defaultValue: '',
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
