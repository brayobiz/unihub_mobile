import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/features/campus_filter/presentation/widgets/campus_filter_selector.dart';
import 'package:unihub_mobile/features/events/shared/providers.dart';
import 'package:unihub_mobile/features/events/domain/models/event.dart';
import 'package:unihub_mobile/features/events/domain/models/event_category.dart';
import 'package:unihub_mobile/features/events/domain/models/organizer.dart';
import 'package:unihub_mobile/widgets/skeleton_loader.dart';
import 'package:unihub_mobile/features/events/presentation/widgets/event_card.dart';
import 'package:unihub_mobile/features/events/presentation/widgets/skeleton_event_card.dart';
import 'events_list_screen.dart';

class EventsBrowseScreen extends ConsumerWidget {
  const EventsBrowseScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final discoveryDataAsync = ref.watch(eventDiscoveryDataProvider);
    final managedAsync = ref.watch(userManagedOrganizersProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: const Text('Discover Events', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            onPressed: () {
              // Future Search Integration
            },
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () {
              // Future Filter Integration
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(eventDiscoveryDataProvider);
          ref.invalidate(userManagedOrganizersProvider);
        },
        child: discoveryDataAsync.when(
          data: (data) => _buildDiscoveryContent(context, data, managedAsync.valueOrNull ?? [], theme),
          loading: () => _buildLoadingState(),
          error: (err, _) => _buildErrorState(err),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            height: 18,
            width: 100,
            color: Colors.grey.withValues(alpha: 0.1), // Fallback if SkeletonLoader fails
            child: const SkeletonLoader(width: 100, height: 18),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 5,
            itemBuilder: (_, __) => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SkeletonLoader(width: 80, height: 80, borderRadius: 16),
            ),
          ),
        ),
        const SizedBox(height: 32),
        ...List.generate(3, (index) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SkeletonLoader(width: 150, height: 18),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 320,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: 3,
                itemBuilder: (_, __) => const SkeletonEventCard(),
              ),
            ),
            const SizedBox(height: 32),
          ],
        )),
      ],
    );
  }

  Widget _buildHostEventCTA(BuildContext context, List<Organizer> orgs) {
    final theme = Theme.of(context);

    // Only show the top CTA if there's an approved Organizer Profile
    final approvedOrgs = orgs.where((o) => o.verificationStatus == OrganizerVerificationStatus.verified || 
                                          o.verificationStatus == OrganizerVerificationStatus.official).toList();
    
    if (approvedOrgs.isEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.8)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.primary.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Organizer Dashboard',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Manage your clubs and campus activities.',
                    style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            ElevatedButton(
              onPressed: () {
                if (approvedOrgs.length == 1) {
                  context.push('/organizers/${approvedOrgs.first.id}/dashboard');
                } else {
                  _showOrganizerPicker(context, approvedOrgs);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: theme.colorScheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: const Text('Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showOrganizerPicker(BuildContext context, List<Organizer> orgs) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your Organizations', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ...orgs.map((org) => ListTile(
              leading: CircleAvatar(
                backgroundImage: org.logoUrl != null ? NetworkImage(org.logoUrl!) : null,
                child: org.logoUrl == null ? Text(org.name.isNotEmpty ? org.name[0].toUpperCase() : 'O') : null,
              ),
              title: Text(org.name, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(org.type.name.toUpperCase()),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                context.push('/organizers/${org.id}/dashboard');
              },
            )),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscoveryContent(BuildContext context, EventDiscoveryData data, List<Organizer> orgs, ThemeData theme) {
    final hasNoEvents = data.featured.isEmpty && 
                     data.live.isEmpty && 
                     data.today.isEmpty && 
                     data.thisWeek.isEmpty;

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 24),
      children: [
        _buildHostEventCTA(context, orgs),
        
        // Show pending events to the organizer for immediate feedback
        if (orgs.isNotEmpty) _buildPendingEventsSection(context, orgs),

        if (data.categories.isNotEmpty) ...[
          const SizedBox(height: 32),
          _buildCategorySection(data.categories),
        ],
        
        if (hasNoEvents && data.categories.isEmpty)
           _buildEmptyState(context, orgs)
        else if (hasNoEvents)
           _buildNoEventsCTA(context, orgs)
        else ...[
          if (data.live.isNotEmpty) ...[
            _buildHorizontalSection(context, 'Happening Now ⚡', data.live, EventListFilter.live),
            const SizedBox(height: 32),
          ],
          if (data.featured.isNotEmpty) ...[
            _buildHorizontalSection(context, 'Featured Events ⭐', data.featured, EventListFilter.featured),
            const SizedBox(height: 32),
          ],
          if (data.today.isNotEmpty) ...[
            _buildHorizontalSection(context, 'Today on Campus', data.today, EventListFilter.today),
            const SizedBox(height: 32),
          ],
          if (data.thisWeek.isNotEmpty) ...[
            _buildHorizontalSection(context, 'This Week', data.thisWeek, EventListFilter.thisWeek),
            const SizedBox(height: 32),
          ],
        ],
        
        const SizedBox(height: 16),
        _buildSecondaryHostCTA(context, orgs),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildPendingEventsSection(BuildContext context, List<Organizer> orgs) {
    return Consumer(
      builder: (context, ref, child) {
        final List<Event> allPending = [];
        
        for (var org in orgs) {
          final events = ref.watch(organizerEventsProvider(org.id)).valueOrNull ?? [];
          allPending.addAll(events.where((e) => e.status == EventStatus.submitted));
        }

        if (allPending.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 20),
                    const SizedBox(width: 8),
                    const Text(
                      'Pending Review',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.orange),
                    ),
                    const Spacer(),
                    Text(
                      '${allPending.length} event(s)',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your submitted events are being reviewed by campus admins and will appear in the feed soon.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 100,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: allPending.length,
                    itemBuilder: (context, index) {
                      final event = allPending[index];
                      return Container(
                        width: 200,
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: event.imageUrls.isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.network(event.imageUrls.first, fit: BoxFit.cover),
                                    )
                                  : const Icon(Icons.event_note, color: Colors.grey, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    event.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Submitted ${DateFormat('MMM dd').format(event.createdAt)}',
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNoEventsCTA(BuildContext context, List<Organizer> orgs) {
    final theme = Theme.of(context);
    
    // Check for approved organizers first
    final approvedOrgs = orgs.where((o) => 
      o.verificationStatus == OrganizerVerificationStatus.verified || 
      o.verificationStatus == OrganizerVerificationStatus.official
    ).toList();

    if (approvedOrgs.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.event_available_outlined, size: 80, color: theme.colorScheme.primary.withOpacity(0.5)),
            ),
            const SizedBox(height: 32),
            const Text(
              'You\'re all set!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your organizer profile is active. Be the first to host an event on your campus today!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 16),
            ),
            const SizedBox(height: 40),
            ElevatedButton.icon(
              onPressed: () {
                if (approvedOrgs.length == 1) {
                  context.push('/organizers/${approvedOrgs.first.id}/dashboard');
                } else {
                  _showOrganizerPicker(context, approvedOrgs);
                }
              },
              icon: const Icon(Icons.dashboard_outlined),
              label: const Text('Go to Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      );
    }

    // Derived state machine logic for pending/rejected apps
    final activeApp = orgs.firstWhere(
      (o) => o.verificationStatus == OrganizerVerificationStatus.submitted || 
             o.verificationStatus == OrganizerVerificationStatus.underReview ||
             o.verificationStatus == OrganizerVerificationStatus.rejected ||
             o.verificationStatus == OrganizerVerificationStatus.draft,
      orElse: () => Organizer(id: '', ownerId: '', name: '', bio: '', campusId: '', createdAt: DateTime.now()),
    );
    
    final hasActiveApp = activeApp.id.isNotEmpty;
    final isRejected = activeApp.verificationStatus == OrganizerVerificationStatus.rejected;
    final isProcessing = activeApp.verificationStatus == OrganizerVerificationStatus.submitted || 
                        activeApp.verificationStatus == OrganizerVerificationStatus.underReview;

    return Padding(
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isProcessing ? Icons.hourglass_empty_rounded : 
              (isRejected ? Icons.edit_note_rounded : Icons.celebration_rounded), 
              size: 80, 
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            isProcessing ? 'Application Processing' : 
            (isRejected ? 'Application Needs Attention' : 'Nothing is happening yet.'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            isRejected 
              ? 'Your organizer application was not approved. Tap below to review and resubmit.' 
              : (isProcessing 
                  ? 'We\'re reviewing your organizer application. You\'ll be able to publish events soon!'
                  : 'Want to host the first event on your campus?'),
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey, fontSize: 16),
          ),
          const SizedBox(height: 40),
          if (!hasActiveApp)
            ElevatedButton(
              onPressed: () => context.pushNamed('organizer-onboarding'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Start Here', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            )
          else if (isRejected)
            ElevatedButton(
              onPressed: () => context.pushNamed('become-organizer', extra: activeApp),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Edit Application', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            )
          else
            ElevatedButton(
              onPressed: () => context.push('/organizers/${activeApp.id}/dashboard'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('View Status', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          const SizedBox(height: 24),
          TextButton(
            onPressed: () => CampusFilterSelector.showCampusBottomSheet(context),
            child: const Text('Change Campus'),
          ),
        ],
      ),
    );
  }

  Widget _buildSecondaryHostCTA(BuildContext context, List<Organizer> orgs) {
    final theme = Theme.of(context);
    
    if (orgs.isNotEmpty) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Divider(),
          const SizedBox(height: 24),
          Text(
            'Want to host an event?',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Create a trusted Organizer Profile and start hosting campus events.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () => context.pushNamed('organizer-onboarding'),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Learn More'),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySection(List<EventCategory> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 24),
          child: Text('Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              return _buildCategoryItem(context, cat);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryItem(BuildContext context, EventCategory category) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () {
        context.push('/events/list?title=${category.label}&filter=category&categoryId=${category.id}');
      },
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            Container(
              height: 60,
              width: 60,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(child: Text(category.icon, style: const TextStyle(fontSize: 24))),
            ),
            const SizedBox(height: 8),
            Text(
              category.label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalSection(BuildContext context, String title, List<Event> events, EventListFilter filter) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  context.push('/events/list?title=$title&filter=${filter.name}');
                },
                child: const Text('See All'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 320,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: events.length,
            itemBuilder: (context, index) {
              return EventCard(event: events[index], index: index);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, List<Organizer> orgs) {
    return _buildNoEventsCTA(context, orgs);
  }

  Widget _buildErrorState(Object err) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 60, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Error: $err', textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
