import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/router/app_router.dart';
import 'app/theme/app_theme.dart';
import 'app/theme/theme_provider.dart';
import 'features/auth/shared/providers.dart';
import 'features/ads/providers/ad_provider.dart';
import 'core/services/ai_assistant_service.dart';
import 'core/config/env_config.dart';
import 'firebase_options.dart';

import 'services/notification_service.dart';
import 'services/presence_service.dart';
import 'services/connectivity_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:unihub_mobile/core/utils/app_logger.dart';
import 'dart:ui';
import 'services/app_lifecycle_service.dart';
import 'core/widgets/app_error_boundary.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  // Ensure the binding is initialized before anything else
  final binding = WidgetsFlutterBinding.ensureInitialized();
  
  // Show a basic splash immediately to prevent ANR during heavy init
  // (In a real app, the native splash handles this, but Flutter needs to start ASAP)
  
  ErrorWidget.builder = buildGlobalErrorWidget;

  try {
    // 1. Initialize core async dependencies with individual timeouts
    // This prevents one hanging service from blocking the whole app launch
    
    AppLogger.info('Starting Ulify Bootstrap...');

    final SharedPreferences sharedPreferences = await SharedPreferences.getInstance()
        .timeout(const Duration(seconds: 5), onTimeout: () => throw TimeoutException('SharedPreferences init timed out'));

    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)
        .timeout(const Duration(seconds: 10), onTimeout: () => throw TimeoutException('Firebase init timed out'));

    // 2. Optimized Firebase configuration
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: 100 * 1024 * 1024, // 100 MB limit (Resilient against huge cache ANRs)
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    _initProductionDiagnostics();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
    );

    // 3. Kick off background services (DO NOT AWAIT)
    // These will initialize while the app starts rendering the first frame
    container.read(appLifecycleServiceProvider).init();
    
    unawaited(container.read(notificationServiceProvider).init().catchError((e) {
      AppLogger.error('Main: Background notif service init failed', e);
    }));

    container.read(aiAssistantServiceProvider).config(
      apiKey: EnvConfig.aiApiKey,
      useMock: EnvConfig.useMockAi,
    );
    
    unawaited(container.read(adInitializationProvider.future));

    // 4. Launch the application
    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const AppErrorBoundary(child: UlifyApp()),
      ),
    );
    
    AppLogger.info('🚀 Ulify Bootstrap Complete');
  } catch (e, stack) {
    AppLogger.error('FATAL Startup Error', e, stack);
    
    // Recovery path for critical failures
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.light(useMaterial3: true),
        home: Scaffold(
          body: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32.0),
            color: const Color(0xFF1677F2), // Primary Brand Color
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.white, size: 64),
                const SizedBox(height: 32),
                const Text(
                  'Initialization Error',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 16),
                Text(
                  'Ulify encountered a problem during startup. This is usually due to a temporary connection issue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 16, height: 1.5),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    onPressed: () {
                      // Attempt to restart bootstrap
                      main();
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFF1677F2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Retry Launch', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UlifyApp extends ConsumerWidget {
  const UlifyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize services when user is logged in
    ref.listen(appUserProvider.select((user) => user.valueOrNull?.uid), (previous, next) {
      if (next != null && previous == null) {
        // Session restoration or login
        ref.read(presenceServiceProvider).init();
        ref.read(authRepositoryProvider).checkAndRestoreRestrictedContent(next);
      } else if (next == null && previous != null) {
        // Logout
        ref.read(presenceServiceProvider).dispose();
      }
    });

    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final connectivity = ref.watch(connectivityServiceProvider);
    
    return MaterialApp.router(
      title: 'Ulify',
      debugShowCheckedModeBanner: false,

      // Theme
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,

      // Navigation
      routerConfig: router,

      builder: (context, child) {
        return Column(
          children: [
            if (connectivity == ConnectivityStatus.isDisconnected)
              _buildOfflineBanner(context),
            Expanded(child: child ?? const SizedBox.shrink()),
          ],
        );
      },
    );
  }

  Widget _buildOfflineBanner(BuildContext context) {
    return Material(
      child: Container(
        width: double.infinity,
        color: Colors.red.shade800,
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: SafeArea(
          bottom: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Text(
                'No internet connection. Some features may be offline.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _initProductionDiagnostics() {
  if (kReleaseMode) {
    AppLogger.info('🚀 Ulify Production Build Initialized');
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }
}
