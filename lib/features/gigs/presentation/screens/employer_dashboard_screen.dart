import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/gig_application.dart';
import '../../shared/providers.dart';
import '../../../../widgets/notification_badge.dart';

final employerApplicationsProvider = StreamProvider<List<GigApplication>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(gigsRepositoryProvider).watchApplicationsForEmployer(user.uid);
});

class EmployerDashboardScreen extends ConsumerStatefulWidget {
  const EmployerDashboardScreen({super.key});

  @override
  ConsumerState<EmployerDashboardScreen> createState() => _EmployerDashboardScreenState();
}

class _EmployerDashboardScreenState extends ConsumerState<EmployerDashboardScreen> {
  ApplicationStatus? _selectedFilter;

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(employerApplicationsProvider);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Employer Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: const [
          NotificationBadge(module: 'gig'),
          SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips Row
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _filterChip(null, 'All'),
                const SizedBox(width: 8),
                _filterChip(ApplicationStatus.pending, 'Pending'),
                const SizedBox(width: 8),
                _filterChip(ApplicationStatus.accepted, 'Accepted'),
                const SizedBox(width: 8),
                _filterChip(ApplicationStatus.rejected, 'Rejected'),
              ],
            ),
          ),

          // Applications List
          Expanded(
            child: appsAsync.when(
              data: (apps) {
                final filteredApps = _selectedFilter == null
                    ? apps
                    : apps.where((a) => a.status == _selectedFilter).toList();

                if (filteredApps.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.folder_open_outlined, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No applications found.', style: TextStyle(color: Colors.grey.shade600)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredApps.length,
                  itemBuilder: (context, index) {
                    final app = filteredApps[index];
                    return _applicationCard(app);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(ApplicationStatus? status, String label) {
    final isSelected = _selectedFilter == status;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: Colors.indigo,
      onSelected: (val) {
        if (val) {
          setState(() => _selectedFilter = status);
        }
      },
    );
  }

  Widget _applicationCard(GigApplication app) {
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
                CircleAvatar(
                  backgroundColor: Colors.indigo.shade50,
                  child: Text(app.fullName[0].toUpperCase(), style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Text('Gig: ${app.gigTitle}', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    app.status.name.toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            Text(
              'Cover Letter:',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade700, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              app.coverLetter,
              style: TextStyle(color: Colors.grey.shade800, height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            
            if (app.portfolioLink != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.link, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      app.portfolioLink!,
                      style: const TextStyle(color: Colors.indigo, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            
            const Divider(height: 32),
            
            // Action Buttons
            Row(
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    if (app.conversationId != null && app.conversationId!.isNotEmpty) {
                      context.push('/chat', extra: {
                        'conversationId': app.conversationId,
                        'otherUserName': app.fullName,
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Conversation not found')),
                      );
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_outline),
                  label: const Text('Reply & Chat'),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const Spacer(),
                if (app.status == ApplicationStatus.pending) ...[
                  IconButton(
                    onPressed: () {
                      ref.read(gigsRepositoryProvider).updateApplicationStatus(app.id, ApplicationStatus.rejected);
                    },
                    icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () async {
                      await ref.read(gigsRepositoryProvider).updateApplicationStatus(app.id, ApplicationStatus.accepted);
                      if (mounted && app.conversationId != null) {
                        context.push('/chat', extra: {
                          'conversationId': app.conversationId,
                          'otherUserName': app.fullName,
                        });
                      }
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('Accept'),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.green,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
