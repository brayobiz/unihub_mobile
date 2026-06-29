import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:unihub_mobile/core/widgets/optimized_image.dart';
import '../../../auth/shared/providers.dart';
import 'package:unihub_mobile/features/auth/domain/models/app_user.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/offer.dart';
import '../../shared/providers.dart';
import '../../../chat/shared/providers.dart';
import '../widgets/marketplace_card.dart';
import '../../../../services/history_service.dart';
import 'package:uuid/uuid.dart';

class ListingDetailScreen extends ConsumerStatefulWidget {
  final Listing listing;
  final String? heroTag;

  const ListingDetailScreen({super.key, required this.listing, this.heroTag});

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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final listing = widget.listing;
      if (listing == null) return;
      
      final userId = ref.read(firebaseAuthProvider).currentUser?.uid;
      ref.read(marketplaceRepositoryProvider).recordView(listing.id, userId: userId);
      
      ref.read(recentHistoryProvider.notifier).addItem(HistoryItem(
        id: listing.id ?? '',
        type: 'listing',
        title: listing.title ?? 'Listing',
        imageUrl: (listing.imageUrls != null && listing.imageUrls.isNotEmpty) ? listing.imageUrls.first : null,
        timestamp: DateTime.now(),
      ));
    });
  }

  void _toggleSave() {
    final listing = widget.listing;
    if (listing == null) return;
    
    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to save items')));
      return;
    }
    setState(() => _isSaved = !_isSaved);
    ref.read(marketplaceRepositoryProvider).toggleSaveListing(user.uid, listing.id);
  }

  void _startChat() async {
    final listing = widget.listing;
    if (listing == null) return;

    final buyer = ref.read(appUserProvider).valueOrNull;
    if (buyer == null) return;
    
    if (buyer.uid == listing.sellerId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This is your own listing.')));
      return;
    }

    final convId = await ref.read(chatRepositoryProvider).getOrCreateConversation(
      buyerId: buyer.uid,
      sellerId: listing.sellerId,
      listingId: listing.id,
      listingTitle: listing.title,
      module: 'marketplace',
    );

    if (mounted) {
      context.push('/chat', extra: {
        'conversationId': convId,
        'otherUserName': listing.sellerName,
        'listing': listing,
      });
      ref.read(marketplaceRepositoryProvider).recordChatStarted(listing.id);
    }
  }

  void _showMakeOfferSheet() {
    final listing = widget.listing;
    if (listing == null) return;

    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;
    
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Make an Offer', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Listing Price: KES ${NumberFormat('#,###').format(listing.price ?? 0)}', style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 24),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Your Offer',
                  prefixText: 'KES ',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: () async {
                    final amount = double.tryParse(controller.text);
                    if (amount != null) {
                      final offer = Offer(
                        id: const Uuid().v4(),
                        listingId: listing.id,
                        buyerId: user.uid,
                        sellerId: listing.sellerId,
                        amount: amount,
                        timestamp: DateTime.now(),
                      );
                      await ref.read(marketplaceRepositoryProvider).makeOffer(offer);
                      if (mounted) {
                         Navigator.pop(context);
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Offer sent!')));
                      }
                    }
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF007BFF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Send Offer', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    if (listing == null) {
      return const Scaffold(body: Center(child: Text('Error: Listing is null')));
    }

    final currentUser = ref.watch(appUserProvider).valueOrNull;
    final String sellerId = listing.sellerId ?? '';
    final bool isOwner = currentUser != null && currentUser.uid == sellerId;
    final sellerAsync = ref.watch(otherUserProvider(sellerId));
    final images = listing.imageUrls ?? <String>[];
    final bool isNegotiable = listing.isNegotiable == true;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildImageGallery(),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildVerifiedBadgeRow(),
                      const SizedBox(height: 12),
                      Text(
                        listing.title ?? 'No Title',
                        style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (listing.description != null && listing.description.isNotEmpty)
                          ? listing.description.split('.').first + '.' 
                          : 'No description provided',
                        style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            'KES ${NumberFormat('#,###').format(listing.price ?? 0)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 26, 
                              fontWeight: FontWeight.w900, 
                              color: const Color(0xFF007BFF)
                            ),
                          ),
                          if (isNegotiable) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F1FF),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Negotiable',
                                style: TextStyle(color: Color(0xFF007BFF), fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSpecsGrid(),
                      const SizedBox(height: 32),
                      Text('Description', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text(
                        listing.description ?? '',
                        maxLines: _isDescriptionExpanded ? null : 3,
                        style: TextStyle(color: Colors.grey.shade700, height: 1.6, fontSize: 15),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
                        child: Text(
                          _isDescriptionExpanded ? 'Read less' : '... Read more',
                          style: const TextStyle(color: Color(0xFF007BFF), fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 32),
                      _buildSellerCard(sellerAsync),
                      const SizedBox(height: 24),
                      _buildSafetyBanner(),
                      const SizedBox(height: 32),
                      _buildSimilarItems(),
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ),
            ],
          ),
          _buildStickyActionBar(isOwner),
        ],
      ),
    );
  }

  Widget _buildImageGallery() {
    final images = widget.listing.imageUrls ?? <String>[];
    final topPadding = MediaQuery.of(context).padding.top;
    
    return SliverAppBar(
      expandedHeight: 420,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      automaticallyImplyLeading: false,
      leading: null,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Row(
              children: [
                // Main Image PageView
                Expanded(
                  flex: 3,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(20, topPadding + 64, 4, 12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (i) => setState(() => _currentPage = i),
                        itemCount: images.isEmpty ? 1 : images.length,
                        itemBuilder: (context, index) {
                          return Hero(
                            tag: index == 0 ? (widget.heroTag ?? 'listing_img_${widget.listing.id}') : 'listing_img_${widget.listing.id}_$index',
                            child: OptimizedImage(
                              imageUrl: images.isEmpty ? '' : images[index],
                              fit: BoxFit.cover,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                
                // Thumbnails Column
                if (images.length > 1)
                  Container(
                    width: MediaQuery.of(context).size.width * 0.28,
                    padding: EdgeInsets.fromLTRB(4, topPadding + 64, 20, 12),
                    child: Column(
                      children: [
                        ...images.skip(1).take(3).indexed.map((entry) {
                          final idx = entry.$1 + 1;
                          final url = entry.$2;
                          final isLast = idx == 3 && images.length > 4;
                          
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: GestureDetector(
                                onTap: () => _pageController.animateToPage(idx, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      OptimizedImage(imageUrl: url, fit: BoxFit.cover),
                                      if (isLast)
                                        Container(
                                          color: Colors.black.withOpacity(0.6),
                                          alignment: Alignment.center,
                                          child: Text('+${images.length - 4}', 
                                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
              ],
            ),
            
            // Top Navigation Buttons
            Positioned(
              top: topPadding + 8,
              left: 16,
              child: _buildCircleButton(Icons.arrow_back, () => context.pop()),
            ),
            Positioned(
              top: topPadding + 8,
              right: 16,
              child: Row(
                children: [
                  _buildCircleButton(Icons.ios_share, () => Share.share('Check this out!')),
                  const SizedBox(width: 12),
                  _buildCircleButton(
                    _isSaved ? Icons.favorite : Icons.favorite_border, 
                    _toggleSave,
                    iconColor: _isSaved ? Colors.red : Colors.black,
                  ),
                ],
              ),
            ),

            // Main Image Index Overlay
            if (images != null && images.isNotEmpty)
              Positioned(
                bottom: 24,
                left: 0,
                right: images.length > 1 ? MediaQuery.of(context).size.width * 0.26 : 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentPage + 1} / ${images.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCircleButton(IconData icon, VoidCallback onTap, {Color? iconColor}) {
    return Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: iconColor ?? Colors.black, size: 20),
        onPressed: onTap,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildVerifiedBadgeRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFE8F5E9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified, color: Color(0xFF4CAF50), size: 14),
              SizedBox(width: 4),
              Text('Verified Seller', style: TextStyle(color: Color(0xFF4CAF50), fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        Text(
          'Posted ${DateFormat('h').format(widget.listing.createdAt)} hours ago  •  ${widget.listing.viewsCount} views',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildSpecsGrid() {
    return Row(
      children: [
        _specItem(Icons.sentiment_satisfied_alt_rounded, 'Condition', 
          widget.listing.condition.name.replaceFirst('newCondition', 'New')),
        if (widget.listing.brand != null) ...[
          const SizedBox(width: 8),
          _specItem(Icons.branding_watermark_outlined, 'Brand', widget.listing.brand!),
        ],
        if (widget.listing.storage != null) ...[
          const SizedBox(width: 8),
          _specItem(Icons.storage_rounded, 'Storage', widget.listing.storage!),
        ],
        if (widget.listing.color != null) ...[
          const SizedBox(width: 8),
          _specItem(Icons.palette_outlined, 'Color', widget.listing.color!),
        ],
      ],
    );
  }

  Widget _specItem(IconData icon, String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: Colors.grey.shade700),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: Colors.grey.shade500, fontSize: 10)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerCard(AsyncValue<AppUser> sellerAsync) {
    return sellerAsync.when(
      data: (seller) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: seller.photoUrl != null ? NetworkImage(seller.photoUrl!) : null,
                      backgroundColor: Colors.grey.shade100,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: const Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              seller.fullName, 
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: Color(0xFF007BFF), size: 16),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text('${seller.averageRating} (${seller.ratingsCount} reviews)', 
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            const SizedBox(width: 8),
                            Text('•', style: TextStyle(color: Colors.grey.shade400)),
                            const SizedBox(width: 8),
                            Text('${seller.completedSalesCount} sales', 
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed: () => context.push('/seller-profile', extra: widget.listing.sellerId),
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: const Text('View Profile', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.school_outlined, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    seller.university ?? 'UniHub Student', 
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 8),
                Text('Usually responds within 1 hour', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSafetyBanner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F7FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: Color(0xFF4CAF50)),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Buy safely on UniHub', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text('Meet in a public place and inspect before you pay.', style: TextStyle(color: Colors.black54, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ],
      ),
    );
  }

  Widget _buildSimilarItems() {
    final similarAsync = ref.watch(similarListingsProvider(widget.listing));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('You might also like', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SizedBox(
          height: 250,
          child: similarAsync.when(
            data: (listings) => ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: listings.length,
              itemBuilder: (context, index) => Container(
                width: 170,
                margin: const EdgeInsets.only(right: 16),
                child: MarketplaceCard(
                  listing: listings[index], 
                  index: index,
                  heroTag: 'hero_detail_similar_${listings[index].id}',
                ),
              ),
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
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
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
        ),
        child: Row(
          children: [
            Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: IconButton(
                icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF007BFF)),
                onPressed: _startChat,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: isOwner ? null : _showMakeOfferSheet,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF007BFF),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(isOwner ? 'Your Listing' : 'Make an Offer', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
