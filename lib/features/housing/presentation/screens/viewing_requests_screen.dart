import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/housing/shared/providers.dart';
import 'package:unihub_mobile/features/housing/domain/models/viewing_request.dart';
import '../../../../core/utils/date_formatter.dart';

class ViewingRequestsScreen extends ConsumerWidget {
  const ViewingRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(appUserProvider).valueOrNull;
    if (user == null) return const Scaffold(body: Center(child: Text('Please log in')));

    final isPlug = user.verifiedRoles.contains('housePlug');
    
    // We watch both, as a plug can also be a student looking for housing
    final plugRequestsAsync = ref.watch(plugViewingRequestsProvider(user.uid));
    final studentRequestsAsync = ref.watch(studentViewingRequestsProvider(user.uid));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text('Viewing Requests', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: DefaultTabController(
        length: isPlug ? 2 : 1,
        child: Column(
          children: [
            if (isPlug)
              TabBar(
                labelColor: theme.colorScheme.primary,
                unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
                indicatorColor: theme.colorScheme.primary,
                tabs: const [
                  Tab(text: 'Incoming (As Plug)'),
                  Tab(text: 'My Requests'),
                ],
              ),
            Expanded(
              child: TabBarView(
                physics: isPlug ? null : const NeverScrollableScrollPhysics(),
                children: [
                  if (isPlug)
                    _RequestsList(
                      requestsAsync: plugRequestsAsync,
                      isPlugView: true,
                    ),
                  _RequestsList(
                    requestsAsync: studentRequestsAsync,
                    isPlugView: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RequestsList extends ConsumerWidget {
  final AsyncValue<List<ViewingRequest>> requestsAsync;
  final bool isPlugView;

  const _RequestsList({
    required this.requestsAsync,
    required this.isPlugView,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return requestsAsync.when(
      data: (requests) {
        if (requests.isEmpty) {
          return _buildEmptyState(context);
        }

        final pending = requests.where((r) => r.status == ViewingRequestStatus.pending).toList();
        final upcoming = requests.where((r) => r.status == ViewingRequestStatus.confirmed || r.status == ViewingRequestStatus.rescheduled).toList();
        final history = requests.where((r) => r.status == ViewingRequestStatus.cancelled || r.status == ViewingRequestStatus.completed).toList();

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (pending.isNotEmpty) ...[
              _buildSectionHeader('Pending', AppColors.warning),
              ...pending.map((r) => _RequestCard(request: r, isPlugView: isPlugView)),
              const SizedBox(height: 24),
            ],
            if (upcoming.isNotEmpty) ...[
              _buildSectionHeader('Upcoming', AppColors.success),
              ...upcoming.map((r) => _RequestCard(request: r, isPlugView: isPlugView)),
              const SizedBox(height: 24),
            ],
            if (history.isNotEmpty) ...[
              _buildSectionHeader('History', Colors.grey),
              ...history.map((r) => _RequestCard(request: r, isPlugView: isPlugView)),
            ],
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, left: 4),
      child: Row(
        children: [
          Container(width: 4, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 0.5)),
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
          Icon(Icons.calendar_today_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.3)),
          const SizedBox(height: 16),
          Text(
            isPlugView ? 'No incoming requests' : 'No sent requests',
            style: const TextStyle(fontWeight: FontWeight.bold)
          ),
          Text(
            isPlugView ? 'Potential tenants will appear here' : 'Requests you make will appear here',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant)
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends ConsumerWidget {
  final ViewingRequest request;
  final bool isPlugView;

  const _RequestCard({
    required this.request,
    required this.isPlugView,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isPending = request.status == ViewingRequestStatus.pending;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildStatusBadge(request.status),
              Text(
                DateFormatter.formatRelative(request.createdAt),
                style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isPlugView ? request.studentName : 'Viewing Request',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 4),
          Text(
            'Property: ${request.listingTitle}',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
          ),
          if (!isPlugView)
            Text(
              'Plug: ${request.plugName}',
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.calendar_today_rounded, size: 14, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                DateFormat('EEEE, MMM d, y').format(request.preferredDate),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
          if (request.notes != null && request.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Notes: ${request.notes}',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
          if (isPlugView && isPending) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _updateStatus(ref, request.id, ViewingRequestStatus.cancelled),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => _updateStatus(ref, request.id, ViewingRequestStatus.confirmed),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.success,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Confirm'),
                  ),
                ),
              ],
            ),
          ] else if (isPlugView && request.status == ViewingRequestStatus.confirmed) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _updateStatus(ref, request.id, ViewingRequestStatus.completed),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Mark as Completed'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ViewingRequestStatus status) {
    Color color;
    switch (status) {
      case ViewingRequestStatus.pending:
        color = AppColors.warning;
        break;
      case ViewingRequestStatus.confirmed:
      case ViewingRequestStatus.rescheduled:
        color = AppColors.success;
        break;
      case ViewingRequestStatus.cancelled:
        color = AppColors.error;
        break;
      case ViewingRequestStatus.completed:
        color = Colors.blue;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
      ),
    );
  }

  void _updateStatus(WidgetRef ref, String requestId, ViewingRequestStatus status) {
    ref.read(housingRepositoryProvider).updateViewingRequestStatus(requestId, status);
  }
}
