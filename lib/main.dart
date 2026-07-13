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

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // RC-Investigate: Moving diagnostic initialization AFTER Firebase init.
    // Accessing FirebaseCrashlytics.instance before Firebase.initializeApp() 
    // can cause a deadlock/hang in release builds.
    
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 15));

    // Initialize diagnostics only after Firebase is ready
    _initProductionDiagnostics();

    // Enable offline persistence for better network resilience (Scenario 7)
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final sharedPreferences = await SharedPreferences.getInstance();

    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
    );

    // Initialize global services IN BACKGROUND to prevent startup hang
    // Note: unawaited requires 'import dart:async'
    unawaited(container.read(notificationServiceProvider).init().catchError((e) {
      AppLogger.error('Main: Notification Service init failed', e);
    }));
    
    container.read(appLifecycleServiceProvider).init();

    // Initialize Ads asynchronously in background
    container.read(adInitializationProvider.future).catchError((e) {
      AppLogger.error('Main: Ad initialization failed in background', e);
    });

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const UniHubApp(),
      ),
    );
  } catch (e, stack) {
    AppLogger.error('FATAL Startup Error', e, stack);
    // Emergency launch to prevent "Launching Forever" screen
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(child: Text('App failed to start: $e\nPlease restart the app.')),
          ),
        ),
      ),
    );
  }
}

class UniHubApp extends ConsumerWidget {
  const UniHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize services when user is logged in (Scenario 4 & 5)
    ref.listen(appUserProvider.select((user) => user.valueOrNull?.uid), (previous, next) {
      if (next != null && previous == null) {
        // First login or session restoration after cold start
        ref.read(presenceServiceProvider).init();
        // Spark Plan Workaround: Self-heal restriction status if it has expired
        ref.read(authRepositoryProvider).checkAndRestoreRestrictedContent(next);
      } else if (next == null && previous != null) {
        // User logged out
        ref.read(presenceServiceProvider).dispose();
      }
    });

    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final connectivity = ref.watch(connectivityServiceProvider);
    
    return MaterialApp.router(
      title: 'UniHub',
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
                'You are currently offline. Some features may be limited.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// RC-3 Production Diagnostic Initializer
void _initProductionDiagnostics() {
  if (kReleaseMode) {
    AppLogger.info('🚀 UniHub Production Build Initialized');
    
    // Pass all uncaught errors from the framework to Crashlytics.
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    
    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics.
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }
}

