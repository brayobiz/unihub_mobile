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
          return Column(
            children: [
              Expanded(
                child: _buildContent(context, event, theme),
              ),
              _buildRegistrationBar(context, event, theme),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Event event, ThemeData theme) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSliverAppBar(context, event, theme),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _buildHeader(event, theme),
              const SizedBox(height: 24),
              _buildOrganizerCard(context, event.organizerId, theme),
              const SizedBox(height: 24),
              _buildInfoCard(context, event, theme),
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 32),
                _buildAboutSection(event, theme),
              ],
              if (event.tags.isNotEmpty) ...[
                const SizedBox(height: 24),
                _buildTags(event.tags, theme),
              ],
              const SizedBox(height: 32),
              _buildMetaInfo(event, theme),
              const SizedBox(height: 40),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildSliverAppBar(BuildContext context, Event event, ThemeData theme) {
    final attendance = ref.watch(eventAttendanceProvider(event.id)).valueOrNull;
    final isSaved = attendance?.status == AttendanceStatus.saved;
    final currentUserId = ref.watch(appUserProvider).valueOrNull?.uid;

    return SliverAppBar(
      expandedHeight: 380,
      pinned: true,
      elevation: 0,
      stretch: true,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      flexibleSpace: FlexibleSpaceBar(
        stretchModes: const [StretchMode.zoomBackground],
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Hero Image Gallery
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(32)),
              child: event.imageUrls.isNotEmpty
                  ? PageView.builder(
                      controller: _pageController,
                      onPageChanged: (idx) => _currentPageNotifier.value = idx,
                      itemCount: event.imageUrls.length,
                      itemBuilder: (context, index) => CachedNetworkImage(
                        imageUrl: event.imageUrls[index], 
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(color: theme.colorScheme.surfaceContainerHighest),
                        errorWidget: (context, url, error) => Container(
                          color: theme.colorScheme.primary.withValues(alpha: 0.1),
                          child: Icon(Icons.broken_image, size: 50, color: theme.colorScheme.primary),
                        ),
                      ),
                    )
                  : Container(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1), 
                      child: Icon(Icons.event, size: 100, color: theme.colorScheme.primary.withValues(alpha: 0.3))
                    ),
            ),
            
            // Buttons Overlay
            Positioned(
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
                      _buildOverlayButton(
                        context: context,
                        icon: Icons.report_gmailerrorred_rounded,
                        iconSize: 20,
                        onTap: () => _showReportDialog(context, event),
                      ),
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
                        onTap: (currentUserId == null || event.endAt.isBefore(DateTime.now())) ? null : () async {
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
            ),

            // Image Counter
            if (event.imageUrls.length > 1)
              Positioned(
                bottom: 24,
                right: 24,
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
                  return Row(
                    children: [
                      Icon(Icons.check_circle, color: theme.brightness == Brightness.light ? Colors.green[600] : AppColors.success, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        'Verified',
                        style: TextStyle(
                          color: theme.brightness == Brightness.light ? Colors.green[600] : AppColors.success, 
                          fontWeight: FontWeight.bold, 
                          fontSize: 13,
                        ),
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          event.title, 
          style: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            cat.label,
            style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
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
              radius: 28,
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
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (organizer.verificationStatus == OrganizerVerificationStatus.verified || 
                          organizer.verificationStatus == OrganizerVerificationStatus.official)
                        Icon(Icons.verified, color: theme.colorScheme.primary, size: 16),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    organizer.type == OrganizerType.officialClub || organizer.type == OrganizerType.department 
                        ? 'Official Organizer' 
                        : 'Verified Organizer',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ),
            OutlinedButton(
              onPressed: () => context.push('/organizers/$organizerId'),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                side: BorderSide(color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              child: Text(
                'View Organizer', 
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildInfoCard(BuildContext context, Event event, ThemeData theme) {
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              height: 40,
              width: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: theme.colorScheme.primary, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
                ],
              ),
            ),
            if (trailing != null) trailing,
            if (showChevron) Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4), size: 20),
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

  Widget _buildRegistrationBar(BuildContext context, Event event, ThemeData theme) {
    final attendanceAsync = ref.watch(eventAttendanceProvider(event.id));
    final attendance = attendanceAsync.valueOrNull;
    final currentUserId = ref.watch(appUserProvider).valueOrNull?.uid;
    
    final isPast = event.endAt.isBefore(DateTime.now());
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
              onPressed: (currentUserId == null || isPast) ? null : () async {
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
              label: Text(isPast ? 'Event Ended' : 'Save Event'),
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
              onPressed: (currentUserId == null || isPast || (isFull && !isGoing)) ? null : () async {
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
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
                  }
                }
              },
              icon: Icon(isGoing ? Icons.check_circle_rounded : (isPast ? Icons.event_busy_rounded : Icons.check_circle_outline_rounded), size: 20),
              label: Text(isPast ? 'Past Event' : (isGoing ? "I'm Going" : (isFull ? 'Event Full' : 'Attend'))),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: isGoing ? AppColors.success : (isPast ? theme.colorScheme.surfaceContainerHighest : theme.colorScheme.primary),
                foregroundColor: isPast ? theme.colorScheme.onSurfaceVariant : Colors.white,
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
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Text('Report Event', style: TextStyle(color: theme.colorScheme.onSurface)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.map((reason) => ListTile(
            title: Text(reason, style: TextStyle(color: theme.colorScheme.onSurface)),
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
