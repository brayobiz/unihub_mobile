import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../layout/admin_layout.dart';
import '../../shared/providers.dart';
import '../../domain/models/platform_analytics.dart';
import '../../domain/models/user_analytics.dart';
import '../../domain/models/feature_analytics.dart';

class AdminAnalyticsScreen extends ConsumerStatefulWidget {
  const AdminAnalyticsScreen({super.key});

  @override
  ConsumerState<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends ConsumerState<AdminAnalyticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AdminLayout(
      title: 'Platform Analytics',
      child: Column(
        children: [
          Material(
            color: Theme.of(context).cardColor,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'User Analytics'),
                Tab(text: 'Feature Analytics'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const _OverviewTab(),
                const _UserAnalyticsTab(),
                const _FeatureAnalyticsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(platformAnalyticsProvider);

    return analyticsAsync.when(
      data: (analytics) => RefreshIndicator(
        onRefresh: () => ref.refresh(platformAnalyticsProvider.future),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, analytics),
              const SizedBox(height: 32),
              _buildSectionTitle(context, 'User Insights'),
              const SizedBox(height: 16),
              _buildUserGrid(context, analytics),
              const SizedBox(height: 32),
              _buildContentGrid(context, analytics),
              const SizedBox(height: 32),
              _buildModerationGrid(context, analytics),
            ],
          ),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildHeader(BuildContext context, PlatformAnalytics analytics) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Foundation Analytics',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'High-level metrics across the platform.',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Text(
          'Last updated: ${DateFormat('HH:mm').format(analytics.updatedAt)}',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildUserGrid(BuildContext context, PlatformAnalytics analytics) {
    return _AnalyticsGrid(
      children: [
        _AnalyticsCard(
          title: 'Total Users',
          value: NumberFormat.compact().format(analytics.totalUsers),
          icon: Icons.people_outline,
          color: AppColors.primary,
          subtitle: 'Registered accounts',
          onTap: () => context.push('/admin/users'),
        ),
        _AnalyticsCard(
          title: 'Growth',
          value: '+${analytics.newUsersToday}',
          icon: Icons.trending_up,
          color: Colors.green,
          subtitle: 'Joined today',
          onTap: () => context.push('/admin/users'),
        ),
        _AnalyticsCard(
          title: 'Active Users',
          value: NumberFormat.compact().format(analytics.activeUsers),
          icon: Icons.bolt,
          color: Colors.orange,
          subtitle: 'Logged in (30d)',
        ),
        _AnalyticsCard(
          title: 'Verified Users',
          value: NumberFormat.compact().format(analytics.verifiedUsers),
          icon: Icons.verified_outlined,
          color: AppColors.success,
          subtitle: 'Identity verified',
        ),
      ],
    );
  }

  Widget _buildContentGrid(BuildContext context, PlatformAnalytics analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Content Ecosystem'),
        const SizedBox(height: 16),
        _AnalyticsGrid(
          children: [
            _AnalyticsCard(
              title: 'Marketplace',
              value: NumberFormat.compact().format(analytics.totalMarketplaceListings),
              icon: Icons.shopping_bag_outlined,
              color: AppColors.marketplace,
              subtitle: 'Active listings',
              onTap: () => context.push('/admin/marketplace'),
            ),
            _AnalyticsCard(
              title: 'Housing',
              value: NumberFormat.compact().format(analytics.totalHousingListings),
              icon: Icons.home_outlined,
              color: AppColors.housing,
              subtitle: 'Available rooms',
              onTap: () => context.push('/admin/housing'),
            ),
            _AnalyticsCard(
              title: 'Study Notes',
              value: NumberFormat.compact().format(analytics.totalNotes),
              icon: Icons.description_outlined,
              color: AppColors.notes,
              subtitle: 'Uploaded resources',
              onTap: () => context.push('/admin/notes'),
            ),
            _AnalyticsCard(
              title: 'Events',
              value: NumberFormat.compact().format(analytics.totalEvents),
              icon: Icons.event_outlined,
              color: Colors.deepPurple,
              subtitle: 'Upcoming & past',
              onTap: () => context.push('/admin/events'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModerationGrid(BuildContext context, PlatformAnalytics analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Moderation & Support'),
        const SizedBox(height: 16),
        _AnalyticsGrid(
          children: [
            _AnalyticsCard(
              title: 'Pending Reports',
              value: analytics.pendingReports.toString(),
              icon: Icons.report_problem_outlined,
              color: AppColors.error,
              subtitle: 'Awaiting review',
              onTap: () => context.push('/admin/reports'),
            ),
            _AnalyticsCard(
              title: 'Verifications',
              value: analytics.pendingVerifications.toString(),
              icon: Icons.how_to_reg_outlined,
              color: AppColors.warning,
              subtitle: 'Pending requests',
              onTap: () => context.push('/admin/verifications'),
            ),
            _AnalyticsCard(
              title: 'Support',
              value: analytics.openSupportConversations.toString(),
              icon: Icons.support_agent,
              color: AppColors.secondary,
              subtitle: 'Active tickets',
              onTap: () => context.push('/admin/support'),
            ),
            _AnalyticsCard(
              title: 'Announcements',
              value: analytics.activeAnnouncements.toString(),
              icon: Icons.campaign_outlined,
              color: AppColors.secondaryDark,
              subtitle: 'Currently live',
              onTap: () => context.push('/admin/announcements'),
            ),
          ],
        ),
      ],
    );
  }
}

class _UserAnalyticsTab extends ConsumerWidget {
  const _UserAnalyticsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(userAnalyticsProvider);

    return analyticsAsync.when(
      data: (analytics) => RefreshIndicator(
        onRefresh: () => ref.refresh(userAnalyticsProvider.future),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle(context, 'User Growth'),
              const SizedBox(height: 16),
              _buildGrowthGrid(context, analytics),
              const SizedBox(height: 24),
              _buildGrowthChart(context, analytics),
              const SizedBox(height: 32),
              _buildSectionTitle(context, 'User Activity'),
              const SizedBox(height: 16),
              _buildActivityGrid(context, analytics),
              const SizedBox(height: 32),
              _buildSectionTitle(context, 'Verification Insights'),
              const SizedBox(height: 16),
              _buildVerificationGrid(context, analytics),
              const SizedBox(height: 32),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(context, 'Account Types'),
                        const SizedBox(height: 16),
                        _buildDistributionPie(context, analytics.usersByAccountType),
                      ],
                    ),
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle(context, 'Trust Score Distribution'),
                        const SizedBox(height: 16),
                        _buildTrustScoreStats(context, analytics),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildGrowthGrid(BuildContext context, UserAnalytics analytics) {
    return _AnalyticsGrid(
      children: [
        _AnalyticsCard(
          title: 'New Today',
          value: analytics.newUsersToday.toString(),
          icon: Icons.person_add_outlined,
          color: Colors.green,
          subtitle: 'Past 24 hours',
          onTap: () => context.push('/admin/users'),
        ),
        _AnalyticsCard(
          title: 'This Week',
          value: analytics.newUsersThisWeek.toString(),
          icon: Icons.calendar_view_week_outlined,
          color: Colors.blue,
          subtitle: 'Current week',
        ),
        _AnalyticsCard(
          title: 'This Month',
          value: analytics.newUsersThisMonth.toString(),
          icon: Icons.calendar_month_outlined,
          color: Colors.orange,
          subtitle: 'Current month',
        ),
        _AnalyticsCard(
          title: 'Total Retention',
          value: '${((analytics.monthlyActiveUsers / analytics.totalUsers) * 100).toStringAsFixed(1)}%',
          icon: Icons.analytics_outlined,
          color: Colors.purple,
          subtitle: 'MAU / Total',
        ),
      ],
    );
  }

  Widget _buildActivityGrid(BuildContext context, UserAnalytics analytics) {
    return _AnalyticsGrid(
      children: [
        _AnalyticsCard(
          title: 'DAU',
          value: analytics.dailyActiveUsers.toString(),
          icon: Icons.today_outlined,
          color: AppColors.primary,
          subtitle: 'Daily Active',
        ),
        _AnalyticsCard(
          title: 'WAU',
          value: analytics.weeklyActiveUsers.toString(),
          icon: Icons.view_week_outlined,
          color: Colors.blue,
          subtitle: 'Weekly Active',
        ),
        _AnalyticsCard(
          title: 'MAU',
          value: analytics.monthlyActiveUsers.toString(),
          icon: Icons.calendar_month_outlined,
          color: Colors.orange,
          subtitle: 'Monthly Active',
        ),
        _AnalyticsCard(
          title: 'Currently Online',
          value: analytics.currentlyActive.toString(),
          icon: Icons.circle,
          color: Colors.green,
          subtitle: 'Real-time',
        ),
      ],
    );
  }

  Widget _buildVerificationGrid(BuildContext context, UserAnalytics analytics) {
    return _AnalyticsGrid(
      children: [
        _AnalyticsCard(
          title: 'Verified',
          value: analytics.verifiedUsers.toString(),
          icon: Icons.verified_user_outlined,
          color: AppColors.success,
          subtitle: 'Approved users',
          onTap: () => context.push('/admin/verifications'),
        ),
        _AnalyticsCard(
          title: 'Rejected',
          value: analytics.rejectedVerifications.toString(),
          icon: Icons.cancel_outlined,
          color: AppColors.error,
          subtitle: 'Failed applications',
          onTap: () => context.push('/admin/verifications'),
        ),
        _AnalyticsCard(
          title: 'Approval Rate',
          value: '${(analytics.verificationApprovalRate * 100).toStringAsFixed(1)}%',
          icon: Icons.percent,
          color: Colors.blue,
          subtitle: 'Accepted / Total',
        ),
        _AnalyticsCard(
          title: 'In Progress',
          value: analytics.pendingVerifications.toString(),
          icon: Icons.pending_actions,
          color: AppColors.warning,
          subtitle: 'Awaiting review',
          onTap: () => context.push('/admin/verifications'),
        ),
      ],
    );
  }

  Widget _buildGrowthChart(BuildContext context, UserAnalytics analytics) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Registrations (Last 7 Days)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: analytics.growthTrend.map((point) {
                  final maxCount = analytics.growthTrend.fold(0, (max, p) => p.count > max ? p.count : max);
                  final heightFactor = maxCount > 0 ? point.count / maxCount : 0.0;
                  
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(point.count.toString(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        width: 32,
                        height: (heightFactor * 150).clamp(4.0, 150.0),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.8),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        DateFormat('E').format(point.date),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionPie(BuildContext context, Map<String, int> data) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: data.entries.map((entry) {
            final total = data.values.fold(0, (sum, val) => sum + val);
            final percent = total > 0 ? entry.value / total : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: entry.key == 'Student' ? AppColors.primary : AppColors.secondary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      entry.key, 
                      style: const TextStyle(fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(entry.value.toString(), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Text('(${(percent * 100).toStringAsFixed(1)}%)', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTrustScoreStats(BuildContext context, UserAnalytics analytics) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Text(
                    'Average Platform Score', 
                    style: TextStyle(fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  analytics.averageTrustScore.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ],
            ),
            const Divider(height: 32),
            const Text('Distribution', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 16),
            ...analytics.trustScoreDistribution.entries.map((entry) {
              final total = analytics.totalUsers;
              final percent = total > 0 ? entry.value / total : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key, style: const TextStyle(fontSize: 12)),
                        Text('${entry.value} users', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: percent,
                      backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                      color: _getTrustColor(entry.key),
                      borderRadius: BorderRadius.circular(4),
                      minHeight: 6,
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _getTrustColor(String bucket) {
    if (bucket.startsWith('0')) return Colors.red;
    if (bucket.startsWith('2')) return Colors.orange;
    if (bucket.startsWith('4')) return Colors.yellow.shade700;
    if (bucket.startsWith('6')) return Colors.lightGreen;
    return Colors.green;
  }
}

class _FeatureAnalyticsTab extends ConsumerWidget {
  const _FeatureAnalyticsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = ref.watch(featureAnalyticsProvider);

    return analyticsAsync.when(
      data: (analytics) => RefreshIndicator(
        onRefresh: () => ref.refresh(featureAnalyticsProvider.future),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildMarketplaceSection(context, analytics.marketplace),
              const SizedBox(height: 40),
              _buildHousingSection(context, analytics.housing),
              const SizedBox(height: 40),
              _buildNotesSection(context, analytics.notes),
              const SizedBox(height: 40),
              _buildEventsSection(context, analytics.events),
              const SizedBox(height: 40),
              _buildSupportModerationSection(context, analytics),
              const SizedBox(height: 40),
              _buildAnnouncementSection(context, analytics.announcements),
            ],
          ),
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildMarketplaceSection(BuildContext context, MarketplaceStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Marketplace Analytics', Icons.shopping_bag, AppColors.marketplace),
        const SizedBox(height: 16),
        _AnalyticsGrid(
          children: [
            _AnalyticsCard(
              title: 'Active Listings',
              value: stats.activeListings.toString(),
              subtitle: '${stats.newListingsToday} new today',
              icon: Icons.store_outlined,
              color: AppColors.marketplace,
              onTap: () => context.push('/admin/marketplace'),
            ),
            _AnalyticsCard(
              title: 'Sold Items',
              value: stats.soldListings.toString(),
              subtitle: 'Total completions',
              icon: Icons.check_circle_outline,
              color: Colors.green,
            ),
            _AnalyticsCard(
              title: 'Total Engagement',
              value: NumberFormat.compact().format(stats.totalViews),
              subtitle: '${NumberFormat.compact().format(stats.totalSaves)} saves recorded',
              icon: Icons.visibility_outlined,
              color: Colors.blue,
            ),
            _AnalyticsCard(
              title: 'Chats Started',
              value: stats.totalChatsStarted.toString(),
              subtitle: 'Purchase intent',
              icon: Icons.chat_bubble_outline,
              color: Colors.orange,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHousingSection(BuildContext context, HousingStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Housing Analytics', Icons.home, AppColors.housing),
        const SizedBox(height: 16),
        _AnalyticsGrid(
          children: [
            _AnalyticsCard(
              title: 'Available Rooms',
              value: stats.availableListings.toString(),
              subtitle: '${stats.newListingsToday} listed today',
              icon: Icons.hotel_outlined,
              color: AppColors.housing,
              onTap: () => context.push('/admin/housing'),
            ),
            _AnalyticsCard(
              title: 'Total Occupied',
              value: stats.takenListings.toString(),
              subtitle: 'Market throughput',
              icon: Icons.house_outlined,
              color: Colors.brown,
            ),
            _AnalyticsCard(
              title: 'Housing Views',
              value: NumberFormat.compact().format(stats.totalViews),
              subtitle: 'Unique searches',
              icon: Icons.remove_red_eye_outlined,
              color: Colors.indigo,
            ),
            _AnalyticsCard(
              title: 'Saved Listings',
              value: stats.totalSaves.toString(),
              subtitle: 'High interest items',
              icon: Icons.favorite_border,
              color: Colors.pink,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNotesSection(BuildContext context, NotesStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Study Notes Analytics', Icons.description, AppColors.notes),
        const SizedBox(height: 16),
        _AnalyticsGrid(
          children: [
            _AnalyticsCard(
              title: 'Active Resources',
              value: stats.activeNotes.toString(),
              subtitle: '${stats.newNotesToday} uploaded today',
              icon: Icons.menu_book_outlined,
              color: AppColors.notes,
              onTap: () => context.push('/admin/notes'),
            ),
            _AnalyticsCard(
              title: 'Total Downloads',
              value: NumberFormat.compact().format(stats.totalDownloads),
              subtitle: 'Direct study impact',
              icon: Icons.download_outlined,
              color: Colors.green,
            ),
            _AnalyticsCard(
              title: 'Library Views',
              value: NumberFormat.compact().format(stats.totalViews),
              subtitle: 'Resource discovery',
              icon: Icons.auto_stories_outlined,
              color: Colors.orange,
            ),
            _AnalyticsCard(
              title: 'Note Volume',
              value: stats.totalNotes.toString(),
              subtitle: 'All-time library size',
              icon: Icons.library_books_outlined,
              color: Colors.blueGrey,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildEventsSection(BuildContext context, EventStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Campus Events', Icons.event, Colors.deepPurple),
        const SizedBox(height: 16),
        _AnalyticsGrid(
          children: [
            _AnalyticsCard(
              title: 'Upcoming Events',
              value: stats.upcomingEvents.toString(),
              subtitle: 'Scheduled soon',
              icon: Icons.calendar_month_outlined,
              color: Colors.deepPurple,
              onTap: () => context.push('/admin/events'),
            ),
            _AnalyticsCard(
              title: 'Live Now',
              value: stats.liveEvents.toString(),
              subtitle: 'Active gatherings',
              icon: Icons.bolt,
              color: Colors.amber,
              onTap: () => context.push('/admin/events'),
            ),
            _AnalyticsCard(
              title: 'Pending Approval',
              value: stats.pendingApprovals.toString(),
              subtitle: 'Moderation queue',
              icon: Icons.hourglass_empty_outlined,
              color: Colors.orange,
              onTap: () => context.push('/admin/events'),
            ),
            _AnalyticsCard(
              title: 'Total Events',
              value: stats.totalEvents.toString(),
              subtitle: 'Platform historical',
              icon: Icons.history_outlined,
              color: Colors.blue,
              onTap: () => context.push('/admin/events'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSupportModerationSection(BuildContext context, FeatureAnalytics analytics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Support & Moderation', Icons.gavel, AppColors.error),
        const SizedBox(height: 16),
        _AnalyticsGrid(
          children: [
            _AnalyticsCard(
              title: 'Awaiting Admin',
              value: analytics.support.waitingAdmin.toString(),
              subtitle: 'Urgent support',
              icon: Icons.support_agent,
              color: AppColors.error,
              onTap: () => context.push('/admin/support'),
            ),
            _AnalyticsCard(
              title: 'Resolved Today',
              value: analytics.support.resolvedToday.toString(),
              subtitle: 'Support throughput',
              icon: Icons.done_all,
              color: Colors.green,
              onTap: () => context.push('/admin/support'),
            ),
            _AnalyticsCard(
              title: 'Open Reports',
              value: analytics.moderation.pendingReports.toString(),
              subtitle: 'Content violations',
              icon: Icons.report_outlined,
              color: Colors.red,
              onTap: () => context.push('/admin/reports'),
            ),
            _AnalyticsCard(
              title: 'Verification Queue',
              value: analytics.moderation.pendingVerifications.toString(),
              subtitle: 'New applications',
              icon: Icons.verified_user_outlined,
              color: AppColors.warning,
              onTap: () => context.push('/admin/verifications'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAnnouncementSection(BuildContext context, AnnouncementStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Announcements', Icons.campaign, AppColors.secondaryDark),
        const SizedBox(height: 16),
        _AnalyticsGrid(
          children: [
            _AnalyticsCard(
              title: 'Active Now',
              value: stats.activeAnnouncements.toString(),
              subtitle: 'Live broadcast',
              icon: Icons.notifications_active_outlined,
              color: AppColors.secondaryDark,
              onTap: () => context.push('/admin/announcements'),
            ),
            _AnalyticsCard(
              title: 'Scheduled',
              value: stats.scheduledAnnouncements.toString(),
              subtitle: 'Future visibility',
              icon: Icons.schedule_outlined,
              color: Colors.blue,
              onTap: () => context.push('/admin/announcements'),
            ),
            _AnalyticsCard(
              title: 'Expired',
              value: stats.expiredAnnouncements.toString(),
              subtitle: 'Past broadcasts',
              icon: Icons.history_outlined,
              color: Colors.grey,
              onTap: () => context.push('/admin/announcements'),
            ),
          ],
        ),
      ],
    );
  }
}

class _AnalyticsGrid extends StatelessWidget {
  final List<Widget> children;

  const _AnalyticsGrid({required this.children});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    int crossAxisCount = 1;
    if (width > 1200) {
      crossAxisCount = 4;
    } else if (width > 800) {
      crossAxisCount = 3;
    } else if (width > 500) {
      crossAxisCount = 2;
    }

    return GridView.count(
      crossAxisCount: crossAxisCount,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      children: children,
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _AnalyticsCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  if (onTap != null)
                    Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5)),
                ],
              ),
              const Spacer(),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
