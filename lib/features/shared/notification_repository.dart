import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/shared/domain/models/uni_notification.dart';
import 'package:unihub_mobile/features/shared/domain/repositories/notification_repository.dart' as domain;
import 'package:unihub_mobile/features/shared/data/repositories/notification_repository_impl.dart';

export 'package:unihub_mobile/features/shared/domain/models/uni_notification.dart';
export 'package:unihub_mobile/features/shared/domain/repositories/notification_repository.dart';

// Alias for backward compatibility if needed, but we'll update usages
typedef AppNotification = UniNotification;

final notificationRepositoryProvider = Provider<domain.NotificationRepository>((ref) {
  return NotificationRepositoryImpl(ref.watch(firestoreProvider));
});

final notificationsProvider = StreamProvider.family<List<UniNotification>, String?>((ref, module) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  
  return ref.watch(notificationRepositoryProvider).watchNotifications(user.uid, module: module);
});

final unreadNotificationsCountProvider = StreamProvider.family<int, String?>((ref, module) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(0);
  
  return ref.watch(notificationRepositoryProvider).watchUnreadCount(user.uid, module: module);
});
