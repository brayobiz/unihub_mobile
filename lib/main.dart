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

import 'features/profile/settings_screen.dart';
import 'services/notification_service.dart';
import 'services/presence_service.dart';
import 'services/connectivity_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable offline persistence for better network resilience
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

  // Initialize notifications
  container.read(notificationServiceProvider).init();

  // Initialize Ads (non-blocking)
  container.read(adInitializationProvider);

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const UniHubApp(),
    ),
  );
}

class UniHubApp extends ConsumerWidget {
  const UniHubApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize presence when user is logged in
    ref.listen(authStateProvider, (previous, next) {
      if (next.value != null) {
        ref.read(presenceServiceProvider).init();
      }
    });

    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final connectivity = ref.watch(connectivityServiceProvider);
    
    return MaterialApp.router(
      title: 'UniHubLife',
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
