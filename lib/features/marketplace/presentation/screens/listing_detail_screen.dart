import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:unihub_mobile/core/widgets/optimized_image.dart';
import '../../../auth/shared/providers.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../domain/models/listing.dart';
import '../../shared/providers.dart';
import '../../../chat/shared/providers.dart';
import '../widgets/marketplace_card.dart';

class ListingDetailScreen extends ConsumerStatefulWidget {
  final Listing listing;

  const ListingDetailScreen({super.key, required this.listing});

  @override
  ConsumerState<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  bool _isSaved = false;
  bool _isDescriptionExpanded = false;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    // Record a view
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(marketplaceRepositoryProvider).recordView(widget.listing.id);
    });
  }

  void _toggleSave() {
    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to save items')));
      return;
    }
    setState(() => _isSaved = !_isSaved);
    ref.read(marketplaceRepositoryProvider).toggleSaveListing(user.uid, widget.listing.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isSaved ? 'Added to your favorites' : 'Removed from favorites'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _reportListing() {
    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Report this Listing', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            const Text('Why are you reporting this listing? Our team will investigate immediately.'),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.warning_amber_rounded, color: Colors.orange),
              title: const Text('Inappropriate content'),
              onTap: () => _submitReport('Inappropriate content'),
            ),
            ListTile(
              leading: const Icon(Icons.money_off_csred_rounded, color: Colors.red),
              title: const Text('Potential scam or fraud'),
              onTap: () => _submitReport('Potential scam'),
            ),
            ListTile(
              leading: const Icon(Icons.copy_rounded, color: Colors.blue),
              title: const Text('Duplicate or fake listing'),
              onTap: () => _submitReport('Duplicate'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Listing?'),
        content: const Text('This will permanently remove this item from the marketplace. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(marketplaceRepositoryProvider).deleteListing(widget.listing.id);
              if (mounted) context.pop();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _submitReport(String reason) {
    final user = ref.read(appUserProvider).valueOrNull;
    if (user != null) {
      ref.read(marketplaceRepositoryProvider).reportListing(
        listingId: widget.listing.id,
        reporterId: user.uid,
        reason: reason,
      );
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Thank you. We will review this listing.')));
  }

  void _startChat() async {
    final buyer = ref.read(appUserProvider).valueOrNull;
    if (buyer == null) return;
    
    if (buyer.uid == widget.listing.sellerId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This is your own listing.')));
      return;
    }

    final convId = await ref.read(chatRepositoryProvider).getOrCreateConversation(
      buyerId: buyer.uid,
      sellerId: widget.listing.sellerId,
      listingId: widget.listing.id,
      listingTitle: widget.listing.title,
    );

    if (mounted) {
      context.push('/chat', extra: {
        'conversationId': convId,
        'otherUserName': widget.listing.sellerName,
        'listing': widget.listing,
      });
      ref.read(marketplaceRepositoryProvider).recordChatStarted(widget.listing.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(appUserProvider).valueOrNull;
    final isOwner = currentUser?.uid == widget.listing.sellerId;
    final sellerAsync = ref.watch(otherUserProvider(widget.listing.sellerId));

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(isOwner),
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeroInfo(),
                    _buildInsightsBar(),
                    const Divider(thickness: 8, color: Color(0xFFF8F9FB)),
                    _buildDescription(),
                    const Divider(thickness: 8, color: Color(0xFFF8F9FB)),
                    _buildSellerSection(sellerAsync),
                    const Divider(thickness: 8, color: Color(0xFFF8F9FB)),
                    _buildItemDetails(),
                    const Divider(thickness: 8, color: Color(0xFFF8F9FB)),
                    _buildSafetySection(),
                    const Divider(thickness: 8, color: Color(0xFFF8F9FB)),
                    _buildSimilarItems(),
                    const SizedBox(height: 120),
                  ],
                ),
              ),
            ],
          ),
          _buildStickyActionBar(isOwner),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(bool isOwner) {
    return SliverAppBar(
      expandedHeight: 450,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.white.withOpacity(0.9),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.black, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      actions: [
        CircleAvatar(
          backgroundColor: Colors.white.withOpacity(0.9),
          child: IconButton(
            icon: const Icon(Icons.share_outlined, color: Colors.black, size: 22),
            onPressed: () => Share.share('Check out this ${widget.listing.title} on UniHub!'),
          ),
        ),
        const SizedBox(width: 8),
        CircleAvatar(
          backgroundColor: Colors.white.withOpacity(0.9),
          child: IconButton(
            icon: Icon(_isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                 color: _isSaved ? Colors.red : Colors.black, size: 22),
            onPressed: _toggleSave,
          ),
        ),
        const SizedBox(width: 8),
        if (isOwner)
          CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.9),
            child: IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDelete(),
            ),
          )
        else
          CircleAvatar(
            backgroundColor: Colors.white.withOpacity(0.9),
            child: IconButton(
              icon: const Icon(Icons.more_horiz_rounded, color: Colors.black),
              onPressed: _reportListing,
            ),
          ),
        const SizedBox(width: 16),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) => setState(() => _currentPage = index),
              itemCount: widget.listing.imageUrls.isEmpty ? 1 : widget.listing.imageUrls.length,
              itemBuilder: (context, index) {
                if (widget.listing.imageUrls.isEmpty) {
                  return Container(
                    color: Colors.indigo.shade50,
                    child: Icon(Icons.shopping_bag_outlined, size: 100, color: Colors.indigo.shade200),
                  );
                }
                return Hero(
                  tag: 'listing_img_${widget.listing.id}',
                  child: OptimizedImage(
                    imageUrl: widget.listing.imageUrls[index],
                    fit: BoxFit.cover,
                  ),
                );
              },
            ),
            if (widget.listing.imageUrls.length > 1)
              Positioned(
                bottom: 20,
                right: 20,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentPage + 1} / ${widget.listing.imageUrls.length}',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroInfo() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.listing.category.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(color: Colors.indigo, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  widget.listing.condition.name.toUpperCase(),
                  style: GoogleFonts.plusJakartaSans(color: Colors.orange.shade800, fontSize: 10, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.listing.title,
            style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, height: 1.2),
          ),
          const SizedBox(height: 12),
          Text(
            'KES ${NumberFormat('#,###').format(widget.listing.price)}',
            style: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.indigo),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.location_on_rounded, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                widget.listing.campusLocation,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 12),
              const Icon(Icons.access_time_filled_rounded, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Posted ${DateFormat('MMM dd').format(widget.listing.createdAt)}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _insightItem(Icons.visibility_rounded, '${widget.listing.viewsCount}', 'Views'),
          _insightItem(Icons.favorite_rounded, '${widget.listing.savesCount}', 'Saves'),
          _insightItem(Icons.chat_bubble_rounded, '${widget.listing.chatsStartedCount}', 'Offers'),
        ],
      ),
    );
  }

  Widget _insightItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: Colors.indigo),
            const SizedBox(width: 4),
            Text(value, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15)),
          ],
        ),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDescription() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Description', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Text(
            widget.listing.description,
            maxLines: _isDescriptionExpanded ? null : 4,
            overflow: _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
            style: TextStyle(color: Colors.grey.shade800, height: 1.6, fontSize: 15),
          ),
          if (widget.listing.description.length > 150)
            TextButton(
              onPressed: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
              child: Text(_isDescriptionExpanded ? 'Show less' : 'Read more', 
                style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
    );
  }

  Widget _buildSellerSection(AsyncValue<AppUser> sellerAsync) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Seller Information', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  if (widget.listing.sellerId.isNotEmpty) {
                    context.push('/seller-profile', extra: widget.listing.sellerId);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Seller profile not available')),
                    );
                  }
                },
                child: const Text('View Profile', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          sellerAsync.when(
            data: (seller) => Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade100),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: seller.photoUrl != null ? NetworkImage(seller.photoUrl!) : null,
                        backgroundColor: Colors.indigo.shade50,
                        child: seller.photoUrl == null ? const Icon(Icons.person, color: Colors.indigo) : null,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  seller.fullName.isEmpty ? 'UniHub Student' : seller.fullName, 
                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)
                                ),
                                if (seller.trustScore > 80)
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4),
                                    child: Icon(Icons.verified_rounded, size: 16, color: Colors.blue),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              (seller.university ?? '').isEmpty ? 'UniHub Student' : seller.university!, 
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 13)
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                              const SizedBox(width: 2),
                              Text(
                                seller.averageRating.toStringAsFixed(1), 
                                style: const TextStyle(fontWeight: FontWeight.bold)
                              ),
                            ],
                          ),
                          Text('${seller.ratingsCount} reviews', style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _sellerStat(
                        seller.responseRate.isEmpty ? '95%' : seller.responseRate, 
                        'Response Rate'
                      ),
                      _sellerStat('${seller.activeListingsCount}', 'Active Ads'),
                      _sellerStat(
                        DateFormat('yyyy').format(seller.createdAt ?? DateTime.now()), 
                        'Joined'
                      ),
                    ],
                  ),
                ],
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('Error loading seller data'),
          ),
        ],
      ),
    );
  }

  Widget _sellerStat(String value, String label) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14)),
        Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildItemDetails() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Item Details', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _detailRow('Condition', widget.listing.condition.name.replaceFirst('newCondition', 'New').toUpperCase()),
          _detailRow('Category', widget.listing.category),
          _detailRow('Location', widget.listing.campusLocation),
          _detailRow('Negotiable', widget.listing.isFeatured ? 'Yes' : 'Maybe'), // Mock logic
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
        ],
      ),
    );
  }

  Widget _buildSafetySection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.blue.shade50.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.shade100),
        ),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.security_rounded, color: Colors.blue),
                const SizedBox(width: 12),
                Text('Meetup Safely', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, color: Colors.blue.shade800)),
              ],
            ),
            const SizedBox(height: 12),
            const Text('For your safety, always meet in a well-lit, public area on campus. Inspect the item thoroughly before making payment.',
              style: TextStyle(fontSize: 13, height: 1.5, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildSimilarItems() {
    final similarAsync = ref.watch(similarListingsProvider(widget.listing));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text('You might also like', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 280,
          child: similarAsync.when(
            data: (listings) => ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: listings.length,
              itemBuilder: (context, index) => SizedBox(
                width: 180,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: MarketplaceCard(listing: listings[index], index: index),
                ),
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox(),
          ),
        ),
      ],
    );
  }

  Widget _buildStickyActionBar(bool isOwner) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -4)),
          ],
        ),
        child: SafeArea(
          child: isOwner ? _buildOwnerActions() : _buildBuyerActions(),
        ),
      ),
    );
  }

  Widget _buildBuyerActions() {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: IconButton(
            icon: Icon(_isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                 color: _isSaved ? Colors.red : Colors.black87),
            onPressed: _toggleSave,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton.icon(
            onPressed: _startChat,
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 20),
            label: const Text('Message', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.indigo,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: Colors.indigo.withOpacity(0.3),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ref.watch(otherUserProvider(widget.listing.sellerId)).when(
          data: (seller) => (seller.whatsappNumber != null && seller.whatsappNumber!.isNotEmpty) 
            ? Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: IconButton(
                  icon: const Icon(Icons.send_to_mobile_rounded, color: Color(0xFF25D366)),
                  onPressed: () async {
                    final message = 'Hi ${seller.fullName}, I saw your listing "${widget.listing.title}" on UniHub and I am interested!';
                    final url = 'https://wa.me/${seller.whatsappNumber}?text=${Uri.encodeComponent(message)}';
                    if (await canLaunchUrl(Uri.parse(url))) {
                      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                    }
                  },
                ),
              )
            : const SizedBox.shrink(),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildOwnerActions() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => context.push('/add-listing', extra: widget.listing),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: const Text('Edit Details', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: FilledButton(
            onPressed: () {
              ref.read(marketplaceRepositoryProvider).updateListingStatus(widget.listing.id, ListingStatus.sold);
              context.pop();
            },
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Mark as Sold', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}
