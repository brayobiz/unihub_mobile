import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/core/constants/campus_constants.dart';
import 'package:unihub_mobile/features/admin/shared/providers.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/campus_filter/shared/providers.dart';
import 'package:unihub_mobile/features/events/domain/models/event.dart';
import '../layout/admin_layout.dart';

class EventApprovalScreen extends ConsumerStatefulWidget {
  const EventApprovalScreen({super.key});

  @override
  ConsumerState<EventApprovalScreen> createState() => _EventApprovalScreenState();
}

class _EventApprovalScreenState extends ConsumerState<EventApprovalScreen> {
  final Set<String> _selectedIds = {};
  bool _isProcessing = false;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _approveEvents(List<Event> events) async {
    final selected = events.where((e) => _selectedIds.contains(e.id)).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No events selected')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Approve Events'),
        content: Text('Approve ${selected.length} event(s)? Organizers will be notified immediately.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Approve')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      final admin = ref.read(appUserProvider).valueOrNull;
      if (admin == null) throw Exception('Admin session not found');

      final repository = ref.read(adminRepositoryProvider);
      await repository.bulkApproveEvents(
        eventIds: selected.map((e) => e.id).toList(),
        adminId: admin.uid,
        reason: 'Event approved and published',
      );

      if (mounted) {
        setState(() {
          _selectedIds.clear();
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Approved ${selected.length} event(s)'),
            backgroundColor: AppColors.success,
          ),
        );
        await ref.refresh(pendingEventsProvider(null).future);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _rejectEvents(List<Event> events) async {
    final selected = events.where((e) => _selectedIds.contains(e.id)).toList();
    if (selected.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No events selected')),
      );
      return;
    }

    final controller = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject Events'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Provide a reason for rejecting ${selected.length} event(s):'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'E.g., Event details violate community guidelines',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );

    if (reason == null || reason.isEmpty) return;

    setState(() => _isProcessing = true);
    try {
      final admin = ref.read(appUserProvider).valueOrNull;
      if (admin == null) throw Exception('Admin session not found');

      final repository = ref.read(adminRepositoryProvider);
      await repository.bulkRejectEvents(
        eventIds: selected.map((e) => e.id).toList(),
        adminId: admin.uid,
        reason: reason,
      );

      if (mounted) {
        setState(() {
          _selectedIds.clear();
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Rejected ${selected.length} event(s)'),
            backgroundColor: AppColors.warning,
          ),
        );
        await ref.refresh(pendingEventsProvider(null).future);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final campusId = ref.watch(effectiveCampusFilterProvider);
    final eventsAsync = ref.watch(pendingEventsProvider(campusId));
    final theme = Theme.of(context);

    return AdminLayout(
      title: 'Event Approvals',
      child: eventsAsync.when(
        data: (events) => Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              color: theme.colorScheme.surface,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Pending Events',
                              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${events.length} event(s) awaiting review',
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      if (_selectedIds.isNotEmpty)
                        Chip(
                          label: Text('${_selectedIds.length} selected'),
                          backgroundColor: AppColors.primary.withAlpha(30),
                        ),
                    ],
                  ),
                  if (events.isNotEmpty && _selectedIds.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: _isProcessing ? null : () => _approveEvents(events),
                            child: const Text('✅ Approve Selected'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: _isProcessing ? null : () => _rejectEvents(events),
                            child: const Text('❌ Reject Selected'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Events List
            Expanded(
              child: events.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.event_available_outlined, size: 64, color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(height: 16),
                          Text(
                            'No pending events',
                            style: theme.textTheme.titleMedium,
                          ),
                          Text(
                            'All submitted events have been reviewed',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: events.length,
                      itemBuilder: (context, index) {
                        final event = events[index];
                        return _EventApprovalCard(
                          event: event,
                          isSelected: _selectedIds.contains(event.id),
                          onSelectionChanged: (selected) {
                            _toggleSelection(event.id);
                          },
                          onApprove: () async => _approveEvents(events),
                          onReject: () async => _rejectEvents(events),
                          isProcessing: _isProcessing,
                        );
                      },
                    ),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: AppColors.error),
              const SizedBox(height: 16),
              Text('Error: $err'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => ref.refresh(pendingEventsProvider(campusId)),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventApprovalCard extends StatelessWidget {
  final Event event;
  final bool isSelected;
  final Function(bool) onSelectionChanged;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final bool isProcessing;

  const _EventApprovalCard({
    required this.event,
    required this.isSelected,
    required this.onSelectionChanged,
    required this.onApprove,
    required this.onReject,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormatter = DateFormat('MMM d, y • h:mm a');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => onSelectionChanged(!isSelected),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with checkbox
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Checkbox(
                    value: isSelected,
                    onChanged: (_) => onSelectionChanged(!isSelected),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'By: ${event.organizerId} • ${CampusConstants.getDisplayName(event.campusId)}',
                          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Event details
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    dateFormatter.format(event.startAt),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      event.venue.address ?? 'Location not specified',
                      style: theme.textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    event.description,
                    style: theme.textTheme.bodySmall,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              // Action buttons (when selected)
              if (isSelected) ...[
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: isProcessing ? null : onApprove,
                        child: const Text('Approve'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonal(
                        onPressed: isProcessing ? null : onReject,
                        child: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

