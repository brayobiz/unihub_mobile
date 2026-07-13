import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/shared/providers.dart';
import '../chat/shared/providers.dart';
import '../admin/shared/providers.dart';

class HelpCentreScreen extends ConsumerWidget {
  const HelpCentreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settingsAsync = ref.watch(systemSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Help Center')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Frequently Asked Questions', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildFaqItem(context, 'How do I buy an item?', 'You can contact the seller via the "Messenger" button or "Contact Student" button (WhatsApp) to arrange a meetup on campus.'),
          _buildFaqItem(context, 'Is it safe?', 'UniHub is for students on the same campus. Always meet in public places like the library or cafeteria and never pay before seeing the item.'),
          _buildFaqItem(context, 'How do I rent a house?', 'Browse the housing section and contact the "Housing Plug" (agent) via chat. We strongly advise against paying any "viewing fees" or deposits before seeing the property.'),
          _buildFaqItem(context, 'What is a "Verified Plug"?', 'Verified Plugs are housing agents who have undergone identity and campus affiliation checks by the UniHub team to ensure listing reliability.'),
          _buildFaqItem(context, 'How do I apply for Gigs?', 'Find a task in the Gigs section, click "Apply", and message the poster. Be clear about your skills and availability.'),
          _buildFaqItem(context, 'How do I boost my listing?', 'Go to "My Listings" and click the "Boost" button. This uses community points to pin your item to the top of the category for 24 hours.'),
          _buildFaqItem(context, 'What is a Trust Score?', 'Your Trust Score (0-100%) is a reputation metric based on your ratings, university email verification, and successful transactions.'),
          _buildFaqItem(context, 'How can I verify my identity?', 'Go to Settings > Trust & Verification. You can verify your Student ID, National ID, or Professional status to gain badges and trust.'),
          _buildFaqItem(context, 'Can I delete my account?', 'Yes. In Settings > Delete Account, you can trigger a permanent erasure of your profile, listings, and all personal data in compliance with data privacy laws.'),
          
          const SizedBox(height: 40),
          Text('Still need help?', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('Our support team is available from 8 AM to 8 PM.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 20),
          
          _buildActiveTickets(context, ref),
          
          Card(
            color: theme.colorScheme.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: theme.colorScheme.outlineVariant)),
            child: InkWell(
              onTap: () => _startSupportChat(context, ref),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                      radius: 25,
                      child: Icon(Icons.chat_bubble_outline, color: theme.colorScheme.primary),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Chat with Support', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                          Text('Typical response time: 5 mins', style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 13)),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _startSupportChat(BuildContext context, WidgetRef ref) async {
    final authUser = ref.read(authStateProvider).valueOrNull;
    if (authUser == null || authUser.uid.isEmpty) return;

    try {
      final conversationId = await ref.read(chatRepositoryProvider).getSupportConversation(authUser.uid);
      if (context.mounted) {
        context.push('/chat', extra: {
          'conversationId': conversationId,
          'otherUserName': 'UniHub Support',
        });
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Widget _buildActiveTickets(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(authStateProvider).valueOrNull;
    if (authUser == null) return const SizedBox.shrink();

    final conversationsAsync = ref.watch(conversationsProvider(authUser.uid));
    final theme = Theme.of(context);

    return conversationsAsync.when(
      data: (conversations) {
        final supportTickets = conversations
            .where((c) => c.isSupport && (c.supportStatus != 'resolved' && c.supportStatus != 'closed'))
            .toList();

        if (supportTickets.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'My Open Tickets',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 12),
            ...supportTickets.map((ticket) {
              final unreadCount = ticket.unreadCounts[authUser.uid] ?? 0;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.1)),
                ),
                child: ListTile(
                  onTap: () => context.push('/chat', extra: {
                    'conversationId': ticket.id,
                    'otherUserName': 'UniHub Support',
                  }),
                  leading: CircleAvatar(
                    backgroundColor: theme.colorScheme.primary,
                    child: const Icon(Icons.support_agent_rounded, color: Colors.white, size: 20),
                  ),
                  title: Text(
                    'Support Session',
                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  ),
                  subtitle: Text(
                    ticket.lastMessage ?? 'Waiting for assistant...',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  trailing: unreadCount > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: theme.colorScheme.primary, borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            unreadCount.toString(),
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        )
                      : const Icon(Icons.chevron_right, size: 20),
                ),
              );
            }),
            const SizedBox(height: 24),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildFaqItem(BuildContext context, String question, String answer) {
    final theme = Theme.of(context);
    return ExpansionTile(
      title: Text(question, style: TextStyle(fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(answer, style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        ),
      ],
    );
  }
}
