import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../features/auth/shared/providers.dart';
import '../app/router/app_router.dart';
import 'package:unihub_mobile/features/shared/notification_repository.dart';

final notificationServiceProvider = Provider((ref) => NotificationService(ref));

class NotificationService {
  final Ref _ref;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;
  StreamSubscription? _tokenSubscription;

  NotificationService(this._ref);

  Future<void> init() async {
    if (_isInitialized) {
      await _saveToken();
      return;
    }

    // 1. Init Local Notifications for Foreground
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          _handleNotificationTap(details.payload!);
        }
      },
    );

    // 2. Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    // 3. Handle Background/Terminated Taps
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleRemoteMessageTap(message);
    });

    // Check if app was opened from a terminated state via a notification
    RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleRemoteMessageTap(initialMessage);
    }

    // 4. Save Token if already logged in
    await _saveToken();
    
    _tokenSubscription?.cancel();
    _tokenSubscription = _messaging.onTokenRefresh.listen((token) => _updateTokenInFirestore(token));
    
    _isInitialized = true;
  }

  Future<bool> requestPermission() async {
    try {
      NotificationSettings settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('User granted notification permission');
        await _saveToken();
        return true;
      }
    } catch (e) {
      debugPrint('Error requesting notification permission: $e');
    }
    return false;
  }

  Future<void> _saveToken() async {
    try {
      String? token = await _messaging.getToken();
      if (token != null) {
        await _updateTokenInFirestore(token);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  Future<void> _updateTokenInFirestore(String token) async {
    final user = _ref.read(authStateProvider).valueOrNull;
    if (user != null) {
      // Store token in a sub-collection for multi-device support
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tokens')
          .doc(token)
          .set({
        'token': token,
        'createdAt': FieldValue.serverTimestamp(),
        'platform': defaultTargetPlatform.name,
        'lastActive': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> deleteToken() async {
    try {
      final user = _ref.read(authStateProvider).valueOrNull;
      String? token = await _messaging.getToken();
      
      if (user != null && token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('tokens')
            .doc(token)
            .delete();
      }
      
      await _messaging.deleteToken();
      _isInitialized = false;
    } catch (e) {
      debugPrint('Error deleting FCM token: $e');
    }
  }

  void _handleRemoteMessageTap(RemoteMessage message) {
    final notificationId = message.data['notificationId'];
    final route = message.data['route'];
    final userId = _ref.read(authStateProvider).valueOrNull?.uid;

    if (userId != null && notificationId != null) {
      markAsRead(userId, notificationId);
    }

    if (route != null) {
      _handleNotificationTap(route);
    }
  }

  void _handleNotificationTap(String payload) {
    if (payload.startsWith('open_file:')) {
      _ref.read(routerProvider).push('/main'); // Go to notes tab/main
    } else {
      _ref.read(routerProvider).push(payload);
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
    try {
      // We add to a 'notifications_queue' which the backend processes
      await FirebaseFirestore.instance.collection('notifications_queue').add({
        'recipientId': recipientId,
        'title': title,
        'body': body,
        'data': data ?? {},
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error triggering push notification: $e');
    }
  }

  // --- Notification Foundation ---

  Stream<List<UniNotification>> watchNotifications(String userId) {
    return _ref.read(notificationRepositoryProvider).watchNotifications(userId);
  }

  Stream<int> watchUnreadCount(String userId) {
    return _ref.read(notificationRepositoryProvider).watchUnreadCount(userId);
  }

  Future<void> sendNotification({
    required String recipientId,
    required String title,
    required String body,
    required NotificationType type,
    String? actorId,
    String? actorName,
    String? actorPhotoUrl,
    String? imageUrl,
    String? targetId,
    String? targetType,
    String? deepLink,
    NotificationPriority priority = NotificationPriority.normal,
    Map<String, dynamic>? metadata,
  }) async {
    final notification = UniNotification(
      id: '', // Will be generated by repository
      recipientId: recipientId,
      actorId: actorId,
      actorName: actorName,
      actorPhotoUrl: actorPhotoUrl,
      type: type,
      title: title,
      body: body,
      imageUrl: imageUrl,
      targetId: targetId,
      targetType: targetType,
      deepLink: deepLink,
      priority: priority,
      createdAt: DateTime.now(),
      metadata: metadata ?? {},
    );

    final savedNotification = await _ref.read(notificationRepositoryProvider).createNotification(notification);

    // Also trigger push notification if needed
    // Build route for push data
    String? route;
    if (deepLink != null) {
      route = deepLink;
    } else if (targetId != null) {
      switch (type) {
        case NotificationType.chat:
        case NotificationType.support:
          route = '/chat'; 
          break;
        case NotificationType.listing:
          route = '/marketplace-detail';
          break;
        case NotificationType.gig:
          route = '/gig-detail';
          break;
        default:
          break;
      }
    }

    await triggerPushNotification(
      recipientId: recipientId,
      title: title,
      body: body,
      data: {
        'notificationId': savedNotification.id,
        'type': type.name,
        'targetId': targetId,
        'targetType': targetType,
        'deepLink': deepLink,
        'route': route,
      },
    );
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    await _ref.read(notificationRepositoryProvider).markAsRead(userId, notificationId);
  }

  Future<void> markAllAsRead(String userId) async {
    await _ref.read(notificationRepositoryProvider).markAllAsRead(userId);
  }

  Future<void> deleteNotification(String userId, String notificationId) async {
    await _ref.read(notificationRepositoryProvider).deleteNotification(userId, notificationId);
  }
}
