import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/conversation.dart';
import '../../domain/models/message.dart';
import '../../shared/providers.dart';

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
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null) return const Scaffold(body: Center(child: Text('Please login to view chats')));

    final conversationsAsync = ref.watch(conversationsProvider(user.uid));

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        title: Text(
          'Messages',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          _buildSearchBox(),
          Expanded(
            child: conversationsAsync.when(
              data: (conversations) {
                final filtered = conversations.where((c) {
                  final titleMatch = c.context.title.toLowerCase().contains(_searchQuery.toLowerCase());
                  // In a real app, we'd also search participant names, but that requires more data loading here
                  return titleMatch;
                }).toList();

                if (filtered.isEmpty) {
                  return _buildEmptyState();
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
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBox() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (val) => setState(() => _searchQuery = val),
          decoration: InputDecoration(
            hintText: 'Search conversations...',
            hintStyle: GoogleFonts.plusJakartaSans(color: Colors.grey, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: Colors.grey),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No conversations yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Messages from marketplace and housing\nwill appear here.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13,
              color: Colors.grey.shade500,
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
          leading: Stack(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: Colors.indigo.shade50,
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? Text(displayName[0].toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo))
                    : null,
              ),
              if (otherUser?.isOnline == true)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  displayName,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.w600,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                _formatTime(conversation.lastMessageTime),
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  color: unreadCount > 0 ? Colors.indigo : Colors.grey.shade500,
                  fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: _getContextColor(conversation.context.type).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      conversation.context.type.toUpperCase(),
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: _getContextColor(conversation.context.type),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      conversation.context.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: Colors.grey.shade600,
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
                      _buildStatusIcon(conversation.lastMessageStatus ?? MessageStatus.sent),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        conversation.lastMessage ?? 'No messages yet',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 13,
                          color: unreadCount > 0 ? Colors.black87 : Colors.grey.shade600,
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
                        color: Colors.indigo,
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

  Widget _buildStatusIcon(MessageStatus status) {
    IconData icon;
    Color color = Colors.grey;
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
        color = Colors.blue;
        break;
    }
    return Icon(icon, size: 14, color: color);
  }

  Color _getContextColor(String type) {
    switch (type.toLowerCase()) {
      case 'marketplace':
        return Colors.orange;
      case 'housing':
        return Colors.blue;
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
    return ListTile(
      leading: CircleAvatar(radius: 28, backgroundColor: Colors.grey.shade200),
      title: Container(height: 12, width: 100, color: Colors.grey.shade200),
      subtitle: Container(height: 10, width: 150, color: Colors.grey.shade100, margin: const EdgeInsets.only(top: 8)),
    );
  }
}
