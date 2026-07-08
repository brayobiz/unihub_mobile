import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/campus_constants.dart';
import '../../../auth/shared/providers.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../domain/models/chat_context.dart';
import '../../shared/providers.dart';
import '../../../../core/utils/debouncer.dart';

class UserSearchScreen extends ConsumerStatefulWidget {
  const UserSearchScreen({super.key});

  @override
  ConsumerState<UserSearchScreen> createState() => _UserSearchScreenState();
}

class _UserSearchScreenState extends ConsumerState<UserSearchScreen> {
  final _searchController = TextEditingController();
  final _debouncer = Debouncer(milliseconds: 300);
  List<AppUser> _results = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debouncer.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _isLoading = false;
      });
      return;
    }

    setState(() => _isLoading = true);
    _debouncer.run(() async {
      final results = await ref.read(authRepositoryProvider).searchUsers(query);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: 'Search name, @username or email...',
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5), fontSize: 16),
            border: InputBorder.none,
          ),
          onChanged: _onSearchChanged,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                _onSearchChanged('');
              },
            ),
        ],
      ),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _results.isEmpty 
              ? _buildEmptyState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final user = _results[index];
                    if (user.uid == currentUserId) return const SizedBox.shrink();
                    
                    return ListTile(
                      onTap: () => _startChat(user),
                      leading: CircleAvatar(
                        backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                        child: user.photoUrl == null ? Text(user.fullName[0].toUpperCase()) : null,
                      ),
                      title: Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(
                        '${user.username != null ? '@${user.username} • ' : ''}${CampusConstants.getDisplayName(user.university)}',
                      ),
                      trailing: const Icon(Icons.chat_bubble_outline, size: 20),
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState() {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_search_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(
            _searchController.text.isEmpty ? 'Find people to connect' : 'No students found',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 16),
          ),
        ],
      ),
    );
  }

  void _startChat(AppUser otherUser) async {
    final currentUser = ref.read(appUserProvider).valueOrNull;
    if (currentUser == null) return;

    try {
      final chatContext = ChatContext(
        type: 'user',
        id: otherUser.uid,
        title: otherUser.fullName,
        thumbnail: otherUser.photoUrl,
      );

      final convId = await ref.read(chatRepositoryProvider).getOrCreateConversation(
        participantIds: [currentUser.uid, otherUser.uid],
        context: chatContext,
      );

      if (mounted) {
        context.pushReplacement('/chat', extra: {
          'conversationId': convId,
          'otherUserName': otherUser.fullName,
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
