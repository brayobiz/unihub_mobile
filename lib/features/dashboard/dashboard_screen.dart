import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth/shared/providers.dart';
import '../marketplace/shared/providers.dart';
import '../housing/shared/providers.dart';
import '../housing/presentation/widgets/housing_card.dart';
import '../notes/shared/providers.dart';
import '../gigs/gigs_screen.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/feed/feed_item_card.dart';
import '../../widgets/feed/feed_type.dart';
import '../../widgets/skeleton_loader.dart';
import 'controllers/smart_feed_controller.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      drawer: const AppDrawer(),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(smartFeedProvider);
          ref.invalidate(listingsProvider);
          ref.invalidate(notesListingsProvider);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          slivers: [
            const _DashboardAppBar(),
            const SliverToBoxAdapter(child: _QuickActions()),
            const SliverToBoxAdapter(child: _CampusPulseSection()),
            const SliverToBoxAdapter(child: _HousingPreviewSection()),
            
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Recommended for You',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
            
            const _SmartFeedSection(),
            
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

class _DashboardAppBar extends ConsumerWidget {
  const _DashboardAppBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).valueOrNull;
    
    return SliverAppBar(
      expandedHeight: 160,
      floating: false,
      pinned: true,
      backgroundColor: Colors.white,
      elevation: 0,
      leading: Builder(
        builder: (context) => IconButton(
          icon: const Icon(Icons.menu, color: Colors.black),
          onPressed: () => Scaffold.of(context).openDrawer(),
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => context.push('/notifications'),
          icon: const Icon(Icons.notifications_none_rounded, color: Colors.black),
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade700, Colors.indigo.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 80, 24, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Hi, ${user?.fullName.split(' ').first ?? 'Student'}! 🎓',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  _getDynamicGreeting(),
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getDynamicGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Start your morning right! ☕';
    if (hour < 17) return 'Campus is buzzing right now! ⚡';
    return 'Unwinding? See what\'s new. 🌙';
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            _item(context, 'Sell', Icons.add_shopping_cart, Colors.orange, '/add-listing'),
            _item(context, 'Post Gig', Icons.add_task_rounded, Colors.indigo, '/gigs'),
            _item(context, 'Notes', Icons.upload_file_rounded, Colors.blue, '/add-note'),
            _item(context, 'Housing', Icons.add_home_work_rounded, Colors.purple, '/add-housing'),
            _item(context, 'Confess', Icons.favorite_rounded, Colors.pink, '/confessions'),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, String label, IconData icon, Color color, String route) {
    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: InkWell(
        onTap: () => context.push(route),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _CampusPulseSection extends ConsumerWidget {
  const _CampusPulseSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listings = ref.watch(topListingsProvider).valueOrNull?.length ?? 0;
    final gigs = ref.watch(gigsFeedProvider).valueOrNull?.length ?? 0;
    final notes = ref.watch(topNotesProvider).valueOrNull?.length ?? 0;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Campus Pulse',
            style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _card('Live Offers', '$listings', Icons.trending_up, Colors.green),
              const SizedBox(width: 12),
              _card('Gigs', '$gigs', Icons.bolt, Colors.amber),
              const SizedBox(width: 12),
              _card('Notes', '$notes', Icons.description, Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _card(String label, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 8),
            Text(val, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

class _HousingPreviewSection extends ConsumerWidget {
  const _HousingPreviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).valueOrNull;
    final housingAsync = ref.watch(housingListingsProvider(15));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Housing near ${user?.campus ?? 'Campus'}',
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              TextButton(onPressed: () => context.push('/housing'), child: const Text('See All')),
            ],
          ),
          housingAsync.when(
            data: (listings) => listings.isEmpty 
              ? const Text('No listings nearby yet.', style: TextStyle(fontSize: 12, color: Colors.grey))
              : SizedBox(
                  height: 260,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: listings.length > 5 ? 5 : listings.length,
                    itemBuilder: (context, index) => SizedBox(
                      width: 280,
                      child: Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: HousingCard(
                          listing: listings[index],
                          onTap: () => context.push('/housing-detail', extra: listings[index]),
                        ),
                      ),
                    ),
                  ),
                ),
            loading: () => const Center(child: SkeletonLoader(width: double.infinity, height: 200)),
            error: (e, _) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _SmartFeedSection extends ConsumerWidget {
  const _SmartFeedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(smartFeedProvider);

    return feedAsync.when(
      data: (items) => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final item = items[index];
              return FeedItemCard(
                item: item.model,
                onTap: () => _handleItemTap(context, item),
              );
            },
            childCount: items.length,
          ),
        ),
      ),
      loading: () => SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) => const SkeletonFeedItem(),
            childCount: 5,
          ),
        ),
      ),
      error: (err, _) => const SliverToBoxAdapter(child: SizedBox.shrink()),
    );
  }

  void _handleItemTap(BuildContext context, SmartFeedItem item) {
    switch (item.model.type) {
      case FeedType.marketplace:
        context.push('/listing-detail', extra: item.originalData);
        break;
      case FeedType.gig:
        context.push('/gig-detail', extra: item.originalData);
        break;
      case FeedType.notes:
        context.push('/note-detail', extra: item.originalData);
        break;
      case FeedType.housing:
        context.push('/housing-detail', extra: item.originalData);
        break;
      default:
        break;
    }
  }
}
