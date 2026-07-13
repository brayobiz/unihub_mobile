import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:unihub_mobile/core/utils/app_logger.dart';
import 'package:unihub_mobile/core/services/notification_sender.dart';
import 'package:uuid/uuid.dart';
import '../features/announcements/domain/models/announcement.dart';
import '../features/auth/shared/providers.dart';
import '../app/router/app_router.dart';
import 'package:unihub_mobile/features/shared/notification_repository.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(ref);
  ref.onDispose(() => service.dispose());
  return service;
});

class NotificationService implements NotificationSender {
  final Ref _ref;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;
  StreamSubscription? _tokenSubscription;
  StreamSubscription? _onMessageSubscription;
  StreamSubscription? _onMessageOpenedAppSubscription;

  NotificationService(this._ref);

  FirebaseMessaging get _messaging => _ref.read(firebaseMessagingProvider);
  FirebaseFirestore get _firestore => _ref.read(firestoreProvider);

  void dispose() {
    _tokenSubscription?.cancel();
    _onMessageSubscription?.cancel();
    _onMessageOpenedAppSubscription?.cancel();
    _isInitialized = false;
  }

  Future<void> init() async {
    AppLogger.info('Initializing NotificationService...', 'NOTIF_SERVICE');
    if (_isInitialized) {
      AppLogger.info('Already initialized, updating token...', 'NOTIF_SERVICE');
      await _saveToken();
      return;
    }

    _ref.listen(authStateProvider, (previous, next) {
      if (next.value != null) {
        _saveToken();
      }
    });

    final settings = await _messaging.getNotificationSettings();
    AppLogger.info('Notification permission status: ${settings.authorizationStatus}', 'NOTIF_SERVICE');

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    const channel = AndroidNotificationChannel(
      'unihub_main_channel',
      'UniHub Notifications',
      description: 'Main channel for all UniHub notifications',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        if (details.payload != null) {
          _handleNotificationTap(details.payload!);
        }
      },
    );

