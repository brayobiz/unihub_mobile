import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:open_filex/open_filex.dart';
import '../features/auth/shared/providers.dart';
import '../app/router/app_router.dart';

final notificationServiceProvider = Provider((ref) => NotificationService(ref));

class NotificationService {
  final Ref _ref;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  NotificationService(this._ref);

  Future<void> init() async {
    // 1. Init Local Notifications for Foreground
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          if (details.payload!.startsWith('open_file:')) {
            // Tapping download complete notification takes user to detail screen 
            // where they can "Resume Studying" internally.
            // This is safer than trying to find the note object here.
            _ref.read(routerProvider).push('/main'); // Go to notes tab essentially
          } else {
            _ref.read(routerProvider).push(details.payload!);
          }
        }
      },
    );

    // 2. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // 3. Handle Background/Terminated Taps
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      final route = message.data['route'];
      if (route != null) {
        _ref.read(routerProvider).push(route);
      }
    });

    // 4. Save Token if already logged in
    _saveToken();
    _messaging.onTokenRefresh.listen((token) => _updateTokenInFirestore(token));
  }

  Future<bool> requestPermission() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted notification permission');
      _saveToken();
      return true;
    }
    return false;
  }

  Future<void> _saveToken() async {
    String? token = await _messaging.getToken();
    if (token != null) {
      await _updateTokenInFirestore(token);
    }
  }

  Future<void> _updateTokenInFirestore(String token) async {
    final user = _ref.read(authStateProvider).valueOrNull;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcmToken': token});
    }
  }

  Future<void> _showLocalNotification(RemoteMessage message) async {
    const androidDetails = AndroidNotificationDetails(
      'unihub_main_channel',
      'UniHub Notifications',
      importance: Importance.max,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await _localNotifications.show(
      message.hashCode,
      message.notification?.title,
      message.notification?.body,
      details,
      payload: message.data['route'],
    );
  }

  Future<void> showDownloadNotification({
    required int id,
    required String title,
    required int progress,
    bool isDone = false,
    String? filePath,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'unihub_downloads',
      'UniHub Downloads',
      channelDescription: 'Download progress and completion notifications',
      importance: isDone ? Importance.high : Importance.low,
      priority: isDone ? Priority.high : Priority.low,
      showProgress: !isDone,
      maxProgress: 100,
      progress: progress,
      ongoing: !isDone,
      onlyAlertOnce: true,
    );

    final details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      id,
      isDone ? 'Download Complete' : 'Downloading...',
      isDone ? title : '$title ($progress%)',
      details,
      payload: isDone ? 'open_file:$filePath' : null,
    );
  }

  /// Sends a "Push Notification Request" to Firestore.
  /// In a real production app, a Cloud Function would listen to this and send the FCM.
  Future<void> triggerPushNotification({
    required String recipientId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    // We add to a 'notifications_queue' which the backend processes
    await FirebaseFirestore.instance.collection('notifications_queue').add({
      'recipientId': recipientId,
      'title': title,
      'body': body,
      'data': data ?? {},
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
