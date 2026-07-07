import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:unihub_mobile/core/constants/campus_constants.dart';
import '../../../auth/shared/providers.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../domain/models/conversation.dart';
import '../../domain/models/chat_context.dart';
import '../../domain/models/message.dart';
import '../../shared/providers.dart';
import '../../../../widgets/skeleton_loader.dart';

class ShareToChatScreen extends ConsumerStatefulWidget {
  final ChatContext shareContext;

  const ShareToChatScreen({super.key, required this.shareContext});

  @override
  ConsumerState<ShareToChatScreen> createState() => _ShareToChatScreenState();
}

class _ShareToChatScreenState extends ConsumerState<ShareToChatScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _isSharing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).valueOrNull;
    if (user == null) return const Scaffold(body: Center(child: Text('Please login')));

    final conversationsAsync = ref.watch(conversationsProvider(user.uid));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Share to UniHub Chat', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  if (widget.shareContext.thumbnail != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(widget.shareContext.thumbnail!, width: 40, height: 40, fit: BoxFit.cover),
                    )
                  else
                    Icon(Icons.share, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sharing ${widget.shareContext.type}:', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                        Text(widget.shareContext.title, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search people or chats...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _searchQuery.isEmpty 
              ? conversationsAsync.when(
                  data: (conversations) {
                    if (conversations.isEmpty) return _buildEmptyState();
                    return ListView.builder(
                      itemCount: conversations.length,
                      itemBuilder: (context, index) => _ConversationShareTile(
                        conversation: conversations[index],
                        currentUserId: user.uid,
                        onShare: (convId) => _handleShare(convId),
                        isSharing: _isSharing,
                      ),
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (err, _) => Center(child: Text('Error: $err')),
                )
              : _UserSearchList(
                  query: _searchQuery,
                  currentUserId: user.uid,
                  onShare: (userId) => _handleShareWithUser(userId),
                  isSharing: _isSharing,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 16),
          const Text('No recent conversations', style: TextStyle(color: Colors.grey)),
          const Text('Search for a user to start sharing!', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _handleShareWithUser(String otherUserId) async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) return;

      // 1. Get or create conversation
      final conversationId = await ref.read(chatRepositoryProvider).getOrCreateConversation(
        participantIds: [user.uid, otherUserId],
        context: widget.shareContext,
      );

      // 2. Send message - bypass isSharing check because we already set it
      await _handleShare(conversationId, bypassCheck: true);
    } catch (e) {
      if (mounted) {
        setState(() => _isSharing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to start chat: $e')));
      }
    }
  }

  Future<void> _handleShare(String conversationId, {bool bypassCheck = false}) async {
    if (!bypassCheck && _isSharing) return;
    if (!bypassCheck) setState(() => _isSharing = true);

    try {
      final user = ref.read(authStateProvider).valueOrNull;
      if (user == null) return;

      final message = Message(
        id: const Uuid().v4(),
        senderId: user.uid,
        content: 'I shared an ${widget.shareContext.type} with you: ${widget.shareContext.title}',
        timestamp: DateTime.now(),
        context: widget.shareContext,
        status: MessageStatus.sent,
      );

      await ref.read(chatRepositoryProvider).sendMessage(conversationId, message);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shared successfully!'), backgroundColor: Colors.green),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }
}

class _UserSearchList extends ConsumerWidget {
  final String query;
  final String currentUserId;
  final Function(String) onShare;
  final bool isSharing;

  const _UserSearchList({
    required this.query,
    required this.currentUserId,
    required this.onShare,
    required this.isSharing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final firestore = ref.watch(firestoreProvider);
    
    // We can use a simple StreamProvider or FutureProvider for searching users
    return StreamBuilder<QuerySnapshot>(
      stream: firestore.collection('users')
          .where('fullName', isGreaterThanOrEqualTo: query)
          .where('fullName', isLessThanOrEqualTo: '$query\uf8ff')
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Text('No users found matching "$query"', style: const TextStyle(color: Colors.grey)),
          );
        }

        final users = snapshot.data!.docs
            .where((doc) => doc.id != currentUserId)
            .map((doc) => AppUser.fromJson(doc.data() as Map<String, dynamic>))
            .toList();

        if (users.isEmpty) return const SizedBox.shrink();

        return ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                child: user.photoUrl == null ? Text(user.fullName[0].toUpperCase()) : null,
              ),
              title: Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(CampusConstants.getDisplayName(user.university)),
              trailing: ElevatedButton(
                onPressed: isSharing ? null : () => onShare(user.uid),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                child: const Text('Send'),
              ),
            );
          },
        );
      },
    );
  }
}

class _ConversationShareTile extends ConsumerWidget {
  final Conversation conversation;
  final String currentUserId;
  final Function(String) onShare;
  final bool isSharing;

  const _ConversationShareTile({
    required this.conversation,
    required this.currentUserId,
    required this.onShare,
    required this.isSharing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final otherUserId = conversation.participants.firstWhere((id) => id != currentUserId, orElse: () => '');
    final otherUserAsync = ref.watch(publicUserProvider(otherUserId));

    return otherUserAsync.when(
      data: (user) {
        if (user == null) return const SizedBox.shrink();
        return ListTile(
          leading: CircleAvatar(
            backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
            child: user.photoUrl == null ? Text(user.fullName[0].toUpperCase()) : null,
          ),
          title: Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(CampusConstants.getDisplayName(user.university)),
          trailing: ElevatedButton(
            onPressed: isSharing ? null : () => onShare(conversation.id),
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text('Send'),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
