import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import '../../shared/providers.dart';
import '../widgets/event_card.dart';
import '../../domain/models/event.dart';

class MyEventsScreen extends ConsumerStatefulWidget {
  const MyEventsScreen({super.key});

  @override
  ConsumerState<MyEventsScreen> createState() => _MyEventsScreenState();
}

class _MyEventsScreenState extends ConsumerState<MyEventsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Events', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: Colors.grey,
          isScrollable: true,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: const [
            Tab(text: 'Upcoming'),
            Tab(text: 'Going'),
            Tab(text: 'Saved'),
            Tab(text: 'Past'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildUpcomingTimeline(),
          _buildEventList(ref.watch(userGoingEventsProvider), 'Going'),
          _buildEventList(ref.watch(userSavedEventsProvider), 'Saved'),
          _buildEventList(ref.watch(userPastEventsProvider), 'Past'),
        ],
      ),
    );
  }

  Widget _buildUpcomingTimeline() {
    final going = ref.watch(userGoingEventsProvider).valueOrNull ?? [];
    final saved = ref.watch(userSavedEventsProvider).valueOrNull ?? [];
    
    // Combine and sort
    final allUpcoming = [...going, ...saved]
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    
    // Remove duplicates
    final seenIds = <String>{};
    final uniqueUpcoming = allUpcoming.where((e) => seenIds.add(e.id)).toList();

    if (uniqueUpcoming.isEmpty) {
      return _buildEmptyState('Upcoming');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: uniqueUpcoming.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) => _MyEventListTile(event: uniqueUpcoming[index]),
    );
  }

  Widget _buildEventList(AsyncValue<List<Event>> eventsAsync, String type) {
    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return _buildEmptyState(type);
        }
        return ListView.separated(
          padding: const EdgeInsets.all(24),
          itemCount: events.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            // Reusing EventCard but maybe need a different layout for vertical list
            // For now, let's use a vertical variant or simple list tile
            final event = events[index];
            return _MyEventListTile(event: event);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildEmptyState(String type) {
    String message = '';
    IconData icon = Icons.event_available_outlined;
    
    if (type == 'Upcoming') {
      message = 'You have no events scheduled. Browse your campus feed to find activities!';
    } else if (type == 'Going') {
      message = 'You haven\'t marked yourself as "Going" to any events yet.';
    } else if (type == 'Saved') {
      message = 'You haven\'t saved any events yet.';
    } else {
      message = 'No past events found in your history.';
      icon = Icons.history_rounded;
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 24),
            Text(
              'No $type Events',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

class _MyEventListTile extends StatelessWidget {
  final Event event;
  const _MyEventListTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: InkWell(
        onTap: () => context.push('/events/${event.id}'),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 80,
                  height: 80,
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  child: event.imageUrls.isNotEmpty
                      ? Image.network(event.imageUrls.first, fit: BoxFit.cover)
                      : const Icon(Icons.event, color: Colors.grey),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${event.venue.address}',
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 12, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          '${event.startAt.day}/${event.startAt.month} @ ${event.startAt.hour}:${event.startAt.minute.toString().padLeft(2, '0')}',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
