import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:unihub_mobile/core/widgets/optimized_image.dart';
import '../../../auth/shared/providers.dart';
import '../../shared/providers.dart';
import '../../domain/models/housing_listing.dart';
import '../../domain/models/housing_plug_application.dart';

class PlugDashboardScreen extends ConsumerWidget {
  const PlugDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).valueOrNull;
    if (user == null) return const Scaffold(body: Center(child: Text('Please log in')));
    
    if (!user.isHousingPlug) {
      final applicationAsync = ref.watch(plugApplicationProvider);

      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text('Plug Access', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
        ),
        body: applicationAsync.when(
          data: (application) => _buildNoAccessBody(context, application),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _buildNoAccessBody(context, null),
        ),
      );
    }

    final listingsAsync = ref.watch(plugListingsProvider(user.uid));
    final applicationAsync = ref.watch(plugApplicationProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Plug Dashboard', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileSummary(user),
            const SizedBox(height: 16),
            applicationAsync.when(
              data: (application) => _buildVerificationStatusCard(context, user, application),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            _buildOpportunityCTA(context),
            const SizedBox(height: 24),
            _buildStatsSection(listingsAsync),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('My Listings', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800)),
                TextButton.icon(
                  onPressed: () => context.push('/add-housing'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add New'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildListingsList(context, listingsAsync, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildNoAccessBody(BuildContext context, HousingPlugApplication? application) {
    final hasPendingApp = application?.status == PlugApplicationStatus.pending;
    final isRejected = application?.status == PlugApplicationStatus.rejected;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: (isRejected ? Colors.red : const Color(0xFF1677F2)).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isRejected 
                  ? Icons.error_outline_rounded 
                  : hasPendingApp 
                      ? Icons.hourglass_empty_rounded 
                      : Icons.lock_person_rounded, 
              color: isRejected ? Colors.red : const Color(0xFF1677F2), 
              size: 64
            ),
          ),
          const SizedBox(height: 32),
          Text(
            isRejected 
                ? 'Application Rejected' 
                : hasPendingApp 
                    ? 'Application Pending' 
                    : 'Plug Access Required',
            style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            isRejected
                ? 'Unfortunately, your application to join the Housing Plug Network was not approved at this time.'
                : hasPendingApp
                    ? 'Your application is currently being reviewed. You will gain access to this dashboard once approved.'
                    : 'You must be a verified Housing Plug to access the professional dashboard and manage listings.',
            style: GoogleFonts.plusJakartaSans(fontSize: 16, color: const Color(0xFF64748B), height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          if (!hasPendingApp)
            SizedBox(
              width: double.infinity,
              height: 58,
              child: FilledButton(
                onPressed: () => context.pushReplacement('/become-plug'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1677F2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: Text(
                  isRejected ? 'Re-apply Now' : 'Apply to Join Network',
                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go('/main'),
            child: Text('Return Home', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSummary(dynamic user) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 20, offset: const Offset(0, 10))
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1677F2).withOpacity(0.2), width: 2),
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
              child: user.photoUrl == null ? Text(user.fullName[0], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)) : null,
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1A1C1E))),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (user.isVerified)
                      const Icon(Icons.verified_rounded, color: Color(0xFF1677F2), size: 16),
                    const SizedBox(width: 4),
                    Text(
                      user.isVerified ? 'VERIFIED PLUG' : 'STANDARD PLUG', 
                      style: TextStyle(
                        color: user.isVerified ? const Color(0xFF1677F2) : const Color(0xFF64748B), 
                        fontSize: 10, 
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.school_rounded, size: 12, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text('${user.university}', style: const TextStyle(color: Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF1677F2).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.qr_code_2_rounded, color: Color(0xFF1677F2), size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildOpportunityCTA(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/opportunities'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1677F2), Color(0xFF0F172A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: const Color(0xFF1677F2).withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.bolt_rounded, color: Colors.amber, size: 20),
                      const SizedBox(width: 8),
                      Text('Opportunity Feed', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Discover new vacancy leads reported by students and landlords.', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white, size: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildVerificationStatusCard(BuildContext context, dynamic user, HousingPlugApplication? application) {
    // If the user is fully verified in their profile, show the Verified state
    if (user.isVerified) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Verified Housing Plug', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16)),
                      Text('Your identity and status are confirmed.', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildVerificationBadge(Icons.check_circle_rounded, 'Identity'),
                _buildVerificationBadge(Icons.check_circle_rounded, 'Phone'),
                _buildVerificationBadge(Icons.check_circle_rounded, 'Active'),
              ],
            ),
          ],
        ),
      );
    }

    // Otherwise, use the application status
    if (application == null) return const SizedBox.shrink();

    return switch (application.status) {
      PlugApplicationStatus.pending => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              const Icon(Icons.hourglass_top_rounded, color: Color(0xFF64748B), size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Application Under Review', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(
                      'We have received your application. You\'ll be notified once our team completes the review.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      PlugApplicationStatus.rejected => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF2F2),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFEE2E2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 28),
                  const SizedBox(width: 16),
                  Text('Application Rejected', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: const Color(0xFF991B1B))),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Unfortunately, your application was not approved. This is usually due to missing documents or unclear professional information.',
                style: TextStyle(color: Color(0xFFB91C1C), fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.push('/become-plug'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    side: const BorderSide(color: Color(0xFFFCA5A5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Update & Resubmit', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      PlugApplicationStatus.approved => const SizedBox.shrink(), // Should be handled by user.isVerified check
    };
  }

  Widget _buildVerificationBadge(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: const Color(0xFF10B981)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF10B981))),
      ],
    );
  }

  Widget _buildStatsSection(AsyncValue<List<HousingListing>> listingsAsync) {
    return listingsAsync.when(
      data: (listings) {
        final active = listings.where((l) => l.status == HousingStatus.available).length;
        final views = listings.fold(0, (sum, l) => sum + l.views);
        final saves = listings.fold(0, (sum, l) => sum + l.saves);

        return Row(
          children: [
            _buildStatCard('Active', active.toString(), Colors.blue),
            const SizedBox(width: 12),
            _buildStatCard('Total Views', views.toString(), Colors.indigo),
            const SizedBox(width: 12),
            _buildStatCard('Saves', saves.toString(), Colors.orange),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 26, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w800, letterSpacing: 0.2)),
          ],
        ),
      ),
    );
  }

  Widget _buildListingsList(BuildContext context, AsyncValue<List<HousingListing>> listingsAsync, WidgetRef ref) {
    return listingsAsync.when(
      data: (listings) => listings.isEmpty
          ? _buildDashboardEmptyState(context)
          : ListView.builder(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: listings.length,
              itemBuilder: (context, index) => _buildDashboardCard(listings[index], context, ref),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
    );
  }

  Widget _buildDashboardEmptyState(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
            child: const Icon(Icons.add_home_work_rounded, size: 48, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 16),
          const Text('No listings yet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          const Text('Start earning by listing properties', style: TextStyle(color: Color(0xFF64748B))),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.push('/add-housing'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1677F2)),
            child: const Text('List First Property'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(HousingListing listing, BuildContext context, WidgetRef ref) {
    final statusColor = switch (listing.status) {
      HousingStatus.available => Colors.green,
      HousingStatus.taken => Colors.red,
      HousingStatus.draft => Colors.grey,
      HousingStatus.pendingReview => Colors.orange,
      HousingStatus.reported => Colors.deepOrange,
      HousingStatus.archived => Colors.blueGrey,
      HousingStatus.published => Colors.blue,
    };

    final statusLabel = listing.status.name.replaceAll(RegExp(r'(?=[A-Z])'), ' ').toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Row(
        children: [
          OptimizedImage(
            imageUrl: listing.images.isNotEmpty ? listing.images.first : 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?q=80&w=2070&auto=format&fit=crop',
            width: 85,
            height: 85,
            borderRadius: BorderRadius.circular(16),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(listing.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('KES ${listing.rent.toInt()}', style: const TextStyle(color: Color(0xFF1677F2), fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildSmallBadge(statusLabel, statusColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Updated ${_formatTimeAgo(listing.updatedAt)}', 
                        style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w500),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'status_available') {
                ref.read(housingRepositoryProvider).updateListingStatus(listing.id, HousingStatus.available);
              } else if (val == 'status_taken') {
                ref.read(housingRepositoryProvider).updateListingStatus(listing.id, HousingStatus.taken);
              } else if (val == 'status_archive') {
                ref.read(housingRepositoryProvider).updateListingStatus(listing.id, HousingStatus.archived);
              } else if (val == 'edit') {
                context.push('/add-housing', extra: listing);
              } else if (val == 'delete') {
                _showDeleteConfirm(context, ref, listing.id);
              }
            },
            itemBuilder: (context) => [
              if (listing.status != HousingStatus.available)
                const PopupMenuItem(value: 'status_available', child: Text('Mark as Available')),
              if (listing.status != HousingStatus.taken)
                const PopupMenuItem(value: 'status_taken', child: Text('Mark as Taken')),
              const PopupMenuItem(value: 'edit', child: Text('Edit Details')),
              if (listing.status != HousingStatus.archived)
                const PopupMenuItem(value: 'status_archive', child: Text('Archive Listing')),
              const PopupMenuItem(value: 'delete', child: Text('Delete Permanently', style: TextStyle(color: Colors.red))),
            ],
            icon: const Icon(Icons.more_vert),
          ),
        ],
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m ago';
    return 'just now';
  }

  void _showDeleteConfirm(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Listing?'),
        content: const Text('This action cannot be undone. All views and stats for this listing will be lost.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(housingRepositoryProvider).deleteListing(id);
              Navigator.pop(context);
            }, 
            child: const Text('Delete', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  Widget _buildSmallBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}
