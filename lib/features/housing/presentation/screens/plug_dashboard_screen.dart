import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/core/widgets/optimized_image.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/housing/shared/providers.dart';
import 'package:unihub_mobile/features/housing/domain/models/housing_listing.dart';
import 'package:unihub_mobile/features/housing/domain/models/viewing_request.dart';
import 'package:unihub_mobile/features/trust/domain/models/professional_role.dart';
import 'package:unihub_mobile/features/trust/domain/models/verification_application.dart';
import 'package:unihub_mobile/features/trust/presentation/providers/trust_providers.dart';
import 'package:unihub_mobile/widgets/notification_badge.dart';

class PlugDashboardScreen extends ConsumerWidget {
  const PlugDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(appUserProvider).valueOrNull;
    if (user == null) return const Scaffold(body: Center(child: Text('Please log in')));
    
    final isVerifiedPlug = user.verifiedRoles.contains('housePlug');

    if (!isVerifiedPlug) {
      final applicationAsync = ref.watch(applicationByRoleProvider(ProfessionalRole.housePlug));

      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: Text('Plug Access', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
          elevation: 0,
        ),
        body: applicationAsync.when(
          data: (application) => _buildNoAccessBody(context, ref, application),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _buildNoAccessBody(context, ref, null),
        ),
      );
    }

    final listingsAsync = ref.watch(plugListingsProvider(user.uid));
    final applicationAsync = ref.watch(applicationByRoleProvider(ProfessionalRole.housePlug));

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text('Plug Dashboard', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
        actions: const [
          NotificationBadge(module: 'housing'),
          SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileSummary(context, user),
            const SizedBox(height: 16),
            _buildViewingRequestsCard(context, ref, user.uid),
            const SizedBox(height: 16),
            applicationAsync.when(
              data: (application) => _buildVerificationStatusCard(context, user, application),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            _buildOpportunityCTA(context),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Performance Overview', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                _buildBulkRefreshButton(context, listingsAsync, ref),
              ],
            ),
            const SizedBox(height: 16),
            _buildStatsSection(context, listingsAsync),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('My Listings', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
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

  Widget _buildViewingRequestsCard(BuildContext context, WidgetRef ref, String plugId) {
    final requestsAsync = ref.watch(plugViewingRequestsProvider(plugId));
    final theme = Theme.of(context);

    return requestsAsync.when(
      data: (requests) {
        final pending = requests.where((r) => r.status == ViewingRequestStatus.pending).length;
        if (pending == 0) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () => context.push('/viewing-requests'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.warning.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle),
                  child: const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$pending Pending Viewing Requests', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      Text('Schedule visits with potential tenants', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: AppColors.warning),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildNoAccessBody(BuildContext context, WidgetRef ref, VerificationApplication? application) {
    final theme = Theme.of(context);
    final user = ref.watch(appUserProvider).valueOrNull;
    final isVerified = user?.isVerified ?? false;
    final hasPendingApp = application?.status == VerificationStatus.pending;
    final isRejected = application?.status == VerificationStatus.rejected;

    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: (isRejected ? AppColors.error : theme.colorScheme.primary).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              !isVerified 
                  ? Icons.verified_user_rounded
                  : (isRejected 
                      ? Icons.error_outline_rounded 
                      : hasPendingApp 
                          ? Icons.hourglass_empty_rounded 
                          : Icons.lock_person_rounded), 
              color: isRejected ? AppColors.error : theme.colorScheme.primary, 
              size: 64
            ),
          ),
          const SizedBox(height: 32),
          Text(
            !isVerified 
                ? 'Identity Verification Required'
                : (isRejected 
                    ? 'Application Rejected' 
                    : hasPendingApp 
                        ? 'Application Pending' 
                        : 'Plug Access Required'),
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            !isVerified
                ? 'To join the Housing Plug Network, you must first verify your identity with the platform Trust Engine.'
                : (isRejected
                    ? 'Unfortunately, your application to join the Housing Plug Network was not approved at this time.'
                    : hasPendingApp
                        ? 'Your application is currently being reviewed. You will gain access to this dashboard once approved.'
                        : 'You must be a verified Housing Plug to access the professional dashboard and manage listings.'),
            style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurfaceVariant, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          if (!hasPendingApp)
            SizedBox(
              width: double.infinity,
              height: 58,
              child: FilledButton(
                onPressed: () => context.pushReplacement(isVerified ? '/verify-professional/housePlug' : '/trust-center'),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: Text(
                  !isVerified 
                      ? 'Verify Identity' 
                      : (isRejected ? 'Update Application' : 'Apply for Plug Access'),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
              ),
            ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => context.go('/main'),
            child: Text('Return Home', style: TextStyle(fontWeight: FontWeight.w700, color: theme.colorScheme.primary)),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSummary(BuildContext context, dynamic user) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
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
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.2), width: 2),
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
                Text(user.fullName, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (user.isVerified)
                      Icon(Icons.verified_rounded, color: theme.colorScheme.primary, size: 16),
                    const SizedBox(width: 4),
                    Text(
                      user.isHousingPlug ? 'HOUSING PLUG' : 'HOUSING PARTNER', 
                      style: TextStyle(
                        color: user.isVerified ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant, 
                        fontSize: 10, 
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      )
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Show platform trust level
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: user.isVerified ? AppColors.success.withOpacity(0.1) : theme.colorScheme.onSurfaceVariant.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    user.isVerified ? 'PLATFORM TRUSTED' : 'STANDARD ACCOUNT',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      color: user.isVerified ? AppColors.success : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.school_rounded, size: 12, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7)),
                    const SizedBox(width: 4),
                    Text('${user.university}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.qr_code_2_rounded, color: theme.colorScheme.primary, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildOpportunityCTA(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => context.push('/opportunities'),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.colorScheme.primary, AppColors.backgroundDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: theme.colorScheme.primary.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10))
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
                      Text('Opportunity Feed', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
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

  Widget _buildVerificationStatusCard(BuildContext context, dynamic user, VerificationApplication? application) {
    final theme = Theme.of(context);
    // If the user is fully verified in their profile, show the Verified state
    if (user.isVerified) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.success.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.verified_user_rounded, color: AppColors.success, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Platform Trusted Status', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: theme.colorScheme.onSurface)),
                      Text('Your identity is confirmed by UniHub Trust Engine.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildVerificationBadge(Icons.check_circle_rounded, 'Platform Identity'),
                _buildVerificationBadge(Icons.check_circle_rounded, 'Phone Verified'),
                _buildVerificationBadge(Icons.check_circle_rounded, 'Role Active'),
              ],
            ),
          ],
        ),
      );
    }

    // Otherwise, use the application status
    if (application == null) return const SizedBox.shrink();

    return switch (application.status) {
      VerificationStatus.pending || VerificationStatus.underReview => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(
                application.status == VerificationStatus.underReview 
                  ? Icons.rate_review_rounded 
                  : Icons.hourglass_top_rounded, 
                color: theme.colorScheme.onSurfaceVariant, 
                size: 28
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      application.status == VerificationStatus.underReview 
                        ? 'Actively Reviewing' 
                        : 'Trust Review Pending', 
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: theme.colorScheme.onSurface)
                    ),
                    const SizedBox(height: 4),
                    Text(
                      application.status == VerificationStatus.underReview
                        ? 'An administrator is currently reviewing your documents. This usually takes less than 12 hours.'
                        : 'The platform Trust Engine is reviewing your application. Role activation follows identity confirmation.',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, height: 1.4),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      VerificationStatus.rejected => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.error.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.error.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 28),
                  const SizedBox(width: 16),
                  Text('Application Rejected', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.error)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Unfortunately, your application was not approved. This is usually due to missing documents or unclear professional information.',
                style: TextStyle(color: AppColors.error.withOpacity(0.8), fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => context.push('/become-plug'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Update & Resubmit', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      VerificationStatus.approved => const SizedBox.shrink(), // Should be handled by user.isVerified check
      VerificationStatus.expired => const SizedBox.shrink(),
      VerificationStatus.resubmissionRequested => Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.primary.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 28),
                  const SizedBox(width: 16),
                  Text('Action Required', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Further documentation is needed to verify your application. Please check your notifications for details.',
                style: TextStyle(color: AppColors.primary.withOpacity(0.8), fontSize: 12, height: 1.4),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.push('/become-plug'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Resubmit Documents', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
    };
  }

  Widget _buildVerificationBadge(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.success),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.success)),
      ],
    );
  }

  Widget _buildBulkRefreshButton(BuildContext context, AsyncValue<List<HousingListing>> listingsAsync, WidgetRef ref) {
    final theme = Theme.of(context);
    return listingsAsync.when(
      data: (listings) {
        final availableCount = listings.where((l) => l.status == HousingStatus.available).length;
        if (availableCount < 2) return const SizedBox.shrink();
        
        return TextButton.icon(
          onPressed: () async {
            final available = listings.where((l) => l.status == HousingStatus.available).toList();
            for (var l in available) {
              await ref.read(housingRepositoryProvider).refreshListingStatus(l.id);
            }
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Refreshed $availableCount listings! They are now "Verified Today".'))
              );
            }
          },
          icon: const Icon(Icons.bolt_rounded, size: 18, color: Colors.amber),
          label: Text('Verify All', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildStatsSection(BuildContext context, AsyncValue<List<HousingListing>> listingsAsync) {
    final theme = Theme.of(context);
    return listingsAsync.when(
      data: (listings) {
        final active = listings.where((l) => l.status == HousingStatus.available).length;
        final views = listings.fold(0, (sum, l) => sum + l.views);
        final saves = listings.fold(0, (sum, l) => sum + l.saves);
        final chats = listings.fold(0, (sum, l) => sum + l.chatCount);

        return Column(
          children: [
            Row(
              children: [
                _buildStatCard(context, 'Active', active.toString(), theme.colorScheme.primary),
                const SizedBox(width: 12),
                _buildStatCard(context, 'Total Views', views.toString(), theme.colorScheme.secondary),
                const SizedBox(width: 12),
                _buildStatCard(context, 'Chats', chats.toString(), AppColors.success),
              ],
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildStatCard(BuildContext context, String label, String value, Color color) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(color: color.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.w800, letterSpacing: 0.2)),
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
    final theme = Theme.of(context);
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: theme.colorScheme.surfaceVariant.withOpacity(0.3), shape: BoxShape.circle),
            child: Icon(Icons.add_home_work_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
          ),
          const SizedBox(height: 16),
          Text('No listings yet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: theme.colorScheme.onSurface)),
          Text('Start earning by listing properties', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => context.push('/add-housing'),
            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.primary),
            child: const Text('List First Property'),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(HousingListing listing, BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final statusColor = switch (listing.status) {
      HousingStatus.available => AppColors.success,
      HousingStatus.taken => AppColors.error,
      HousingStatus.draft => theme.colorScheme.onSurfaceVariant,
      HousingStatus.pendingReview => AppColors.warning,
      HousingStatus.reported => Colors.deepOrange,
      HousingStatus.archived => Colors.blueGrey,
      HousingStatus.published => theme.colorScheme.primary,
    };

    final statusLabel = listing.status.name.replaceAll(RegExp(r'(?=[A-Z])'), ' ').toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
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
                Text(listing.title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: theme.colorScheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text('KES ${listing.rent.toInt()}', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildSmallBadge(statusLabel, statusColor),
                    const SizedBox(width: 8),
                    _buildListingMetric(Icons.visibility_outlined, listing.views.toString()),
                    const SizedBox(width: 8),
                    _buildListingMetric(Icons.favorite_border_rounded, listing.saves.toString()),
                    const SizedBox(width: 8),
                    _buildListingMetric(Icons.chat_bubble_outline_rounded, listing.chatCount.toString()),
                    const Spacer(),
                    Text(
                      'Upd. ${_formatTimeAgo(listing.updatedAt)}', 
                      style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7), fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: theme.colorScheme.surface,
            onSelected: (val) {
              if (val == 'refresh') {
                ref.read(housingRepositoryProvider).refreshListingStatus(listing.id);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing availability verified!')));
              } else if (val == 'status_available') {
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
              const PopupMenuItem(value: 'refresh', child: Row(
                children: [
                  Icon(Icons.auto_awesome, color: AppColors.success, size: 18),
                  SizedBox(width: 8),
                  Text('Verify Availability'),
                ],
              )),
              if (listing.status != HousingStatus.available)
                const PopupMenuItem(value: 'status_available', child: Text('Mark as Available')),
              if (listing.status != HousingStatus.taken)
                const PopupMenuItem(value: 'status_taken', child: Text('Mark as Taken')),
              const PopupMenuItem(value: 'edit', child: Text('Edit Details')),
              if (listing.status != HousingStatus.archived)
                const PopupMenuItem(value: 'status_archive', child: Text('Archive Listing')),
              PopupMenuItem(value: 'delete', child: Text('Delete Permanently', style: TextStyle(color: AppColors.error))),
            ],
            icon: Icon(Icons.more_vert, color: theme.colorScheme.onSurfaceVariant),
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

  Widget _buildListingMetric(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, size: 12, color: Colors.grey),
        const SizedBox(width: 2),
        Text(value, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
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
