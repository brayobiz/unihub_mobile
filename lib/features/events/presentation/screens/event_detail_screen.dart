import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/core/constants/campus_constants.dart';
import 'package:unihub_mobile/core/utils/app_logger.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import '../../shared/providers.dart';
import '../../domain/models/event.dart';
import '../../domain/models/event_category.dart';
import '../../domain/models/organizer.dart';
import '../../domain/models/attendance.dart';
import 'package:unihub_mobile/features/chat/domain/models/chat_context.dart';

class EventDetailScreen extends ConsumerStatefulWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  ConsumerState<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends ConsumerState<EventDetailScreen> {
  final PageController _pageController = PageController();
  final ValueNotifier<int> _currentPageNotifier = ValueNotifier<int>(0);

  @override
  void dispose() {
    _pageController.dispose();
    _currentPageNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eventAsync = ref.watch(eventProvider(widget.eventId));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: eventAsync.when(
        data: (event) {
          if (event == null) return const Center(child: Text('Event not found'));
          
          final currentUserId = ref.watch(appUserProvider).valueOrNull?.uid;
          final membersAsync = ref.watch(organizerMembersProvider(event.organizerId));
          final isOrganizer = membersAsync.valueOrNull?.any((m) => m.userId == currentUserId) ?? false;

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(eventProvider(widget.eventId));
                    ref.invalidate(organizerProvider(event.organizerId));
                    ref.invalidate(eventAttendanceProvider(event.id));
                  },
                  child: Stack(
                    children: [
                      _buildContent(context, event, theme, isOrganizer),
                      _buildStickyHeader(context, event, theme, isOrganizer),
                    ],
                  ),
                ),
              ),
              _buildRegistrationBar(context, event, theme, isOrganizer),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Unable to load event details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString().contains('Permission denied') 
                    ? 'You do not have permission to view this event.'
                    : 'Please check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(eventProvider(widget.eventId)),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Event event, ThemeData theme, bool isOrganizer) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      slivers: [
        _buildSliverAppBar(context, event, theme),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              if (event.status == EventStatus.cancelled) _buildStatusBanner(theme, 'This event has been cancelled.', Icons.cancel_outlined, AppColors.error),
              if (event.status == EventStatus.archived) _buildStatusBanner(theme, 'This event is archived.', Icons.archive_outlined, Colors.grey),
              if (event.isExpired && event.status != EventStatus.cancelled) _buildStatusBanner(theme, 'This event has already ended.', Icons.event_busy_rounded, theme.colorScheme.onSurfaceVariant),
              
