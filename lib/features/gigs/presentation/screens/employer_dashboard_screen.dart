import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/gig_application.dart';
import '../../shared/providers.dart';
import '../../../../widgets/notification_badge.dart';
import 'package:unihub_mobile/features/ads/ads_module.dart';

final employerApplicationsProvider = StreamProvider<List<GigApplication>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(gigsRepositoryProvider).watchApplicationsForEmployer(user.uid).map((apps) {
    if (user.blockedUids.isEmpty) return apps;
    return apps.where((a) => !user.blockedUids.contains(a.freelancerId)).toList();
  });
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
    final theme = Theme.of(context);
    final appsAsync = ref.watch(employerApplicationsProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      bottomNavigationBar: const SafeArea(
        top: false,
        child: BannerAdWidget(),
      ),
      appBar: AppBar(
        title: Text('Employer Dashboard', 
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          )),
        backgroundColor: theme.colorScheme.surface,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
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
            color: theme.colorScheme.surface,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _filterChip(context, null, 'All'),
                const SizedBox(width: 8),
                _filterChip(context, ApplicationStatus.pending, 'Pending'),
                const SizedBox(width: 8),
                _filterChip(context, ApplicationStatus.accepted, 'Accepted'),
                const SizedBox(width: 8),
                _filterChip(context, ApplicationStatus.rejected, 'Rejected'),
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
                        Icon(Icons.folder_open_outlined, size: 64, color: theme.colorScheme.outlineVariant),
                        const SizedBox(height: 16),
                        Text('No applications found.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredApps.length,
                  itemBuilder: (context, index) {
                    final app = filteredApps[index];
                    return _applicationCard(context, app);
                  },
                );
              },
              loading: () => Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
              error: (err, _) => Center(child: Text('Error: $err', style: TextStyle(color: theme.colorScheme.error))),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(BuildContext context, ApplicationStatus? status, String label) {
    final theme = Theme.of(context);
    final isSelected = _selectedFilter == status;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.white : theme.colorScheme.onSurface,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      selectedColor: theme.colorScheme.primary,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      onSelected: (val) {
        if (val) {
          setState(() => _selectedFilter = status);
        }
      },
    );
  }

  Widget _applicationCard(BuildContext context, GigApplication app) {
    final theme = Theme.of(context);
    Color statusColor = Colors.amber;
    if (app.status == ApplicationStatus.accepted) statusColor = Colors.green;
    if (app.status == ApplicationStatus.rejected) statusColor = theme.colorScheme.error;

    return Card(
      elevation: 0,
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
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
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  child: Text(app.fullName[0].toUpperCase(), style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(app.fullName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface)),
                      Text('Gig: ${app.gigTitle}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
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
              style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              app.coverLetter,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.4),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            
            if (app.portfolioLink != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(Icons.link, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      app.portfolioLink!,
                      style: TextStyle(color: theme.colorScheme.primary, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            
            Divider(height: 32, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            
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
                    foregroundColor: theme.colorScheme.primary,
                    side: BorderSide(color: theme.colorScheme.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const Spacer(),
                if (app.status == ApplicationStatus.pending) ...[
                  IconButton(
                    onPressed: () {
                      ref.read(gigsRepositoryProvider).updateApplicationStatus(app.id, ApplicationStatus.rejected);
                    },
                    icon: Icon(Icons.cancel_outlined, color: theme.colorScheme.error),
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
