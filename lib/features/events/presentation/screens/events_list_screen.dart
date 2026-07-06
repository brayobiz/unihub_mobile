import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/event.dart';
import '../../shared/providers.dart';
import '../widgets/event_card.dart';

enum EventListFilter { today, thisWeek, featured, live, category }

class EventsListScreen extends ConsumerWidget {
  final String title;
  final EventListFilter filter;
  final String? categoryId;

  const EventsListScreen({
    super.key,
    required this.title,
    required this.filter,
    this.categoryId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    
    AsyncValue<List<Event>> getEvents() {
      switch (filter) {
        case EventListFilter.today:
          return ref.watch(todayEventsProvider);
        case EventListFilter.thisWeek:
          return ref.watch(thisWeekEventsProvider);
        case EventListFilter.featured:
          return ref.watch(featuredEventsProvider);
        case EventListFilter.live:
          return ref.watch(liveEventsProvider);
        case EventListFilter.category:
          return ref.watch(eventsByCategoryProvider(categoryId ?? ''));
      }
    }

    final eventsAsync = getEvents();

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: eventsAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return _buildEmptyState(context);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: events.length,
            separatorBuilder: (_, __) => const SizedBox(height: 24),
            itemBuilder: (context, index) {
              final event = events[index];
              return _buildListEventCard(context, event);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildListEventCard(BuildContext context, Event event) {
    // We'll reuse EventCard logic but maybe layout it differently for list?
    // For consistency and speed, we'll use the existing EventCard but with a full width
    return SizedBox(
      width: double.infinity,
      child: EventCard(event: event, index: 0),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_rounded, size: 80, color: Colors.grey.withOpacity(0.3)),
          const SizedBox(height: 24),
          const Text(
            'No events found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
