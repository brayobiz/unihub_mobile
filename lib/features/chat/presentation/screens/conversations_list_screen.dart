import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/conversation.dart';
import '../../domain/models/message.dart';
import '../../shared/providers.dart';
import '../../../../widgets/skeleton_loader.dart';

class ConversationsListScreen extends ConsumerStatefulWidget {
  const ConversationsListScreen({super.key});

  @override
  ConsumerState<ConversationsListScreen> createState() => _ConversationsListScreenState();
}

class _ConversationsListScreenState extends ConsumerState<ConversationsListScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null) return Scaffold(backgroundColor: theme.colorScheme.surface, body: const Center(child: Text('Please login to view chats')));

    final conversationsAsync = ref.watch(conversationsProvider(user.uid));

    // Mark messages as delivered when they appear in the list
    ref.listen(conversationsProvider(user.uid), (previous, next) {
      if (next.hasValue) {
        for (final conv in next.value!) {
          if (conv.lastMessageSenderId != user.uid && 
              conv.lastMessageStatus == MessageStatus.sent) {
            ref.read(chatRepositoryProvider).markAsDelivered(conv.id, user.uid);
          }
        }
      }
    });

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Messages',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          _buildSearchBox(context),
          Expanded(
            child: conversationsAsync.when(
              data: (conversations) {
                final filtered = conversations.where((c) {
                  final titleMatch = c.context?.title.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
                  final typeMatch = c.context?.type.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
                  final lastMessageMatch = c.lastMessage?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
                  return titleMatch || typeMatch || lastMessageMatch;
                }).toList();

                if (filtered.isEmpty) {
                  return _buildEmptyState(context);
                }

                return RefreshIndicator(
                  onRefresh: () async {
                    // Riverpod streams auto-refresh, but we can trigger a manual reload if needed
                    ref.invalidate(conversationsProvider(user.uid));
                  },
                  child: ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      return _ConversationTile(
                        conversation: filtered[index],
                        currentUserId: user.uid,
                      );
                    },
                  ),
                );
              },
              loading: () => ListView.builder(
                itemCount: 8,
                itemBuilder: (context, index) => const _ConversationLoadingTile(),
              ),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      color: theme.colorScheme.surface,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        child: TextField(
          controller: _searchController,
          style: TextStyle(color: theme.colorScheme.onSurface),
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: 'Search conversations...',
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5), fontSize: 14),
            prefixIcon: Icon(Icons.search, color: theme.colorScheme.onSurfaceVariant),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Messages from marketplace and housing\nwill appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends ConsumerWidget {
  final Conversation conversation;
  final String currentUserId;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final otherUserId = conversation.participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    final otherUserAsync = ref.watch(userByIdProvider(otherUserId));
    final unreadCount = conversation.unreadCounts[currentUserId] ?? 0;

    return otherUserAsync.when(
      data: (otherUser) {
        final displayName = otherUser?.fullName ?? 'User';
        final photoUrl = otherUser?.photoUrl;

        return ListTile(
          onTap: () {
            context.push('/chat', extra: {
              'conversationId': conversation.id,
              'otherUserName': displayName,
              'context': conversation.context,
            });
          },
          leading: CircleAvatar(
            radius: 28,
            backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null
                ? Text(displayName[0].toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary))
                : null,
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  displayName,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                    fontSize: 15,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _formatTime(conversation.lastMessageTime),
                style: TextStyle(
                  fontSize: 11,
                  color: unreadCount > 0 ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                  fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              if (conversation.context != null)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _getContextColor(conversation.context!.type).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        conversation.context!.type.toUpperCase(),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: _getContextColor(conversation.context!.type),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        conversation.context!.title,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 4),
              Row(
                children: [
              Expanded(
                child: Row(
                  children: [
                    if (conversation.lastMessageSenderId == currentUserId) ...[
                      _buildStatusIcon(context, conversation.lastMessageStatus ?? MessageStatus.sent),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        conversation.lastMessage ?? 'No messages yet',
                        style: TextStyle(
                          fontSize: 13,
                          color: unreadCount > 0 ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                          fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (unreadCount > 0)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        unreadCount.toString(),
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
      loading: () => const _ConversationLoadingTile(),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }

  Widget _buildStatusIcon(BuildContext context, MessageStatus status) {
    final theme = Theme.of(context);
    IconData icon;
    Color color = theme.colorScheme.onSurfaceVariant;
    switch (status) {
      case MessageStatus.sending:
        icon = Icons.access_time;
        break;
      case MessageStatus.sent:
        icon = Icons.check;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = theme.colorScheme.primary;
        break;
    }
    return Icon(icon, size: 14, color: color);
  }

  Color _getContextColor(String type) {
    switch (type.toLowerCase()) {
      case 'marketplace':
        return AppColors.marketplace;
      case 'housing':
        return AppColors.housing;
      case 'support':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) {
      return DateFormat.Hm().format(date);
    } else if (diff.inDays < 7) {
      return DateFormat.E().format(date);
    } else {
      return DateFormat.MMMd().format(date);
    }
  }
}

class _ConversationLoadingTile extends StatelessWidget {
  const _ConversationLoadingTile();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: SkeletonLoader(width: 56, height: 56, borderRadius: 28, color: theme.colorScheme.surfaceVariant),
      title: SkeletonLoader(width: 120, height: 16, color: theme.colorScheme.surfaceVariant),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 8.0),
        child: SkeletonLoader(width: 200, height: 12, color: theme.colorScheme.surfaceVariant),
      ),
    );
  }
}
