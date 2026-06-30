import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../features/auth/shared/providers.dart';
import '../app/router/app_router.dart';
import 'package:unihub_mobile/features/shared/notification_repository.dart';
import 'package:unihub_mobile/features/marketplace/shared/providers.dart';
import 'package:unihub_mobile/features/housing/shared/providers.dart';
import 'package:unihub_mobile/features/notes/shared/providers.dart';
import 'package:unihub_mobile/features/chat/shared/providers.dart';

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

    // Listen to auth state to save token when user logs in
    _ref.listen(authStateProvider, (previous, next) {
      if (next.value != null) {
        _saveToken();
      }
    });

    // 1. Init Local Notifications for Foreground
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
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
    // We add a small delay to ensure the router and state are ready
    Future.delayed(const Duration(milliseconds: 500), () async {
      RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        _handleRemoteMessageTap(initialMessage);
      }
    });

    // 4. Save Token if already logged in
    await _saveToken();
    
    // Subscribe to broadcast topic
    await _messaging.subscribeToTopic('all_users');
    
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
      
      // Get token with a short timeout to prevent hanging on logout
      String? token;
      try {
        token = await _messaging.getToken().timeout(const Duration(seconds: 2));
      } catch (e) {
        debugPrint('Timeout/error getting token during deletion: $e');
      }
      
      if (user != null && token != null) {
        // Attempt to delete from Firestore, but don't hang if network is slow
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('tokens')
            .doc(token)
            .delete()
            .timeout(const Duration(seconds: 2))
            .catchError((e) {
          debugPrint('Firestore token deletion failed: $e');
          return null;
        });
      }
      
      // Delete FCM token from device/server
      await _messaging.deleteToken().timeout(const Duration(seconds: 2)).catchError((e) {
        debugPrint('FCM deleteToken failed: $e');
        return null;
      });
      
      _isInitialized = false;
    } catch (e) {
      debugPrint('Error during notification token cleanup: $e');
    }
  }

  Future<void> _handleRemoteMessageTap(RemoteMessage message) async {
    final notificationId = message.data['notificationId'];
    final userId = _ref.read(authStateProvider).valueOrNull?.uid;

    if (userId == null || notificationId == null) {
      final route = message.data['route'];
      if (route != null) _handleNotificationTap(route);
      return;
    }

    // 1. Mark as read
    await markAsRead(userId, notificationId);

    // 2. Fetch full notification to get metadata and targetId
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .get();
      
      if (doc.exists) {
        final notification = UniNotification.fromFirestore(doc);
        await _navigateToNotificationTarget(notification);
      } else {
        // Fallback to simple route if doc doesn't exist
        final route = message.data['route'];
        if (route != null) _handleNotificationTap(route);
      }
    } catch (e) {
      debugPrint('Error handling remote message tap: $e');
    }
  }

  Future<void> _navigateToNotificationTarget(UniNotification n) async {
    final router = _ref.read(routerProvider);

    // 1. Explicit deepLink
    if (n.deepLink != null && n.deepLink!.isNotEmpty) {
      router.push(n.deepLink!);
      return;
    }

    if (n.targetId == null || n.targetId!.isEmpty) return;

    try {
      switch (n.type) {
        case NotificationType.chat:
        case NotificationType.support:
          router.push('/chat', extra: {
            'conversationId': n.targetId,
            'otherUserName': n.actorName ?? (n.type == NotificationType.support ? 'UniHub Support' : 'Message'),
          });
          break;

        case NotificationType.marketplace:
        case NotificationType.listing:
          final listing = await _ref.read(marketplaceRepositoryProvider).getListingById(n.targetId!);
          if (listing != null) {
            router.push('/listing-detail', extra: listing);
          }
          break;

        case NotificationType.housing:
          final listing = await _ref.read(housingRepositoryProvider).getListingById(n.targetId!);
          if (listing != null) {
            router.push('/housing-detail', extra: listing);
          }
          break;

        case NotificationType.notes:
          final note = await _ref.read(notesRepositoryProvider).getNoteById(n.targetId!);
          if (note != null) {
            router.push('/note-detail', extra: note);
          }
          break;

        case NotificationType.gig:
          if (n.title.contains('Application Update')) {
            router.push('/my-gig-applications');
          } else if (n.title.contains('New Gig Application')) {
            router.push('/employer-dashboard');
          } else {
            router.push('/gigs');
          }
          break;

        case NotificationType.follower:
          if (n.actorId != null) {
            router.push('/seller-profile', extra: n.actorId);
          }
          break;

        case NotificationType.community:
          router.push('/community');
          break;

        default:
          break;
      }
    } catch (e) {
      debugPrint('Navigation error in service: $e');
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
      isDone ? 'Ready to Study' : 'Preparing Material...',
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
    bool isBroadcast = false,
  }) async {
    try {
      // We add to a 'notifications_queue' which the backend processes
      await FirebaseFirestore.instance.collection('notifications_queue').add({
        'recipientId': isBroadcast ? null : recipientId,
        'isBroadcast': isBroadcast,
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

  /// Triggers a random marketplace reminder to all users.
  Future<void> triggerMarketplaceReminder() async {
    final messages = [
      {
        'title': 'New Deals Alert! 🛍️',
        'body': 'Fresh items just landed in the marketplace. See what you can find today!',
      },
      {
        'title': 'UniHub Marketplace 🎓',
        'body': 'Looking for something specific? Your campus mates might be selling exactly what you need!',
      },
      {
        'title': 'Save Money Today! 💸',
        'body': 'Why buy new when you can get quality items from fellow students? Check out the marketplace.',
      },
      {
        'title': 'Tired of the same old stuff? 📦',
        'body': 'Discover hidden gems and great bargains in the marketplace right now!',
      },
    ];

    final randomMessage = (messages..shuffle()).first;

    await triggerPushNotification(
      recipientId: '', // Ignored for broadcast
      isBroadcast: true,
      title: randomMessage['title']!,
      body: randomMessage['body']!,
      data: {
        'route': '/marketplace',
        'targetType': 'marketplace',
      },
    );
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
    // 0. Check recipient notification preferences
    if (priority != NotificationPriority.high) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(recipientId).get();
        if (doc.exists) {
          final settings = doc.data()?['notificationSettings'] as Map<String, dynamic>?;
          if (settings != null) {
            bool isEnabled = true;
            
            // Map NotificationType/targetType to setting keys
            switch (type) {
              case NotificationType.chat:
              case NotificationType.support:
                isEnabled = settings['new_messages'] ?? true;
                break;
              case NotificationType.marketplace:
              case NotificationType.listing:
                isEnabled = settings['marketplace'] ?? true;
                break;
              case NotificationType.housing:
                // If it's for the plug dashboard, check 'plug' setting, otherwise 'housing'
                if (deepLink?.contains('plug') == true || targetType == 'plug') {
                  isEnabled = settings['plug'] ?? true;
                } else {
                  isEnabled = settings['housing'] ?? true;
                }
                break;
              case NotificationType.notes:
                isEnabled = settings['notes'] ?? true;
                break;
              case NotificationType.review:
                isEnabled = settings['reviews'] ?? true;
                break;
              case NotificationType.follower:
                isEnabled = settings['followers'] ?? true;
                break;
              case NotificationType.system:
                isEnabled = settings['system'] ?? true;
                break;
              case NotificationType.gig:
                // Gigs usually fall under marketplace/community preference or own
                isEnabled = settings['marketplace'] ?? true;
                break;
              case NotificationType.community:
                isEnabled = settings['community_activity'] ?? true;
                break;
            }

            if (!isEnabled) {
              debugPrint('🚫 Notification suppressed by user preference: $type to $recipientId');
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('⚠️ Error checking preferences: $e');
      }
    }

    // Logic to ensure notifications appear in the correct feature-specific tabs.
    // The targetType is used by NotificationRepository to filter by module/feature.
    String? effectiveTargetType = targetType;
    if (effectiveTargetType == null) {
      switch (type) {
        case NotificationType.marketplace:
        case NotificationType.listing:
        case NotificationType.review:
          effectiveTargetType = 'marketplace';
          break;
        case NotificationType.housing:
          effectiveTargetType = 'housing';
          break;
        case NotificationType.notes:
          effectiveTargetType = 'notes';
          break;
        case NotificationType.gig:
          effectiveTargetType = 'gig';
          break;
        case NotificationType.community:
          effectiveTargetType = 'community';
          break;
        case NotificationType.support:
        case NotificationType.chat:
          // For chat, we usually expect the caller to pass the specific targetType (e.g., 'marketplace' or 'housing')
          // because chat can belong to any module. If not passed, it only shows in Home.
          break;
        default:
          break;
      }
    }

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
      targetType: effectiveTargetType,
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
        'targetType': effectiveTargetType,
        'deepLink': deepLink,
        'route': route,
      },
    );
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    await _ref.read(notificationRepositoryProvider).markAsRead(userId, notificationId);
  }

  Future<void> markAllAsRead(String userId, {String? module}) async {
    await _ref.read(notificationRepositoryProvider).markFeatureNotificationsAsRead(userId, module: module);
  }

  Future<void> deleteNotification(String userId, String notificationId) async {
    await _ref.read(notificationRepositoryProvider).deleteNotification(userId, notificationId);
  }
}
