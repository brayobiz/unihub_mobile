import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../auth/shared/providers.dart';
import '../../../shared/feed_repository.dart';

import 'package:intl/intl.dart';
import '../../../auth/shared/providers.dart';
import '../../../shared/feed_repository.dart';
import '../../../../services/history_service.dart';

class GigDetailsScreen extends ConsumerStatefulWidget {
  final FeedItem gig;

  const GigDetailsScreen({super.key, required this.gig});

  @override
  ConsumerState<GigDetailsScreen> createState() => _GigDetailsScreenState();
}

class _GigDetailsScreenState extends ConsumerState<GigDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recentHistoryProvider.notifier).addItem(HistoryItem(
        id: widget.gig.id,
        type: 'gig',
        title: widget.gig.title,
        timestamp: DateTime.now(),
      ));
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final gig = widget.gig;
    final user = ref.watch(appUserProvider).valueOrNull;
    final isOwner = user != null && gig.authorId == user.uid;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text('Gig details', 
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
                    gig.price ?? 'Negotiable',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  DateFormat.yMMMd().format(gig.createdAt),
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              gig.title,
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
                  'Employer: ${gig.authorName}',
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
              gig.subtitle,
              style: TextStyle(
                fontSize: 16,
                color: theme.colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 32),

            if (gig.deadline != null) ...[
              _buildInfoRow(context, Icons.calendar_month_outlined, 'Application Deadline', 
                  DateFormat.yMMMd().format(gig.deadline!)),
              const SizedBox(height: 16),
            ],
            
            _buildInfoRow(context, Icons.location_on_outlined, 'Campus', gig.university ?? 'Global'),
            
            const SizedBox(height: 40),

            if (gig.images.isNotEmpty) ...[
              Text(
                'Attachments',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: gig.images.length,
                  itemBuilder: (context, index) {
                    return Container(
                      width: 200,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        image: DecorationImage(
                          image: NetworkImage(gig.images[index]),
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
                  onPressed: gig.authorId.isEmpty 
                    ? null 
                    : () => context.push('/apply-gig', extra: gig),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text(
                    gig.authorId.isEmpty ? 'Invalid Gig Listing' : 'Apply for this Gig',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
      ),
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
