import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/providers.dart';
import '../widgets/roommate_card.dart';
import '../../../auth/shared/providers.dart';
import '../../../chat/shared/providers.dart';
import '../../../chat/domain/models/chat_context.dart';
import '../../domain/models/roommate_profile.dart';

class RoommateFeedScreen extends ConsumerWidget {
  const RoommateFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final roommatesAsync = ref.watch(roommateProfilesProvider);
    final user = ref.watch(appUserProvider).valueOrNull;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text('Find Roommates', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline_rounded),
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Roommate Finder'),
                  content: const Text('Find fellow students to share housing costs with. Profiles show budget, preferred location, and lifestyle habits.'),
                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it'))],
                ),
              );
            },
          ),
        ],
      ),
      body: roommatesAsync.when(
        data: (profiles) {
          if (profiles.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people_outline_rounded, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                  const SizedBox(height: 16),
                  Text('No roommate profiles yet', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 8),
                  const Text('Be the first to list yours!'),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              final profile = profiles[index];
              return RoommateCard(
                profile: profile,
                onTap: () {
                  // Show detail or open chat
                  _showProfileDetail(context, profile, ref);
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-roommate'),
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Post My Profile'),
      ),
    );
  }

  void _showProfileDetail(BuildContext context, RoommateProfile profile, WidgetRef ref) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: profile.profileImage.isNotEmpty ? NetworkImage(profile.profileImage) : null,
                  child: profile.profileImage.isEmpty ? const Icon(Icons.person, size: 40) : null,
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(profile.name, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      Text('${profile.course} • Year ${profile.yearOfStudy}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text('About', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(profile.bio, style: const TextStyle(height: 1.5)),
            const SizedBox(height: 24),
            Text('Lifestyle', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profile.lifestyle.map<Widget>((l) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(l, style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold)),
              )).toList(),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: () async {
                  final currentUser = ref.read(appUserProvider).valueOrNull;
                  if (currentUser == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to contact student')));
                    return;
                  }

                  if (currentUser.uid == profile.userId) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This is your own profile.')));
                    return;
                  }

                  final chatContext = ChatContext(
                    type: 'roommate',
                    id: profile.id,
                    title: 'Roommate Finder: ${profile.name}',
                    thumbnail: profile.profileImage.isNotEmpty ? profile.profileImage : null,
                    metadata: {
                      'budget': profile.budget,
                      'campus': profile.campus,
                    },
                  );

                  final convId = await ref.read(chatRepositoryProvider).getOrCreateConversation(
                    participantIds: [currentUser.uid, profile.userId],
                    context: chatContext,
                  );

                  if (context.mounted) {
                    Navigator.pop(modalContext);
                    context.push('/chat', extra: {
                      'conversationId': convId,
                      'otherUserName': profile.name,
                      'context': chatContext,
                    });
                  }
                },
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Contact Student', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