    _onMessageSubscription?.cancel();
    _onMessageSubscription = FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _showLocalNotification(message);
    });

    _onMessageOpenedAppSubscription?.cancel();
    _onMessageOpenedAppSubscription = FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleRemoteMessageTap(message);
    });

    Future.delayed(const Duration(milliseconds: 500), () async {
      RemoteMessage? initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleRemoteMessageTap(initialMessage);
      }
    });

    await _saveToken();
    await _messaging.subscribeToTopic('all_users');
    
    final user = _ref.read(appUserProvider).valueOrNull;
    if (user != null && user.isAdmin) {
      AppLogger.info('Subscribing to admin notification topic', 'NOTIF_SERVICE');
      await _messaging.subscribeToTopic('admins');
    }
    
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
        AppLogger.info('User granted notification permission', 'NOTIF_SERVICE');
        await _saveToken();
        return true;
      }
    } catch (e) {
      AppLogger.error('Error requesting notification permission', e, null, 'NOTIF_SERVICE');
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
      AppLogger.error('Error getting FCM token', e, null, 'NOTIF_SERVICE');
    }
  }

  Future<void> _updateTokenInFirestore(String token) async {
    try {
      final user = _ref.read(authStateProvider).valueOrNull;
      if (user != null) {
        AppLogger.info('Saving FCM token for user (masked): ${token.substring(0, 8)}...', 'NOTIF_SERVICE');
        await _firestore
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
        AppLogger.notification('FCM Token registered in Firestore');
      }
    } catch (e) {
      AppLogger.error('Error updating FCM token in Firestore', e, null, 'NOTIF_SERVICE');
    }
  }

  Future<void> deleteToken() async {
    try {
      final user = _ref.read(authStateProvider).valueOrNull;
      String? token;
      try {
        token = await _messaging.getToken().timeout(const Duration(seconds: 2));
      } catch (_) {}
      
      if (user != null && token != null) {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('tokens')
            .doc(token)
            .delete()
            .timeout(const Duration(seconds: 2))
            .catchError((_) => null);
      }
      
      await _messaging.deleteToken().timeout(const Duration(seconds: 2)).catchError((_) => null);
      _isInitialized = false;
    } catch (e) {
      AppLogger.error('Error during notification token cleanup', e, null, 'NOTIF_SERVICE');
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

    await markAsRead(userId, notificationId);

    try {
      final doc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc(notificationId)
          .get();
      
      if (doc.exists) {
        final notification = UniNotification.fromFirestore(doc);
        await _navigateToNotificationTarget(notification);
      } else {
        final route = message.data['route'];
        if (route != null) _handleNotificationTap(route);
      }
    } catch (e) {
      AppLogger.error('Error handling remote message tap', e, null, 'NOTIF_SERVICE');
    }
  }

  Future<void> _navigateToNotificationTarget(UniNotification n) async {
    final router = _ref.read(routerProvider);

    if (n.deepLink != null && n.deepLink!.isNotEmpty) {
      router.push(n.deepLink!);
      return;
    }

    if (n.targetId == null || n.targetId!.isEmpty) return;

    try {
      switch (n.type) {
        case NotificationType.chat:
        case NotificationType.support:
          final isAdmin = _ref.read(appUserProvider).valueOrNull?.isAdmin ?? false;
          if (isAdmin && n.type == NotificationType.support) {
            router.push('/admin/support/${n.targetId}');
          } else {
            router.push('/chat', extra: {
              'conversationId': n.targetId,
              'otherUserName': n.actorName ?? (n.type == NotificationType.support ? 'UniHub Support' : 'Message'),
            });
          }
          break;

        case NotificationType.marketplace:
        case NotificationType.listing:
          router.push('/listing-detail/${n.targetId}');
          break;

        case NotificationType.housing:
          if (n.targetType == 'viewing_request') {
            router.push('/viewing-requests');
          } else {
            router.push('/housing-detail/${n.targetId}');
          }
          break;

        case NotificationType.notes:
          router.push('/note-detail/${n.targetId}');
          break;

        case NotificationType.gig:
          if (n.title.contains('Application Update')) {
            router.push('/my-gig-applications');
          } else if (n.title.contains('New Gig Application')) {
            router.push('/employer-dashboard');
          } else {
            router.push('/gig-detail/${n.targetId}');
          }
          break;

        case NotificationType.follower:
          if (n.actorId != null) {
            router.push('/seller-profile/${n.actorId}');
          }
          break;

        case NotificationType.community:
          router.push('/community');
          break;

        case NotificationType.events:
          if (n.targetType == 'organizer') {
            router.push('/organizers/${n.targetId}');
          } else {
            router.push('/events/${n.targetId}');
          }
          break;

        default:
          break;
      }
    } catch (e) {
      AppLogger.error('Navigation error in service', e, null, 'NOTIF_SERVICE');
    }
  }

  void _handleNotificationTap(String payload) {
    if (payload.startsWith('open_file:')) {
      _ref.read(routerProvider).push('/main'); 
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

    final notificationId = message.data['notificationId'];
    final int id = notificationId != null ? notificationId.hashCode : message.hashCode;

    await _localNotifications.show(
      id,
      message.notification?.title ?? message.data['title'],
      message.notification?.body ?? message.data['body'],
      details,
      payload: message.data['route'] ?? message.data['deepLink'],
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

  Future<void> triggerPushNotification({
    required String recipientId,
    required String title,
    required String body,
    Map<String, dynamic>? data,
    bool isBroadcast = false,
  }) async {
    try {
      await _firestore.collection('notifications_queue').add({
        'recipientId': isBroadcast ? null : recipientId,
        'isBroadcast': isBroadcast,
        'title': title,
        'body': body,
        'data': data ?? {},
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      AppLogger.error('Error triggering push notification', e, null, 'NOTIF_SERVICE');
    }
  }

  Future<void> notifyAdmins({
    required String title,
    required String body,
    required String route,
    Map<String, dynamic>? data,
  }) async {
    await triggerPushNotification(
      recipientId: '',
      isBroadcast: true,
      title: title,
      body: body,
      data: {
        'route': route,
        'topic': 'admins',
        if (data != null) ...data,
      },
    );
  }

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
    if (priority != NotificationPriority.high) {
      try {
        final doc = await _firestore.collection('users').doc(recipientId).get();
        if (doc.exists) {
          final settings = doc.data()?['notificationSettings'] as Map<String, dynamic>?;
          if (settings != null) {
            bool isEnabled = true;
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
                isEnabled = settings['gigs'] ?? true;
                break;
              case NotificationType.community:
                isEnabled = settings['community_activity'] ?? true;
                break;
              case NotificationType.events:
                isEnabled = settings['events'] ?? true;
                break;
            }

            if (!isEnabled) return;
          }
        }
      } catch (_) {}
    }

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
        case NotificationType.events:
          effectiveTargetType = 'events';
          break;
        default: break;
      }
    }

    final notification = UniNotification(
      id: '',
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

    UniNotification? savedNotification;
    if (recipientId.isNotEmpty) {
      savedNotification = await _ref.read(notificationRepositoryProvider).createNotification(notification);
    }

    String? route;
    if (deepLink != null) {
      route = deepLink;
    } else if (targetId != null) {
      switch (type) {
        case NotificationType.chat:
          route = '/chat';
          break;
        case NotificationType.support:
          // Intelligent routing: If recipient is an admin, go to Support Center, else regular chat
          final recipientData = await _firestore.collection('users').doc(recipientId).get();
          final bool recipientIsAdmin = (recipientData.data()?['isAdmin'] == true) || 
                                       (recipientData.data()?['roles'] as List?)?.contains('admin') == true;
          route = recipientIsAdmin ? '/admin/support/$targetId' : '/chat';
          break;
        case NotificationType.listing:
          route = '/listing-detail';
          break;
        default: break;
      }
    }

    await triggerPushNotification(
      recipientId: recipientId,
      title: title,
      body: body,
      data: {
        'notificationId': savedNotification?.id,
        'type': type.name,
        'targetId': targetId,
        'targetType': effectiveTargetType,
        'deepLink': deepLink,
        'route': route,
      },
    );
  }

  Future<void> triggerMarketplaceReminder({String? customTitle, String? customBody}) async {
    String title;
    String body;

    if (customTitle != null && customBody != null) {
      title = customTitle;
      body = customBody;
    } else {
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
      title = randomMessage['title']!;
      body = randomMessage['body']!;
    }

    // 1. Send Push Notification
    await triggerPushNotification(
      recipientId: '', // Ignored for broadcast
      isBroadcast: true,
      title: title,
      body: body,
      data: {
        'route': '/marketplace',
        'targetType': 'marketplace',
        'topic': 'all_users',
      },
    );

    // 2. Create In-App Announcement for 24 hours
    try {
      final user = _ref.read(appUserProvider).valueOrNull;
      if (user == null || !user.isAdmin) return;

      final announcement = Announcement(
        id: const Uuid().v4(),
        title: title,
        content: body,
        type: AnnouncementType.featureSpecific,
        targetFeatures: ['marketplace'],
        targetAudience: {'verifiedOnly': false, 'university': 'All', 'roles': []},
        displayStyle: AnnouncementDisplayStyle.banner,
        priority: AnnouncementPriority.normal,
        status: AnnouncementStatus.published,
        publishAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(hours: 24)),
        createdBy: user.uid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _firestore.collection('announcements').doc(announcement.id).set(announcement.toJson());
      AppLogger.info('Marketplace broadcast persistent announcement created', 'NOTIF_SERVICE');
    } catch (e) {
      AppLogger.error('Failed to create persistent announcement for broadcast', e, null, 'NOTIF_SERVICE');
    }
  }

  Future<void> markAsRead(String userId, String notificationId) async {
    await _ref.read(notificationRepositoryProvider).markAsRead(userId, notificationId);
  }

  Future<void> markAsReadByTarget(String userId, String targetId) async {
    await _ref.read(notificationRepositoryProvider).markTargetAsRead(userId, targetId);
  }

  Future<void> markAllAsRead(String userId, {String? module}) async {
    await _ref.read(notificationRepositoryProvider).markFeatureNotificationsAsRead(userId, module: module);
  }

  Future<void> deleteNotification(String userId, String notificationId) async {
    await _ref.read(notificationRepositoryProvider).deleteNotification(userId, notificationId);
  }
}
