import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../auth/shared/providers.dart';
import '../../../shared/feed_repository.dart';
import '../../../../services/history_service.dart';

class GigDetailsScreen extends ConsumerStatefulWidget {
  final FeedItem? gig;
  final String gigId;

  const GigDetailsScreen({super.key, this.gig, required this.gigId});

  @override
  ConsumerState<GigDetailsScreen> createState() => _GigDetailsScreenState();
}

class _GigDetailsScreenState extends ConsumerState<GigDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.gig != null) {
        _recordHistory(widget.gig!);
      }
    });
  }

  void _recordHistory(FeedItem gig) {
    ref.read(recentHistoryProvider.notifier).addItem(HistoryItem(
      id: gig.id,
      type: 'gig',
      title: gig.title,
      timestamp: DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gigAsync = ref.watch(feedItemByIdProvider(widget.gigId));

    return gigAsync.when(
      data: (gig) {
        final currentGig = gig ?? widget.gig;
        if (currentGig == null) {
          return const Scaffold(body: Center(child: Text('Gig no longer available.')));
        }

        if (gig != null) {
           WidgetsBinding.instance.addPostFrameCallback((_) => _recordHistory(gig));
        }

        final user = ref.watch(appUserProvider).valueOrNull;
        final isOwner = user != null && currentGig.authorId == user.uid;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            title: Text('Gig Details',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              )),
            backgroundColor: theme.colorScheme.surface,
            iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
            elevation: 0,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Info
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        currentGig.price ?? 'Negotiable',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat.yMMMd().format(currentGig.createdAt),
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  currentGig.title,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.business_center_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Text(
                      'Employer: ${currentGig.authorName}',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Divider(height: 40, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),

                Text(
                  'Job Description',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                ),
                const SizedBox(height: 12),
                Text(
                  currentGig.subtitle,
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),

                if (currentGig.deadline != null) ...[
                  _buildInfoRow(context, Icons.calendar_month_outlined, 'Application Deadline', 
                      DateFormat.yMMMd().format(currentGig.deadline!)),
                  const SizedBox(height: 16),
                ],
                
                _buildInfoRow(context, Icons.location_on_outlined, 'Campus', currentGig.university ?? 'Global'),
                
                const SizedBox(height: 40),

                if (currentGig.images.isNotEmpty) ...[
                  Text(
                    'Attachments',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: currentGig.images.length,
                      itemBuilder: (context, index) {
                        return Container(
                          width: 200,
                          margin: const EdgeInsets.only(right: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(16),
                            image: DecorationImage(
                              image: NetworkImage(currentGig.images[index]),
                              fit: BoxFit.cover,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                ],

                // Safety Warning
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shield_outlined, color: Colors.amber),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Safety Tip: Never pay any upfront fees to secure a gig. Always meet in public campus locations.',
                          style: TextStyle(color: Colors.amber, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 100), // Spacing for bottom button
              ],
            ),
          ),
          bottomSheet: Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: isOwner
                ? SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: OutlinedButton.icon(
                      onPressed: () => context.push('/employer-dashboard'),
                      icon: const Icon(Icons.dashboard_outlined),
                      label: const Text('View Applications'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        side: BorderSide(color: theme.colorScheme.primary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  )
                : SizedBox(
                    width: double.infinity,
                    height: 55,
                    child: FilledButton(
                      onPressed: currentGig.authorId.isEmpty 
                        ? null 
                        : () => context.push('/apply-gig', extra: currentGig),
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(
                        currentGig.authorId.isEmpty ? 'Invalid Gig Listing' : 'Apply for this Gig',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
          ),
        );
      },
      loading: () => widget.gig != null 
          ? _buildInitialState(widget.gig!)
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildInitialState(FeedItem gig) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(title: Text(gig.title)),
      body: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: theme.colorScheme.surfaceContainerHighest,
          child: Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 12)),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
          ],
        ),
      ],
    );
  }
}
