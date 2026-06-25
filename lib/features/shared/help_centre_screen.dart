import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../auth/shared/providers.dart';
import '../chat/shared/providers.dart';

class HelpCentreScreen extends ConsumerWidget {
  const HelpCentreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help Centre')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Frequently Asked Questions', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildFaqItem('How do I buy an item?', 'You can contact the seller via the "Live Chat" button or "Contact Student" button (WhatsApp) to arrange a meetup on campus.'),
          _buildFaqItem('Is it safe?', 'UniHub is for students on the same campus. Always meet in public places like the library or cafeteria.'),
          _buildFaqItem('How do I boost my listing?', 'Go to "My Listings" and click the "Boost" button. This will pin your item to the top of the feed.'),
          _buildFaqItem('What is a Trust Score?', 'Your Trust Score (0-100%) is based on your ratings, verified university email, and community engagement.'),
          
          const SizedBox(height: 40),
          const Text('Still need help?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('Our support team is available from 8 AM to 8 PM.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 20),
          
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.blue.shade100)),
            child: InkWell(
              onTap: () => _startSupportChat(context, ref),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: Colors.blue.shade50,
                      radius: 25,
                      child: const Icon(Icons.chat_bubble_outline, color: Colors.blue),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Chat with Support', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          Text('Typical response time: 5 mins', style: TextStyle(color: Colors.grey, fontSize: 13)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          const Card(
            child: ListTile(
              leading: Icon(Icons.email_outlined),
              title: Text('support@unihub.com'),
              subtitle: Text('For complex inquiries'),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _startSupportChat(BuildContext context, WidgetRef ref) async {
    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    try {
      final conversationId = await ref.read(chatRepositoryProvider).getSupportConversation(user.uid);
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

  Widget _buildFaqItem(String question, String answer) {
    return ExpansionTile(
      title: Text(question, style: const TextStyle(fontWeight: FontWeight.w600)),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(answer, style: const TextStyle(color: Colors.blueGrey)),
        ),
      ],
    );
  }
}
