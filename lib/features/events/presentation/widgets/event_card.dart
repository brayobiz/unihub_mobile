import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/core/widgets/optimized_image.dart';
import '../../domain/models/event.dart';
import '../../domain/models/organizer.dart';
import '../../shared/providers.dart';

class EventCard extends ConsumerWidget {
  final Event event;
  final int index;

  const EventCard({
    super.key,
    required this.event,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final organizerAsync = ref.watch(organizerProvider(event.organizerId));

    return RepaintBoundary(
      child: Semantics(
        label: 'Event card for ${event.title}',
        hint: 'Double tap to view event details',
        child: GestureDetector(
          onTap: () => context.push('/events/${event.id}'),
          child: Container(
            width: 280,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Image Section
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                      child: Container(
                        height: 160,
                        width: double.infinity,
                        color: theme.colorScheme.primary.withValues(alpha: 0.05),
                        child: event.imageUrls.isNotEmpty
                            ? OptimizedImage(
                                imageUrl: event.imageUrls.first,
                                thumbnailWidth: 500,
                              )
                            : Center(
                                child: Icon(
                                  Icons.event_available_outlined,
                                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                                  size: 48,
                                ),
                              ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: _buildStatusBadge(event),
                    ),
                    Positioned(
                      bottom: 12,
                      right: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          DateFormat('MMM dd').format(event.startAt).toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                // Info Section
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.access_time_rounded, size: 14, color: theme.colorScheme.primary, semanticLabel: 'Start time'),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('h:mm a').format(event.startAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(Icons.location_on_rounded, size: 14, color: AppColors.error, semanticLabel: 'Location'),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              event.venue.address ?? 'TBA',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(Icons.people_outline, size: 14, color: Colors.grey, semanticLabel: 'RSVP count'),
                          const SizedBox(width: 4),
                          Text(
                            '${event.currentAttendeeCount} Going',
                            style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                          if (event.maxCapacity != null && event.currentAttendeeCount >= event.maxCapacity!) ...[
                            const SizedBox(width: 8),
                            Text(
                              '• FULL',
                              style: TextStyle(fontSize: 11, color: AppColors.error, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      organizerAsync.when(
                        data: (organizer) => Row(
                          children: [
                            CircleAvatar(
                              radius: 10,
                              backgroundImage: organizer?.logoUrl != null ? CachedNetworkImageProvider(organizer!.logoUrl!) : null,
                              child: organizer?.logoUrl == null ? Text(organizer?.name.isNotEmpty == true ? organizer!.name[0].toUpperCase() : 'O', style: const TextStyle(fontSize: 8)) : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                organizer?.name ?? 'Unknown Organizer',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                            if (organizer?.verificationStatus == OrganizerVerificationStatus.verified || 
                                organizer?.verificationStatus == OrganizerVerificationStatus.official)
                              const Icon(Icons.verified_rounded, size: 14, color: AppColors.success, semanticLabel: 'Verified organizer'),
                          ],
                        ),
                        loading: () => const SizedBox(height: 20),
                        error: (_, __) => const SizedBox(height: 20),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(Event event) {
    String label;
    Color color;

    if (event.status == EventStatus.live) {
      label = 'LIVE NOW';
      color = AppColors.error;
    } else if (event.status == EventStatus.scheduled) {
      label = 'UPCOMING';
      color = AppColors.secondary;
    } else {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
