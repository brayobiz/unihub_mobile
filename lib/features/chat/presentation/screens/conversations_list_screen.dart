import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/conversation.dart';
import '../../domain/models/message.dart';
import '../../shared/providers.dart';
import '../../../../widgets/skeleton_loader.dart';
import '../../../../widgets/notification_badge.dart';
import '../../../../widgets/app_drawer.dart';

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
      drawer: AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu_rounded, color: theme.colorScheme.onSurface),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          'Messages',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        centerTitle: false,
        actions: [
          const NotificationBadge(),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: Consumer(
              builder: (context, ref, _) {
                // Optimization: only watch photo and name
                final userData = ref.watch(appUserProvider.select((u) {
                  final user = u.valueOrNull;
                  if (user == null) return null;
                  return (
                    photoUrl: user.photoUrl,
                    fullName: user.fullName,
                  );
                }));
                
                return CircleAvatar(
                  radius: 16,
                  backgroundColor: theme.colorScheme.surfaceVariant,
                  backgroundImage: userData?.photoUrl != null ? CachedNetworkImageProvider(userData!.photoUrl!) : null,
                  onBackgroundImageError: userData?.photoUrl != null ? (e, s) => debugPrint('🖼️ AppBar Avatar Error: $e') : null,
                  child: userData?.photoUrl == null 
                      ? Text(
                          userData?.fullName.isNotEmpty == true ? userData!.fullName[0].toUpperCase() : 'U',
                          style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                        )
                      : null,
                );
              }
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: Column(
        children: [
          _buildSearchBox(context),
          // Hardware: Only show security badge when not searching to keep results focused
          if (_searchQuery.isEmpty) _buildSecurityBadge(context),
          Expanded(
            child: conversationsAsync.when(
              data: (conversations) {
                if (conversations.isEmpty) {
                  return _buildEmptyState(context);
                }

                final filtered = conversations.where((c) {
                  final titleMatch = c.context?.title.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
                  final typeMatch = c.context?.type.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
                  final lastMessageMatch = c.lastMessage?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false;
                  return titleMatch || typeMatch || lastMessageMatch;
                }).toList();

                if (filtered.isEmpty) {
                  return _buildEmptyState(context);
                }

                // Separate Support sessions from regular chats for better visibility
                final supportSessions = filtered.where((c) => c.isSupport && c.supportStatus != 'closed' && c.supportStatus != 'resolved').toList();
                final regularChats = filtered.where((c) => !c.isSupport || c.supportStatus == 'closed' || c.supportStatus == 'resolved').toList();

                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(conversationsProvider(user.uid));
                  },
                  child: ListView(
                    children: [
                      if (supportSessions.isNotEmpty && _searchQuery.isEmpty) ...[
                        _buildSectionHeader(context, 'Open Support Sessions', Icons.support_agent_rounded),
                        ...supportSessions.map((conv) => _ConversationTile(
                          conversation: conv,
                          currentUserId: user.uid,
                          isHighlight: true,
                        )),
                        const Divider(height: 1),
                        _buildSectionHeader(context, 'Recent Messages', Icons.history_rounded),
                      ],
                      ...regularChats.map((conv) => _ConversationTile(
                        conversation: conv,
                        currentUserId: user.uid,
                      )),
                    ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/user-search'),
        backgroundColor: theme.colorScheme.primary,
        child: const Icon(Icons.message_outlined, color: Colors.white),
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

  Widget _buildSecurityBadge(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.gpp_good_outlined, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Your conversations are end-to-end encrypted and private.',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
              letterSpacing: 1.1,
            ),
          ),
        ],
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
            'Messages from marketplace, housing,\nand support will appear here.',
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
  final bool isHighlight;

  const _ConversationTile({
    required this.conversation,
    required this.currentUserId,
    this.isHighlight = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final otherUserId = conversation.participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    // Support logic: Ensure support chats are ALWAYS visible and maintain 'Ulify Support' identity
    final bool isSupport = conversation.isSupport || otherUserId == 'unihub_admin' || conversation.context?.type == 'support';

    final unreadCount = conversation.unreadCounts[currentUserId] ?? 0;

    if (isSupport) {
      // For support chats, we ignore the assigned admin's personal name/photo in the list view
      // to maintain the official "Ulify Support" channel identity.
      return _buildTile(context, theme, null, unreadCount);
    }

    return ref.watch(publicUserProvider(otherUserId)).when(
      data: (otherUser) => _buildTile(context, theme, otherUser, unreadCount),
      loading: () => const _ConversationLoadingTile(),
      error: (err, stack) => _buildTile(context, theme, null, unreadCount),
    );
  }

  Widget _buildTile(BuildContext context, ThemeData theme, AppUser? otherUser, int unreadCount) {
    final bool isSupport = conversation.isSupport ||
                          conversation.participants.contains('unihub_admin') ||
                          conversation.context?.type == 'support';

    // Always use 'Ulify Support' for support channels regardless of who is assigned.
    final String displayName = isSupport ? 'Ulify Support' : (otherUser?.fullName ?? 'User');

    final String? photoUrl = isSupport ? null : otherUser?.photoUrl;

    return ListTile(
      tileColor: isHighlight ? theme.colorScheme.primary.withOpacity(0.03) : null,
      onTap: () {
        context.push('/chat', extra: {
          'conversationId': conversation.id,
          'otherUserName': displayName,
          'context': conversation.context,
        });
      },
      leading: CircleAvatar(
        radius: isSupport ? 28 : 24, // Slightly reduced avatar for personal chats
        backgroundColor: isSupport ? theme.colorScheme.primary : theme.colorScheme.primary.withOpacity(0.1),
        backgroundImage: (photoUrl != null && !isSupport) ? CachedNetworkImageProvider(photoUrl) : null,
        onBackgroundImageError: photoUrl != null ? (exception, stackTrace) {
          debugPrint('🖼️ Avatar: Failed to load $photoUrl: $exception');
        } : null,
        child: (photoUrl == null || isSupport)
            ? (isSupport
                ? const Icon(Icons.support_agent_rounded, color: Colors.white, size: 24)
                : Text(displayName[0].toUpperCase(),
                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)))
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              displayName,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: unreadCount > 0 || isHighlight ? FontWeight.bold : FontWeight.w600,
                fontSize: isSupport ? 15 : 14, // Slightly varied font size for hierarchy
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
          // Only show context row if it's NOT a generic user chat
          if (conversation.context != null && conversation.context!.type != 'user')
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
                // Only show context title if it's NOT a support chat (to avoid "UniHub Support" redundancy)
                if (conversation.context!.type != 'support') ...[
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
        color = Colors.grey.shade400;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        color = Colors.grey.shade400;
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = const Color(0xFF00FFFF); // High Glow Electric Cyan
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
