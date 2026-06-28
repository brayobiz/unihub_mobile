import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unihub_mobile/features/auth/domain/models/app_user.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/listing.dart';
import '../../shared/providers.dart';
import '../widgets/marketplace_card.dart';

class SellerProfileScreen extends ConsumerWidget {
  final String userId;

  const SellerProfileScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sellerAsync = ref.watch(otherUserProvider(userId));
    final listingsAsync = ref.watch(topListingsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Seller Profile',
          style: GoogleFonts.plusJakartaSans(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: sellerAsync.when(
        data: (seller) => _buildContent(context, ref, seller, listingsAsync),
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.indigo)),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, AppUser seller, AsyncValue<List<Listing>> listingsAsync) {
    final reviewsAsync = ref.watch(sellerReviewsProvider(seller.uid));

    return Column(
      children: [
        _buildHeader(seller),
        _buildStats(seller),
        const SizedBox(height: 20),
        Expanded(
          child: DefaultTabController(
            length: 2,
            child: Column(
              children: [
                TabBar(
                  tabs: const [
                    Tab(text: 'Active Listings'),
                    Tab(text: 'Reviews'),
                  ],
                  labelColor: Colors.indigo,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: Colors.indigo,
                  labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildListingsTab(context, seller, listingsAsync),
                      _buildReviewsTab(reviewsAsync),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListingsTab(BuildContext context, AppUser seller, AsyncValue<List<Listing>> listingsAsync) {
    return listingsAsync.when(
      data: (allListings) {
        final sellerListings = allListings.where((l) => l.sellerId == seller.uid).toList();
        if (sellerListings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade200),
                const SizedBox(height: 16),
                Text('No active listings', style: TextStyle(color: Colors.grey.shade500)),
              ],
            ),
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.all(20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 0.7,
          ),
          itemCount: sellerListings.length,
          itemBuilder: (context, index) {
            return MarketplaceCard(listing: sellerListings[index], index: index);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.indigo)),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildReviewsTab(AsyncValue<List<Map<String, dynamic>>> reviewsAsync) {
    return reviewsAsync.when(
      data: (reviews) {
        if (reviews.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.rate_review_outlined, size: 64, color: Colors.grey.shade200),
                const SizedBox(height: 16),
                Text('No reviews yet', style: TextStyle(color: Colors.grey.shade500)),
              ],
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: reviews.length,
          itemBuilder: (context, index) {
            final r = reviews[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade100),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Row(
                        children: List.generate(5, (i) => Icon(
                          Icons.star_rounded,
                          size: 18,
                          color: i < (r['rating'] ?? 0) ? Colors.amber : Colors.grey.shade200,
                        )),
                      ),
                      const Spacer(),
                      Text(
                        _formatDate(r['timestamp'] ?? r['createdAt']),
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    r['comment'] ?? '',
                    style: const TextStyle(fontSize: 14, height: 1.4, color: Colors.black87),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.indigo.shade50,
                        child: Text(
                          (r['reviewerName'] ?? 'S')[0].toUpperCase(),
                          style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.indigo),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        r['reviewerName'] ?? 'Verified Buyer',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: Colors.indigo)),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Recently';
    DateTime date;
    if (timestamp is Timestamp) {
      date = timestamp.toDate();
    } else if (timestamp is DateTime) {
      date = timestamp;
    } else {
      return 'Recently';
    }
    return DateFormat('MMM dd, yyyy').format(date);
  }

  Widget _buildHeader(AppUser seller) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.indigo.shade50, width: 4),
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.indigo.shade50,
                  backgroundImage: seller.photoUrl != null ? NetworkImage(seller.photoUrl!) : null,
                  child: seller.photoUrl == null ? const Icon(Icons.person, size: 50, color: Colors.indigo) : null,
                ),
              ),
              if (seller.trustScore > 80)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.blue, shape: BoxShape.circle),
                    child: const Icon(Icons.verified, color: Colors.white, size: 20),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            seller.fullName,
            style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            seller.university ?? 'UniHub Student',
            style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _infoBadge(Icons.verified_user_rounded, 'Trust ${seller.trustScore.toInt()}%', Colors.blue),
              const SizedBox(width: 12),
              _infoBadge(Icons.star_rounded, '${seller.averageRating.toStringAsFixed(1)} (${seller.ratingsCount})', Colors.amber),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStats(AppUser seller) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _statItem('Completed', '${seller.completedSalesCount}', 'Sales'),
          _statItem('Response', seller.responseRate, 'Rate'),
          _statItem('Joined', DateFormat('MMM yyyy').format(seller.createdAt ?? DateTime.now()), 'Member'),
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, String unit) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.indigo)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
        Text(unit, style: const TextStyle(fontSize: 9, color: Colors.grey)),
      ],
    );
  }

  Widget _infoBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