              const SizedBox(height: 8),
              _buildHeader(event, theme),
              const SizedBox(height: 16),
              _buildOrganizerCard(context, event.organizerId, theme),
              const SizedBox(height: 16),
              _buildInfoCard(context, event, theme, isOrganizer),
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildAboutSection(event, theme),
              ],
              if (event.tags.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildTags(event.tags, theme),
              ],
              const SizedBox(height: 24),
              _buildMetaInfo(event, theme),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBanner(ThemeData theme, String message, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, Event event, ThemeData theme) {
    final topPadding = MediaQuery.of(context).padding.top;
    return SliverAppBar(
      expandedHeight: 440,
      pinned: true,
      elevation: 0,
      stretch: true,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Padding(
          padding: EdgeInsets.fromLTRB(16, topPadding + 65, 16, 0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Hero Image Gallery with all-around rounded corners
              ClipRRect(
                borderRadius: BorderRadius.circular(32),
                child: event.imageUrls.isNotEmpty
                    ? PageView.builder(
                        controller: _pageController,
                        onPageChanged: (idx) => _currentPageNotifier.value = idx,
                        itemCount: event.imageUrls.length,
                        itemBuilder: (context, index) => Stack(
                          fit: StackFit.expand,
                          children: [
                            // Background: Blurred version of the image to fill the container nicely
                            CachedNetworkImage(
                              imageUrl: event.imageUrls[index],
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => const SizedBox.shrink(),
                            ),
                            // Blur overlay
                            ClipRect(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
                                child: Container(
                                  color: Colors.black.withOpacity(0.2),
                                ),
                              ),
                            ),
                            // Main Image: Contain fit ensures the entire graphic (poster) is visible
                            CachedNetworkImage(
                              imageUrl: event.imageUrls[index], 
                              fit: BoxFit.contain,
                              placeholder: (context, url) => Container(color: theme.colorScheme.surfaceContainerHighest),
                              errorWidget: (context, url, error) => Container(
                                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                child: Icon(Icons.broken_image, size: 50, color: theme.colorScheme.primary),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1), 
                        child: Icon(Icons.event, size: 100, color: theme.colorScheme.primary.withValues(alpha: 0.3))
                      ),
              ),
              
              // Image Counter (Moved up slightly to account for padding)
              if (event.imageUrls.length > 1)
                Positioned(
                  bottom: 16,
                  right: 16,
                  child: ValueListenableBuilder<int>(
                    valueListenable: _currentPageNotifier,
                    builder: (context, currentPage, _) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.image_outlined, color: Colors.white, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              '${currentPage + 1}/${event.imageUrls.length}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      );
                    }
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStickyHeader(BuildContext context, Event event, ThemeData theme, bool isOrganizer) {
    final attendance = ref.watch(eventAttendanceProvider(event.id)).valueOrNull;
    final isSaved = attendance?.status == AttendanceStatus.saved;
    final currentUserId = ref.watch(appUserProvider).valueOrNull?.uid;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 20,
      right: 20,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildOverlayButton(
            context: context,
            icon: Icons.arrow_back,
            onTap: () => context.pop(),
          ),
          Row(
            children: [
              if (isOrganizer) ...[
                _buildOverlayButton(
                  context: context,
                  icon: Icons.edit_outlined,
                  iconSize: 20,
                  onTap: event.isExpired ? null : () => context.push('/organizers/${event.organizerId}/events/edit', extra: event),
                ),
                const SizedBox(width: 8),
                _buildOverlayButton(
                  context: context,
                  icon: Icons.more_vert_rounded,
                  onTap: () => _showOrganizerMenu(context, event),
                ),
              ] else ...[
                _buildOverlayButton(
                  context: context,
                  icon: Icons.report_gmailerrorred_rounded,
                  iconSize: 20,
                  onTap: () => _showReportDialog(context, event),
                ),
              ],
              const SizedBox(width: 8),
              _buildOverlayButton(
                context: context,
                icon: Icons.share_outlined,
                onTap: () {
                  final chatContext = ChatContext(
                    type: 'event',
                    id: event.id,
                    title: event.title,
                    thumbnail: event.imageUrls.isNotEmpty ? event.imageUrls.first : null,
                    metadata: {'description': event.description},
                  );
                  context.push('/share-to-chat', extra: chatContext);
                },
              ),
              const SizedBox(width: 8),
              _buildOverlayButton(
                context: context,
                icon: isSaved ? Icons.favorite : Icons.favorite_border,
                iconColor: isSaved ? AppColors.error : theme.colorScheme.onSurface,
                onTap: (currentUserId == null || event.isExpired || event.status == EventStatus.cancelled) ? null : () async {
                  try {
                    final newStatus = isSaved ? null : AttendanceStatus.saved;
                    await ref.read(eventServiceProvider).setAttendance(currentUserId, event.id, newStatus);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  }
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOverlayButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback? onTap,
    Color? iconColor,
    double iconSize = 20,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      shape: const CircleBorder(),
      elevation: 2,
      shadowColor: theme.brightness == Brightness.light 
        ? Colors.black.withValues(alpha: 0.2)
        : Colors.black.withValues(alpha: 0.5),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          height: 40,
          width: 40,
          alignment: Alignment.center,
          child: Icon(
            icon, 
            color: onTap == null 
              ? theme.colorScheme.onSurface.withValues(alpha: 0.3) 
              : (iconColor ?? theme.colorScheme.onSurface), 
            size: iconSize,
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Event event, ThemeData theme) {
    final organizerAsync = ref.watch(organizerProvider(event.organizerId));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildCategoryChip(event.categoryId, theme),
            organizerAsync.maybeWhen(
              data: (org) {
                if (org != null && (org.verificationStatus == OrganizerVerificationStatus.verified || org.verificationStatus == OrganizerVerificationStatus.official)) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (theme.brightness == Brightness.light ? Colors.green[600] : AppColors.success)!.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: (theme.brightness == Brightness.light ? Colors.green[600] : AppColors.success)!.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.verified_rounded, 
                          color: theme.brightness == Brightness.light ? Colors.green[600] : AppColors.success, 
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Verified',
                          style: TextStyle(
                            color: theme.brightness == Brightness.light ? Colors.green[600] : AppColors.success, 
                            fontWeight: FontWeight.bold, 
                            fontSize: 11,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          event.title, 
          style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String categoryId, ThemeData theme) {
    final categoriesAsync = ref.watch(eventCategoriesProvider);
    return categoriesAsync.when(
      data: (cats) {
        final cat = cats.firstWhere((c) => c.id == categoryId, orElse: () => EventCategory(id: '', label: 'General', icon: '📅'));
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            cat.label,
            style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildOrganizerCard(BuildContext context, String organizerId, ThemeData theme) {
    final organizerAsync = ref.watch(organizerProvider(organizerId));
    
    return organizerAsync.when(
      data: (organizer) {
        if (organizer == null) return const SizedBox.shrink();
        return Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
              backgroundImage: organizer.logoUrl != null ? CachedNetworkImageProvider(organizer.logoUrl!) : null,
              child: organizer.logoUrl == null ? Text(organizer.name[0], style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)) : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          organizer.name,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.colorScheme.onSurface),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (organizer.verificationStatus == OrganizerVerificationStatus.verified || 
                          organizer.verificationStatus == OrganizerVerificationStatus.official)
                        Icon(Icons.verified, color: theme.colorScheme.primary, size: 14),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Text(
                    organizer.type == OrganizerType.officialClub || organizer.type == OrganizerType.department 
                        ? 'Official Organizer' 
                        : 'Verified Organizer',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () => context.push('/organizers/$organizerId'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.4)),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 32),
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                'View', 
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildInfoCard(BuildContext context, Event event, ThemeData theme, bool isOrganizer) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.light
                ? Colors.black.withValues(alpha: 0.02)
                : Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(
            theme: theme,
            icon: Icons.calendar_today_outlined,
            title: DateFormat('EEE, MMM d, yyyy').format(event.startAt),
            subtitle: '${DateFormat('h:mm a').format(event.startAt)} – ${DateFormat('h:mm a').format(event.endAt)}',
          ),
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 4, bottom: 4), 
            child: Divider(height: 1, color: theme.colorScheme.outlineVariant),
          ),
          _buildInfoRow(
            theme: theme,
            icon: Icons.location_on_outlined,
            title: event.venue.address ?? 'TBA',
            subtitle: event.venueRoom.isNotEmpty ? event.venueRoom : 'On Campus',
            showChevron: true,
            onTap: () => context.push('/campus-map?eventId=${event.id}'),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 4, bottom: 4), 
            child: Divider(height: 1, color: theme.colorScheme.outlineVariant),
          ),
          _buildInfoRow(
            theme: theme,
            icon: Icons.groups_outlined,
            title: '${event.currentAttendeeCount} Going  ·  ${event.savedCount} Interested',
            subtitle: event.maxCapacity != null ? 'Capacity: ${event.maxCapacity} students' : 'Open attendance',
            showChevron: isOrganizer,
            onTap: isOrganizer ? () => context.push('/events/${event.id}/attendees') : null,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 4, bottom: 4), 
            child: Divider(height: 1, color: theme.colorScheme.outlineVariant),
          ),
          _buildInfoRow(
            theme: theme,
            icon: Icons.confirmation_number_outlined,
            title: event.isRegistrationRequired ? 'Registration Required' : 'Open to all students',
            subtitle: event.isRegistrationRequired ? 'Register via link below' : 'Bring your ID',
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    bool showChevron = false,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 1),
                  Text(subtitle, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            if (trailing != null) trailing,
            if (showChevron) Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4), size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection(Event event, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About This Event',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: theme.colorScheme.onSurface),
        ),
        const SizedBox(height: 12),
        Text(
          event.description,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
            height: 1.6,
          ),
        ),
      ],
    );
  }

  Widget _buildTags(List<String> tags, ThemeData theme) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: tags.map((tag) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tag_rounded, size: 14, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              tag,
              style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
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
          style: TextStyle(
            fontSize: 11, 
            fontWeight: FontWeight.w900, 
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5), 
            letterSpacing: 1.0,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'LAST UPDATED: ${DateFormat('MMM dd, yyyy').format(event.updatedAt ?? event.createdAt)}',
          style: TextStyle(
            fontSize: 11, 
            fontWeight: FontWeight.w900, 
            color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5), 
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildRegistrationBar(BuildContext context, Event event, ThemeData theme, bool isOrganizer) {
    final attendanceAsync = ref.watch(eventAttendanceProvider(event.id));
    final attendance = attendanceAsync.valueOrNull;
    final currentUserId = ref.watch(appUserProvider).valueOrNull?.uid;

    final isPast = event.isExpired;
    final isCancelled = event.status == EventStatus.cancelled;
    final isFull = event.maxCapacity != null && event.currentAttendeeCount >= event.maxCapacity!;
    final isGoing = attendance?.status == AttendanceStatus.going;
    final isSaved = attendance?.status == AttendanceStatus.saved;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant)),
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
          Expanded(
            flex: 1,
            child: OutlinedButton.icon(
              onPressed: (currentUserId == null || isPast || isOrganizer || isCancelled) ? null : () async {
                try {
                  final newStatus = isSaved ? null : AttendanceStatus.saved;
                  await ref.read(eventServiceProvider).setAttendance(currentUserId, event.id, newStatus);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
              icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border_rounded, size: 20),
              label: Text(isCancelled ? 'Cancelled' : (isPast ? 'Event Ended' : (isOrganizer ? 'Organizer' : 'Save Event'))),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                foregroundColor: isSaved ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                side: BorderSide(
                  color: isSaved ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: ElevatedButton.icon(
              onPressed: (currentUserId == null || isPast || isCancelled || (isFull && !isGoing && !isOrganizer)) 
                ? (isOrganizer ? () => context.push('/organizers/${event.organizerId}/dashboard') : null) 
                : () async {
                  if (isOrganizer) {
                    context.push('/organizers/${event.organizerId}/dashboard');
                    return;
                  }

                  if (event.isRegistrationRequired && event.registrationUrl != null && event.registrationUrl!.isNotEmpty) {
                    final uri = Uri.tryParse(event.registrationUrl!);
                    if (uri != null) {
                      try {
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        } else {
                          throw 'Could not launch registration link';
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                        }
                      }
                    }
                  }

                  try {
                    final newStatus = isGoing ? null : AttendanceStatus.going;
                    await ref.read(eventServiceProvider).setAttendance(currentUserId!, event.id, newStatus);
                    
                    if (context.mounted && newStatus == AttendanceStatus.going) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('You\'re going! This event has been added to your hub.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                    }
                  }
                },
              icon: Icon(isGoing ? Icons.check_circle_rounded : (isCancelled ? Icons.cancel_outlined : (isPast ? Icons.event_busy_rounded : (isOrganizer ? Icons.admin_panel_settings_outlined : Icons.check_circle_outline_rounded))), size: 20),
              label: Text(isCancelled ? 'Cancelled' : (isPast ? 'Past Event' : (isGoing ? "I'm Going" : (isOrganizer ? 'Manage Event' : (isFull ? 'Event Full' : 'Attend'))))),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: isGoing ? AppColors.success : ((isPast || isCancelled) ? theme.colorScheme.surfaceContainerHighest : theme.colorScheme.primary),
                foregroundColor: (isPast || isCancelled) ? theme.colorScheme.onSurfaceVariant : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showReportDialog(BuildContext context, Event event) {
    final theme = Theme.of(context);
    final reasons = [
      'Inappropriate content',
      'Misleading information',
      'Spam',
      'Scam or fraud',
      'Other'
    ];

    showDialog(
      context: context,
      builder: (context) {
        String? selectedReason;
        final controller = TextEditingController();

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            title: Text('Report Event', style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...reasons.map((reason) => RadioListTile<String>(
                    title: Text(reason, style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14)),
                    value: reason,
                    groupValue: selectedReason,
                    onChanged: (val) => setState(() => selectedReason = val),
                    contentPadding: EdgeInsets.zero,
                    activeColor: theme.colorScheme.primary,
                  )),
                  if (selectedReason == 'Other') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: controller,
                      decoration: InputDecoration(
                        hintText: 'Please specify...',
                        hintStyle: TextStyle(fontSize: 13, color: theme.colorScheme.onSurfaceVariant),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      maxLines: 3,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: selectedReason == null || (selectedReason == 'Other' && controller.text.trim().isEmpty)
                  ? null
                  : () async {
                      final user = ref.read(appUserProvider).valueOrNull;
                      if (user != null) {
                        try {
                          final finalReason = selectedReason == 'Other' ? 'Other: ${controller.text.trim()}' : selectedReason!;
                          await ref.read(eventRepositoryProvider).reportEvent(
                            eventId: event.id,
                            reporterId: user.uid,
                            reason: finalReason,
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Report submitted. Thank you for keeping Ulify safe!'),
                                backgroundColor: AppColors.success,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            AppLogger.info('Event Reported: ${event.id} for $finalReason', 'EVENT_DETAIL');
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Failed to submit report. Please try again later.')),
                            );
                            AppLogger.error('Report Event Failed', e, null, 'EVENT_DETAIL');
                          }
                        }
                      }
                    },
                child: const Text('Submit Report'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showOrganizerMenu(BuildContext context, Event event) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(Icons.dashboard_outlined, color: theme.colorScheme.primary),
              title: const Text('Organizer Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
              onTap: () {
                Navigator.pop(context);
                context.push('/organizers/${event.organizerId}/dashboard');
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_outline_rounded),
              title: const Text('View Attendees'),
              onTap: () {
                Navigator.pop(context);
                context.push('/events/${event.id}/attendees');
              },
            ),
            ListTile(
              leading: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
              title: const Text('Edit Event'),
              onTap: () {
                Navigator.pop(context);
                context.push('/organizers/${event.organizerId}/events/edit', extra: event);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Duplicate Event'),
              onTap: () {
                Navigator.pop(context);
                context.push(
                  '/organizers/${event.organizerId}/events/create',
                  extra: {'duplicateEvent': event, 'campusId': event.campusId},
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archive Event'),
              onTap: () {
                Navigator.pop(context);
                _confirmArchiveEvent(context, event);
              },
            ),
            ListTile(
              leading: const Icon(Icons.report_problem_outlined),
              title: const Text('Report an Issue'),
              onTap: () {
                Navigator.pop(context);
                _showReportDialog(context, event);
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.cancel_outlined, color: theme.colorScheme.error),
              title: Text('Cancel Event', style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
              subtitle: const Text('This will notify all attendees'),
              onTap: () {
                Navigator.pop(context);
                _showCancelDialog(context, event);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context, Event event) {
    final theme = Theme.of(context);
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Event'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please provide a reason for cancellation. This will be sent to all registered attendees.'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: const InputDecoration(
                hintText: 'e.g. Venue unavailable, bad weather...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reason is required')));
                return;
              }
              
              final userId = ref.read(appUserProvider).valueOrNull?.uid;
              if (userId == null) return;

              Navigator.pop(context);
              try {
                await ref.read(eventServiceProvider).cancelEvent(event.id, userId, reasonController.text.trim());
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event cancelled and attendees notified.')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Confirm Cancellation'),
          ),
        ],
      ),
    );
  }

  void _confirmArchiveEvent(BuildContext context, Event event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Archive Event?'),
        content: const Text('Archiving will hide this event from public discovery but keep it in your records. You can still see it in your History.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final userId = ref.read(appUserProvider).valueOrNull?.uid;
              if (userId == null) return;

              Navigator.pop(context);
              try {
                await ref.read(eventServiceProvider).archiveEvent(event.id, userId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Event archived.')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Archive'),
          ),
        ],
      ),
    );
  }
}
