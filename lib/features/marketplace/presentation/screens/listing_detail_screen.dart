import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/core/widgets/optimized_image.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../auth/shared/providers.dart';
import 'package:unihub_mobile/features/auth/domain/models/app_user.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/offer.dart';
import '../../shared/providers.dart';
import '../../../chat/domain/models/chat_context.dart';
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

    final chatContext = ChatContext(
      type: 'marketplace',
      id: listing.id,
      title: listing.title,
      thumbnail: (listing.imageUrls != null && listing.imageUrls.isNotEmpty) ? listing.imageUrls.first : null,
      metadata: {
        'price': listing.price,
      },
    );

    final convId = await ref.read(chatRepositoryProvider).getOrCreateConversation(
      participantIds: [buyer.uid, listing.sellerId],
      context: chatContext,
    );

    if (mounted) {
      context.push('/chat', extra: {
        'conversationId': convId,
        'otherUserName': listing.sellerName,
        'context': chatContext,
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
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) {
        final mTheme = Theme.of(context);
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Make an Offer', 
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 20, 
                    fontWeight: FontWeight.bold,
                    color: mTheme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Listing Price: KES ${NumberFormat('#,###').format(listing.price ?? 0)}', 
                  style: TextStyle(color: mTheme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: controller,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: TextStyle(color: mTheme.colorScheme.onSurface),
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
                      backgroundColor: AppColors.marketplaceBlue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Send Offer', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
      backgroundColor: theme.colorScheme.surface,
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
                      _buildVerifiedBadgeRow(sellerAsync),
                      const SizedBox(height: 12),
                      Text(
                        listing.title ?? 'No Title',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 24, 
                          fontWeight: FontWeight.w800,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        (listing.description != null && listing.description.isNotEmpty)
                          ? listing.description.split('.').first + '.' 
                          : 'No description provided',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 15),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Text(
                            'KES ${NumberFormat('#,###').format(listing.price ?? 0)}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 26, 
                              fontWeight: FontWeight.w900, 
                              color: AppColors.marketplaceBlue,
                            ),
                          ),
                          if (isNegotiable) ...[
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.negotiableBg,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Negotiable',
                                style: TextStyle(color: AppColors.marketplaceBlue, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 24),
                      _buildSpecsGrid(),
                      const SizedBox(height: 32),
                      Text(
                        'Description', 
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        listing.description ?? '',
                        maxLines: _isDescriptionExpanded ? null : 3,
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.6, fontSize: 15),
                      ),
                      GestureDetector(
                        onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
                        child: Text(
                          _isDescriptionExpanded ? 'Read less' : '... Read more',
                          style: const TextStyle(color: AppColors.marketplaceBlue, fontWeight: FontWeight.bold),
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
    
    final theme = Theme.of(context);
    return SliverAppBar(
      expandedHeight: 420,
      pinned: true,
      elevation: 0,
      backgroundColor: theme.colorScheme.surface,
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
                    iconColor: _isSaved ? AppColors.error : Theme.of(context).colorScheme.onSurface,
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
    final theme = Theme.of(context);
    return Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
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
        icon: Icon(icon, color: iconColor ?? theme.colorScheme.onSurface, size: 20),
        onPressed: onTap,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildVerifiedBadgeRow(AsyncValue<AppUser> sellerAsync) {
    final theme = Theme.of(context);
    return sellerAsync.when(
      data: (seller) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (seller.isVerifiedSeller)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.verifiedSellerBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified, color: AppColors.verifiedSellerIcon, size: 14),
                  SizedBox(width: 4),
                  Text('Verified Seller', style: TextStyle(color: AppColors.verifiedSellerIcon, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: theme.colorScheme.onSurfaceVariant, size: 14),
                  const SizedBox(width: 4),
                  Text('Student Listing', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          Text(
            'Posted ${DateFormatter.formatRelative(widget.listing.createdAt)}  •  ${widget.listing.viewsCount} views',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
          ),
        ],
      ),
      loading: () => const SizedBox(height: 28),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSpecsGrid() {
    final attributes = widget.listing.attributes;
    final List<Map<String, dynamic>> specItems = [];

    // Add Condition first
    specItems.add({
      'icon': Icons.sentiment_satisfied_alt_rounded,
      'label': 'Condition',
      'value': widget.listing.condition.name.replaceFirst('newCondition', 'New'),
    });

    if (widget.listing.quantity > 1) {
      specItems.add({
        'icon': Icons.inventory_2_outlined,
        'label': 'Quantity',
        'value': widget.listing.quantity.toString(),
      });
    }

    // Add legacy fields if present and not in attributes
    if (widget.listing.brand != null && !attributes.containsKey('brand')) {
      specItems.add({'icon': Icons.branding_watermark_outlined, 'label': 'Brand', 'value': widget.listing.brand});
    }
    if (widget.listing.storage != null && !attributes.containsKey('storage')) {
      specItems.add({'icon': Icons.storage_rounded, 'label': 'Storage', 'value': widget.listing.storage});
    }
    if (widget.listing.color != null && !attributes.containsKey('color')) {
      specItems.add({'icon': Icons.palette_outlined, 'label': 'Color', 'value': widget.listing.color});
    }

    // Add dynamic attributes
    attributes.forEach((key, value) {
      if (value == null || value.toString().isEmpty) return;
      
      IconData icon;
      switch (key.toLowerCase()) {
        case 'brand': icon = Icons.branding_watermark_outlined; break;
        case 'storage': icon = Icons.storage_rounded; break;
        case 'color': icon = Icons.palette_outlined; break;
        case 'model': icon = Icons.model_training_outlined; break;
        case 'size': icon = Icons.straighten_rounded; break;
        case 'material': icon = Icons.layers_outlined; break;
        case 'year': icon = Icons.calendar_today_rounded; break;
        case 'mileage': icon = Icons.speed_rounded; break;
        case 'author': icon = Icons.person_outline_rounded; break;
        case 'edition': icon = Icons.menu_book_rounded; break;
        default: icon = Icons.info_outline_rounded;
      }
      
      specItems.add({
        'icon': icon,
        'label': key.isNotEmpty ? (key[0].toUpperCase() + key.substring(1)) : key,
        'value': value.toString(),
      });
    });

    if (specItems.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (var i = 0; i < specItems.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                _specItem(specItems[i]['icon'], specItems[i]['label'], specItems[i]['value']),
                const SizedBox(width: 8),
                if (i + 1 < specItems.length)
                  _specItem(specItems[i + 1]['icon'], specItems[i + 1]['label'], specItems[i + 1]['value'])
                else
                  const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
      ],
    );
  }

  Widget _specItem(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10)),
            Text(
              value, 
              style: TextStyle(
                fontWeight: FontWeight.bold, 
                fontSize: 12,
                color: theme.colorScheme.onSurface,
              ), 
              maxLines: 1, 
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSellerCard(AsyncValue<AppUser> sellerAsync) {
    final theme = Theme.of(context);
    return sellerAsync.when(
      data: (seller) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant),
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
                      backgroundColor: theme.colorScheme.surfaceVariant,
                    ),
                    if (seller.isOnline)
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: theme.colorScheme.surface, width: 2),
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
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.bold, 
                                fontSize: 16,
                                color: theme.colorScheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (seller.isVerifiedSeller) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified, color: AppColors.marketplaceBlue, size: 16),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            if (seller.isOnline) ...[
                              const Text('Online Now', style: TextStyle(color: AppColors.success, fontSize: 12, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Text('•', style: TextStyle(color: theme.colorScheme.outlineVariant)),
                              const SizedBox(width: 8),
                            ],
                            const Icon(Icons.star, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text('${seller.averageRating} (${seller.ratingsCount} reviews)', 
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                            const SizedBox(width: 8),
                            Text('•', style: TextStyle(color: theme.colorScheme.outlineVariant)),
                            const SizedBox(width: 8),
                            Text('${seller.completedSalesCount} sales', 
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
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
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Text(
                    'View Profile', 
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.school_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    seller.university ?? 'UniHub Student', 
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text('Usually responds within 1 hour', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
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
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.safetyBannerBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.shield_outlined, color: AppColors.verifiedSellerIcon),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Buy safely on UniHub', 
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 14,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  'Meet in a public place and inspect before you pay.', 
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: theme.colorScheme.outlineVariant),
        ],
      ),
    );
  }

  Widget _buildSimilarItems() {
    final similarAsync = ref.watch(similarListingsProvider(widget.listing));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'You might also like', 
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18, 
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
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
    final theme = Theme.of(context);
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05), 
              blurRadius: 20, 
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 56,
              width: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: IconButton(
                icon: const Icon(Icons.chat_bubble_outline, color: AppColors.marketplaceBlue),
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
                    backgroundColor: AppColors.marketplaceBlue,
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
