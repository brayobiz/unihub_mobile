import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/widgets/optimized_image.dart';
import '../../shared/providers.dart';
import '../../domain/models/event.dart';

class EventsDashboardOrchestrator extends ConsumerWidget {
  const EventsDashboardOrchestrator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(homepageEventsProvider);
    final now = DateTime.now();

    return eventsAsync.when(
      data: (data) {
        if (data.isEmpty) return const SizedBox.shrink();

        String todayTitle = 'Later Today on Campus';
        if (now.hour < 11) todayTitle = 'Happening Today';
        if (now.hour >= 18) todayTitle = 'Tomorrow on Campus';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (data.goingSoon.isNotEmpty) _UpcomingReminder(event: data.goingSoon.first),
            if (data.liveNow.isNotEmpty) _HorizontalEventSection(title: 'Happening Now ⚡', events: data.liveNow),
            if (data.today.isNotEmpty) _HorizontalEventSection(title: todayTitle, events: data.today),
            if (data.featured.isNotEmpty) _HorizontalEventSection(title: 'Don\'t Miss This ⭐', events: data.featured),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _UpcomingReminder extends StatelessWidget {
  final Event event;
  const _UpcomingReminder({required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final diff = event.startAt.difference(DateTime.now());
    final String timeLabel = diff.inHours > 0 
        ? 'Starts in ${diff.inHours}h ${diff.inMinutes % 60}m'
        : 'Starts in ${diff.inMinutes}m';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: InkWell(
        onTap: () => context.push('/events/${event.id}'),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.8)],
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.notifications_active_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your next event',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      event.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  timeLabel,
                  style: TextStyle(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HorizontalEventSection extends StatelessWidget {
  final String title;
  final List<Event> events;

  const _HorizontalEventSection({required this.title, required this.events});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/events'),
                  child: const Text('See All'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 250, // Slightly smaller than discovery for dashboard
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: events.length,
              itemBuilder: (context, index) {
                return _CompactEventCard(event: events[index]);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CompactEventCard extends StatelessWidget {
  final Event event;
  const _CompactEventCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => context.push('/events/${event.id}'),
        child: Container(
          width: 220,
          margin: const EdgeInsets.only(right: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Container(
                  height: 120,
                  width: double.infinity,
                  color: theme.colorScheme.primary.withValues(alpha: 0.05),
                  child: event.imageUrls.isNotEmpty
                      ? OptimizedImage(
                          imageUrl: event.imageUrls.first,
                          fit: BoxFit.cover,
                          thumbnailWidth: 400,
                        )
                      : const Icon(Icons.event_available_outlined, color: Colors.grey),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 12, color: theme.colorScheme.primary),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('h:mm a').format(event.startAt),
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            event.venue.address ?? 'TBA',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// Performance optimized events dashboard version RC-2
