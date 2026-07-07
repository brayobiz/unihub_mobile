import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/core/constants/campus_constants.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import '../../shared/providers.dart';
import '../../domain/models/event.dart';
import '../../domain/models/event_category.dart';
import '../../domain/models/organizer.dart';
import '../../domain/models/attendance.dart';
import '../../presentation/controllers/organizer_profile_controller.dart';
import 'package:unihub_mobile/features/chat/domain/models/chat_context.dart';

class EventDetailScreen extends ConsumerWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final eventAsync = ref.watch(eventProvider(eventId));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: eventAsync.when(
        data: (event) {
          if (event == null) return const Center(child: Text('Event not found'));
          return Stack(
            children: [
              _buildContent(context, event, theme, ref),
              _buildRegistrationBar(context, event, theme, ref),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Event event, ThemeData theme, WidgetRef ref) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSliverAppBar(context, event, ref),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 140),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildHeader(event, theme, ref),
              const SizedBox(height: 32),
              
              _buildSectionHeader(context, 'When & Where', Icons.calendar_today_rounded),
              const SizedBox(height: 16),
              _buildInfoRow(Icons.access_time_filled_rounded, _formatDateTime(event.startAt, event.endAt)),
              const SizedBox(height: 16),
              _buildInfoRow(Icons.location_on_rounded, event.venue.address ?? 'TBA'),
              if (event.venueRoom.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 40, top: 4),
                  child: Text(event.venueRoom, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey, fontWeight: FontWeight.w500)),
                ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.only(left: 40),
                child: TextButton.icon(
                  onPressed: () {
                    // Navigate to Map and center on event
                    context.push('/campus-map?eventId=${event.id}');
                  },
                  icon: const Icon(Icons.map_outlined, size: 18),
                  label: const Text('View on Campus Map', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 32),
              
              _buildOrganizerSection(context, event.organizerId, ref),
              
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 32),
              
              _buildSectionHeader(context, 'About Event', Icons.description_rounded),
              const SizedBox(height: 16),
              Text(
                event.description, 
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.7, color: theme.colorScheme.onSurface.withValues(alpha: 0.8)),
              ),
              
              const SizedBox(height: 32),
              _buildTags(event.tags, theme),
              
              const SizedBox(height: 32),
              _buildMetaInfo(event, theme),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSliverAppBar(BuildContext context, Event event, WidgetRef ref) {
    return SliverAppBar(
      expandedHeight: 350,
      pinned: true,
      elevation: 0,
      stretch: true,
      backgroundColor: Theme.of(context).colorScheme.primary,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            event.imageUrls.isNotEmpty
                ? CachedNetworkImage(imageUrl: event.imageUrls.first, fit: BoxFit.cover)
                : Container(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1), 
                    child: const Icon(Icons.event, size: 100, color: Colors.white)
                  ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black26, Colors.transparent, Colors.black54],
                ),
              ),
            ),
          ],
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.black26,
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.black26,
            child: IconButton(
              icon: const Icon(Icons.report_gmailerrorred_rounded, color: Colors.white, size: 18),
              onPressed: () => _showReportDialog(context, ref, event),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.black26,
            child: IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.white, size: 18),
              onPressed: () {
                final chatContext = ChatContext(
                  type: 'event',
                  id: event.id,
                  title: event.title,
                  thumbnail: event.imageUrls.isNotEmpty ? event.imageUrls.first : null,
                  metadata: {'description': event.description},
                );
                context.push('/share-to-chat', extra: chatContext);
                ref.read(eventRepositoryProvider).incrementShareCount(event.id);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(Event event, ThemeData theme, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                event.status.name.toUpperCase(),
                style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.0),
              ),
            ),
            const SizedBox(width: 12),
            _buildCategoryPill(event.categoryId, theme, ref),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          event.title, 
          style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w900, fontSize: 30, letterSpacing: -1.0),
        ),
      ],
    );
  }

  Widget _buildCategoryPill(String categoryId, ThemeData theme, WidgetRef ref) {
    final categoriesAsync = ref.watch(eventCategoriesProvider);
    return categoriesAsync.when(
      data: (cats) {
        final cat = cats.firstWhere((c) => c.id == categoryId, orElse: () => EventCategory(id: '', label: 'General', icon: '📅'));
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: theme.colorScheme.secondary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '${cat.icon} ${cat.label}'.toUpperCase(),
            style: TextStyle(color: theme.colorScheme.secondary, fontWeight: FontWeight.w900, fontSize: 10, letterSpacing: 1.0),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Text(
          title, 
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 18, color: Colors.grey[700]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text, 
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildOrganizerSection(BuildContext context, String organizerId, WidgetRef ref) {
    final theme = Theme.of(context);
    final organizerAsync = ref.watch(organizerProvider(organizerId));
    
    return organizerAsync.when(
      data: (organizer) {
        if (organizer == null) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, 'Hosted by', Icons.groups_rounded),
            const SizedBox(height: 16),
            InkWell(
              onTap: () => context.push('/organizers/$organizerId'),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 25,
                      backgroundImage: organizer.logoUrl != null ? CachedNetworkImageProvider(organizer.logoUrl!) : null,
                      child: organizer.logoUrl == null ? Text(organizer.name.isNotEmpty ? organizer.name[0].toUpperCase() : 'O') : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  organizer.name, 
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (organizer.verificationStatus == OrganizerVerificationStatus.verified || 
                                  organizer.verificationStatus == OrganizerVerificationStatus.official)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Icon(Icons.verified_rounded, color: AppColors.success, size: 16),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${organizer.followerCount} Followers', 
                            style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/organizers/$organizerId'),
                      child: const Text('View Profile'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildTags(List<String> tags, ThemeData theme) {
    if (tags.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          '#$tag', 
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant),
        ),
      )).toList(),
    );
  }

  Widget _buildMetaInfo(Event event, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CAMPUS: ${CampusConstants.getDisplayName(event.campusId)}',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.withValues(alpha: 0.6), letterSpacing: 1.0),
        ),
        const SizedBox(height: 8),
        Text(
          'LAST UPDATED: ${DateFormat('MMM dd, yyyy').format(event.updatedAt ?? event.createdAt)}',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.grey.withValues(alpha: 0.6), letterSpacing: 1.0),
        ),
      ],
    );
  }

  Widget _buildRegistrationBar(BuildContext context, Event event, ThemeData theme, WidgetRef ref) {
    final attendanceAsync = ref.watch(eventAttendanceProvider(event.id));
    final attendance = attendanceAsync.valueOrNull;
    final currentUserId = ref.watch(appUserProvider).valueOrNull?.uid;
    
    final isFull = event.maxCapacity != null && event.currentAttendeeCount >= event.maxCapacity!;
    final isGoing = attendance?.status == AttendanceStatus.going;
    final isSaved = attendance?.status == AttendanceStatus.saved;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: currentUserId == null ? null : () async {
                    try {
                      final newStatus = isSaved ? null : AttendanceStatus.saved;
                      await ref.read(eventServiceProvider).setAttendance(currentUserId, event.id, newStatus);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
                      }
                    }
                  },
                  icon: Icon(
                    isSaved ? Icons.bookmark : Icons.bookmark_border_rounded,
                    color: isSaved ? theme.colorScheme.primary : Colors.grey,
                  ),
                  tooltip: isSaved ? 'Remove from Saved' : 'Save Event',
                ),
                const Text('Save', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ElevatedButton(
                onPressed: currentUserId == null || (isFull && !isGoing) ? null : () async {
                  if (event.isRegistrationRequired && event.registrationUrl != null && event.registrationUrl!.isNotEmpty) {
                    final uri = Uri.tryParse(event.registrationUrl!);
                    if (uri != null && await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }

                  try {
                    final newStatus = isGoing ? null : AttendanceStatus.going;
                    await ref.read(eventServiceProvider).setAttendance(currentUserId, event.id, newStatus);
                    
                    if (context.mounted && newStatus == AttendanceStatus.going) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('You\'re going! This event has been added to your hub.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))));
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: isGoing ? AppColors.success : theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(
                  isGoing ? 'I\'M GOING' : (isFull ? 'EVENT FULL' : (event.isRegistrationRequired && event.registrationUrl != null ? 'REGISTER' : 'RESERVE A SPOT')),
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime start, DateTime end) {
    final date = DateFormat('EEEE, MMM d').format(start);
    final startTime = DateFormat('h:mm a').format(start);
    final endTime = DateFormat('h:mm a').format(end);
    return '$date\n$startTime - $endTime';
  }

  void _showReportDialog(BuildContext context, WidgetRef ref, Event event) {
    final reasons = [
      'Inappropriate content',
      'Misleading information',
      'Spam',
      'Scam or fraud',
      'Other'
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.map((reason) => ListTile(
            title: Text(reason),
            onTap: () async {
              final user = ref.read(appUserProvider).valueOrNull;
              if (user != null) {
                await ref.read(eventRepositoryProvider).reportEvent(
                  eventId: event.id,
                  reporterId: user.uid,
                  reason: reason,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report submitted. Thank you for keeping UniHub safe!')),
                  );
                }
              }
            },
          )).toList(),
        ),
      ),
    );
  }
}
