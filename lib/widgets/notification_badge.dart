import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/features/shared/notification_repository.dart';

class NotificationBadge extends ConsumerWidget {
  final Color? iconColor;
  final String? module;
  
  const NotificationBadge({
    super.key, 
    this.iconColor,
    this.module,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final unreadCount = ref.watch(unreadNotificationsCountProvider(module)).valueOrNull ?? 0;
    final effectiveColor = iconColor ?? theme.colorScheme.onSurface;
    
    return Stack(
      children: [
        IconButton(
          onPressed: () => context.push('/notifications', extra: module),
          icon: Icon(Icons.notifications_none_rounded, color: effectiveColor),
        ),
        if (unreadCount > 0)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                unreadCount > 9 ? '9+' : '$unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
