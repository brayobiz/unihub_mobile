import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/gig_application.dart';
import '../../shared/providers.dart';

final freelancerApplicationsProvider = StreamProvider<List<GigApplication>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(gigsRepositoryProvider).watchApplicationsForFreelancer(user.uid);
});

class FreelancerApplicationsScreen extends ConsumerWidget {
  const FreelancerApplicationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(freelancerApplicationsProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('My Gig Applications', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: appsAsync.when(
        data: (apps) {
          if (apps.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined, size: 64, color: Colors.grey.shade300),
                  const SizedBox(height: 16),
                  Text(
                    'You haven\'t applied for any gigs yet.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => context.go('/gigs'),
                    child: const Text('Browse Gigs'),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: apps.length,
            itemBuilder: (context, index) {
              final app = apps[index];
              return _applicationCard(context, app);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _applicationCard(BuildContext context, GigApplication app) {
    Color statusColor = Colors.amber;
    if (app.status == ApplicationStatus.accepted) statusColor = Colors.green;
    if (app.status == ApplicationStatus.rejected) statusColor = Colors.red;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        app.gigTitle,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Status: ${app.status.name.toUpperCase()}',
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    app.status == ApplicationStatus.pending
                        ? Icons.timer_outlined
                        : (app.status == ApplicationStatus.accepted
                            ? Icons.check_circle_outline
                            : Icons.cancel_outlined),
                    color: statusColor,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            const Text(
              'Your Cover Letter:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              app.coverLetter,
              style: TextStyle(color: Colors.grey.shade800, height: 1.4),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            const Divider(height: 32),
            
            Row(
              children: [
                Text(
                  'Applied on ${app.createdAt.day}/${app.createdAt.month}/${app.createdAt.year}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
                const Spacer(),
                if (app.status == ApplicationStatus.accepted && app.conversationId != null)
                  FilledButton.icon(
                    onPressed: () {
                      context.push('/chat', extra: {
                        'conversationId': app.conversationId,
                        'otherUserName': 'Employer',
                      });
                    },
                    icon: const Icon(Icons.chat_bubble_outline, size: 18),
                    label: const Text('Open Chat'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
