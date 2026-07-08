import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import '../../shared/providers.dart';
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
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('My Events', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 24)),
        centerTitle: false,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: theme.colorScheme.primary,
          indicatorSize: TabBarIndicatorSize.label,
          indicatorWeight: 3,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          dividerColor: Colors.transparent,
          tabs: const [
            Tab(text: 'Timeline'),
            Tab(text: 'Going'),
            Tab(text: 'Saved'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildTimelineTab(),
          _buildEventList(ref.watch(userGoingEventsProvider), 'Going'),
          _buildEventList(ref.watch(userSavedEventsProvider), 'Saved'),
          _buildEventList(ref.watch(userPastEventsProvider), 'History'),
        ],
      ),
    );
  }

  Widget _buildTimelineTab() {
    final going = ref.watch(userGoingEventsProvider).valueOrNull ?? [];
    final saved = ref.watch(userSavedEventsProvider).valueOrNull ?? [];
    
    final now = DateTime.now();
    // Combine and sort future events
    final allUpcoming = [...going, ...saved]
      .where((e) => e.endAt.isAfter(now))
      .toList()
      ..sort((a, b) => a.startAt.compareTo(b.startAt));
    
    // Remove duplicates
    final seenIds = <String>{};
    final uniqueUpcoming = allUpcoming.where((e) => seenIds.add(e.id)).toList();

    if (uniqueUpcoming.isEmpty) {
      return _buildEmptyState('Timeline');
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      physics: const BouncingScrollPhysics(),
      itemCount: uniqueUpcoming.length,
      itemBuilder: (context, index) {
        final event = uniqueUpcoming[index];
        bool showDateHeader = true;
        
        if (index > 0) {
          final prevEvent = uniqueUpcoming[index - 1];
          if (prevEvent.startAt.day == event.startAt.day && 
              prevEvent.startAt.month == event.startAt.month) {
            showDateHeader = false;
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDateHeader) ...[
              if (index > 0) const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(bottom: 16, left: 4),
                child: Text(
                  _formatDateHeader(event.startAt),
                  style: TextStyle(
                    fontWeight: FontWeight.w900, 
                    fontSize: 14, 
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
            _MyEventListTile(event: event),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return 'TODAY';
    }
    final tomorrow = now.add(const Duration(days: 1));
    if (date.day == tomorrow.day && date.month == tomorrow.month && date.year == tomorrow.year) {
      return 'TOMORROW';
    }
    return DateFormat('EEEE, MMM d').format(date).toUpperCase();
  }

  Widget _buildEventList(AsyncValue<List<Event>> eventsAsync, String type) {
    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return _buildEmptyState(type);
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          physics: const BouncingScrollPhysics(),
          itemCount: events.length,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (context, index) => _MyEventListTile(event: events[index]),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildEmptyState(String type) {
    String message = '';
    IconData icon = Icons.event_available_outlined;
    
    if (type == 'Timeline') {
      message = 'Your schedule is clear. Browse your campus feed to find activities!';
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
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 60, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
            ),
            const SizedBox(height: 24),
            Text(
              'No $type Events',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.6), height: 1.5),
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
    final isPast = event.endAt.isBefore(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => context.push('/events/${event.id}'),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Stack(
                children: [
                  Hero(
                    tag: 'event_img_${event.id}_mine',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 90,
                        height: 90,
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: event.imageUrls.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: event.imageUrls.first, 
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const SizedBox.shrink(),
                              )
                            : const Icon(Icons.event, color: Colors.grey),
                      ),
                    ),
                  ),
                  if (isPast)
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.4),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.history_rounded, color: Colors.white, size: 24),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            event.title,
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${event.venue.address ?? 'On Campus'}',
                      style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.access_time_rounded, size: 14, color: theme.colorScheme.primary),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('h:mm a').format(event.startAt),
                            style: TextStyle(
                              fontSize: 12, 
                              fontWeight: FontWeight.w900, 
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}
