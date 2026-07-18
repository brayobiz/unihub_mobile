import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import '../../domain/models/event.dart';
import '../../domain/models/organizer.dart';
import '../../domain/services/event_service.dart';
import '../../shared/providers.dart';

class ManageEventsScreen extends ConsumerWidget {
  final String organizerId;

  const ManageEventsScreen({super.key, required this.organizerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organizerAsync = ref.watch(organizerProvider(organizerId));
    final eventsAsync = ref.watch(organizerEventsProvider(organizerId));

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Events', style: TextStyle(fontWeight: FontWeight.bold)),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Live'),
              Tab(text: 'Past'),
            ],
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: organizerAsync.when(
          data: (organizer) {
            if (organizer == null) return const Center(child: Text('Organizer not found'));
            
            return eventsAsync.when(
              data: (events) {
                if (events.isEmpty) {
                  return _buildEmptyState(context, organizer);
                }

                final now = DateTime.now();
                final upcomingEvents = events.where((e) => e.startAt.isAfter(now)).toList();
                final liveEvents = events.where((e) => e.startAt.isBefore(now) && e.endAt.isAfter(now)).toList();
                final pastEvents = events.where((e) => e.endAt.isBefore(now)).toList();

                return TabBarView(
                  children: [
                    _buildEventList(context, ref, upcomingEvents, organizer, isPast: false, emptyMessage: 'No upcoming events'),
                    _buildEventList(context, ref, liveEvents, organizer, isPast: false, emptyMessage: 'No events are live right now'),
                    _buildEventList(context, ref, pastEvents, organizer, isPast: true, emptyMessage: 'No past events'),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(child: Text('Error: $err')),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            final organizer = organizerAsync.value;
            if (organizer != null) {
              context.push(
                '/organizers/$organizerId/events/create',
                extra: {'campusId': organizer.campusId},
              );
            }
          },
          label: const Text('New Event'),
          icon: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildEventList(BuildContext context, WidgetRef ref, List<Event> events, Organizer organizer, {required bool isPast, required String emptyMessage}) {
    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPast ? Icons.history_rounded : Icons.event_note_outlined, 
              size: 64, 
              color: Colors.grey.withOpacity(0.5)
            ),
            const SizedBox(height: 16),
            Text(
              emptyMessage,
              style: const TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: events.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _buildEventItem(context, ref, events[index], isPast: isPast),
    );
  }

  Widget _buildEventItem(BuildContext context, WidgetRef ref, Event event, {required bool isPast}) {
    final theme = Theme.of(context);
    return Opacity(
      opacity: isPast ? 0.7 : 1.0,
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        child: InkWell(
          onTap: () => context.push('/events/${event.id}'),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _buildStatusChip(event.status, isExpired: event.isExpired),
                    const Spacer(),
                    if (!isPast)
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        onPressed: () => context.push('/organizers/$organizerId/events/edit', extra: event),
                        visualDensity: VisualDensity.compact,
                      ),
                    IconButton(
                      icon: const Icon(Icons.more_vert, size: 20),
                      onPressed: () => _showMoreOptions(context, ref, event),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  event.title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM dd, HH:mm').format(event.startAt),
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                    const SizedBox(width: 16),
                    const Icon(Icons.people_outline, size: 14, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      '${event.currentAttendeeCount} RSVP',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(EventStatus status, {bool isExpired = false}) {
    Color color;
    String label = status.name.toUpperCase();
    
    if (isExpired && (status == EventStatus.approved || status == EventStatus.scheduled || status == EventStatus.live)) {
      color = Colors.black54;
      label = 'ENDED';
    } else {
      switch (status) {
        case EventStatus.draft: color = Colors.grey; break;
        case EventStatus.submitted: color = Colors.orange; break;
        case EventStatus.approved: color = Colors.blue; break;
        case EventStatus.scheduled: color = Colors.indigo; break;
        case EventStatus.live: color = Colors.green; break;
        case EventStatus.ended: color = Colors.black54; break;
        case EventStatus.archived: color = Colors.brown; break;
        case EventStatus.cancelled:
        case EventStatus.removed:
          color = AppColors.error; 
          break;
      }
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10, letterSpacing: 0.5),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, Organizer organizer) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_note_outlined, size: 80, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            const Text(
              'No events found',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Start hosting events on campus to build your community and engage with students.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
                onPressed: () => context.push('/organizers/${organizer.id}/events/create'),
                icon: const Icon(Icons.add),
                label: const Text('Create Your First Event'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showMoreOptions(BuildContext context, WidgetRef ref, Event event) {
    final service = ref.read(eventServiceProvider);
    final userId = ref.read(appUserProvider).valueOrNull?.uid ?? '';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (event.status == EventStatus.draft)
                ListTile(
                  leading: const Icon(Icons.send_rounded, color: Colors.blue),
                  title: const Text('Submit for Review'),
                  subtitle: const Text('Publish this event to your campus.'),
                  onTap: () async {
                    Navigator.pop(context);
                    try {
                      await service.submitEvent(event.id, userId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Event submitted for review!'), backgroundColor: AppColors.success),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
                        );
                      }
                    }
                  },
                ),
              if (event.status == EventStatus.approved || event.status == EventStatus.scheduled || event.status == EventStatus.live)
                ListTile(
                  leading: const Icon(Icons.people_outline_rounded),
                  title: const Text('View Attendees'),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/events/${event.id}/attendees');
                  },
                ),
              if (event.status == EventStatus.approved || event.status == EventStatus.scheduled || event.status == EventStatus.live)
                ListTile(
                  leading: const Icon(Icons.cancel_outlined, color: AppColors.error),
                  title: const Text('Cancel Event', style: TextStyle(color: AppColors.error)),
                  onTap: () {
                    Navigator.pop(context);
                    _showCancelDialog(context, service, event, userId);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.archive_outlined),
                title: const Text('Archive'),
                onTap: () async {
                  Navigator.pop(context);
                  await service.archiveEvent(event.id, userId);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Delete Permanently', style: TextStyle(color: AppColors.error)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete Event?'),
                      content: const Text('This will permanently remove the event. This action cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                        TextButton(
                          onPressed: () => Navigator.pop(context, true), 
                          child: const Text('Delete', style: TextStyle(color: AppColors.error))
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await service.deleteEvent(event.id, userId);
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined),
                title: const Text('Share Event'),
                onTap: () {
                  Navigator.pop(context);
                  // Share logic
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context, EventService service, Event event, String userId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Event?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This will notify all RSVP\'d students. Please provide a reason.'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'e.g. Venue double-booked',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Keep Event')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isEmpty) return;
              
              Navigator.pop(context);
              await service.cancelEvent(event.id, userId, reason);
              
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Event cancelled and students notified.')),
                );
              }
            },
            child: const Text('Cancel Event'),
          ),
        ],
      ),
    );
  }
}
