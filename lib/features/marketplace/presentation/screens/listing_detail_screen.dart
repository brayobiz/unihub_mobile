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
import 'package:unihub_mobile/features/auth/presentation/controllers/auth_controller.dart';
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
      
      final userId = ref.read(firebaseAuthProvider).currentUser?.uid;
      
      // Only record a view if it's not the seller themselves
      if (userId != listing.sellerId) {
        ref.read(marketplaceRepositoryProvider).recordView(listing.id, userId: userId);
      }
      
      ref.read(recentHistoryProvider.notifier).addItem(HistoryItem(
        id: listing.id,
        type: 'listing',
        title: listing.title,
        imageUrl: (listing.imageUrls.isNotEmpty) ? listing.imageUrls.first : null,
        timestamp: DateTime.now(),
      ));
    });
  }

  void _toggleSave(Listing listing) {
    if (listing == null) return;
    
    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to save items')));
      return;
    }
    setState(() => _isSaved = !_isSaved);
    ref.read(marketplaceRepositoryProvider).toggleSaveListing(user.uid, listing.id);
  }

  void _startChat(Listing listing) async {
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

  void _shareListing(Listing listing) {
    final text = 'Check out this ${listing.title} for KES ${NumberFormat('#,###').format(listing.price)} on UniHub Marketplace! \n\nDownload UniHub to view more: https://unihub.app/marketplace/${listing.id}';
    Share.share(text);
    ref.read(marketplaceRepositoryProvider).recordShare(listing.id);
  }

  void _showReportDialog(Listing listing) {
    final reasons = [
      'Scam or fraud',
      'Fake product',
      'Wrong category',
      'Duplicate listing',
      'Inappropriate content',
      'Other'
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Listing'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.map((reason) => ListTile(
            title: Text(reason),
            onTap: () async {
              final user = ref.read(appUserProvider).valueOrNull;
              if (user != null) {
                await ref.read(marketplaceRepositoryProvider).reportListing(
                  listingId: listing.id,
                  reporterId: user.uid,
                  reason: reason,
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report submitted. Thank you for keeping UniHub safe!')),
                  );
                }
              }
            },
          )).toList(),
        ),
      ),
    );
  }

  void _showMakeOfferSheet(Listing listing) {
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
                  'Listing Price: KES ${NumberFormat('#,###').format(listing.price)}', 
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
    final initialListing = widget.listing;
    
    // Watch real-time listing updates for viewsCount, price changes, etc.
    final listingAsync = ref.watch(listingProvider(initialListing.id));
    
    return listingAsync.when(
      data: (listing) {
        if (listing == null) {
          return const Scaffold(body: Center(child: Text('Listing no longer available.')));
        }

        final currentUser = ref.watch(appUserProvider).valueOrNull;
        final String sellerId = listing.sellerId;
        final bool isOwner = currentUser != null && currentUser.uid == sellerId;
        final sellerAsync = ref.watch(otherUserProvider(sellerId));
        final images = listing.imageUrls;

        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildImageGallery(listing),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          _buildVerifiedBadgeRow(sellerAsync, listing),
                          const SizedBox(height: 12),
                          _buildAvailabilityBadge(listing),
                          const SizedBox(height: 8),
                          Text(
                            listing.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 24, 
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Text(
                                'KES ${NumberFormat('#,###').format(listing.price)}',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 26, 
                                  fontWeight: FontWeight.w900, 
                                  color: AppColors.marketplaceBlue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              _buildPriceBadge(listing),
                            ],
                          ),
                          const SizedBox(height: 24),
                          _buildConditionSection(listing),
                          const SizedBox(height: 24),
                          _buildSpecsGrid(listing),
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
                            listing.description,
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
                          _buildSellerCard(sellerAsync, listing),
                          _buildMoreFromSeller(sellerId, listing),
                          _buildSafetyBanner(),
                          _buildSimilarItems(listing),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              _buildStickyActionBar(isOwner, listing),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  void _openFullScreenGallery(int initialIndex, Listing listing) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenGallery(
          imageUrls: listing.imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  Widget _buildAvailabilityBadge(Listing listing) {
    final status = listing.status;
    final isRecent = DateTime.now().difference(listing.createdAt).inHours < 48;

    if (status == ListingStatus.active && !isRecent) return const SizedBox.shrink();

    Color color;
    String label;
    IconData icon;

    if (status == ListingStatus.active && isRecent) {
      color = AppColors.secondary;
      label = 'RECENTLY LISTED';
      icon = Icons.auto_awesome_rounded;
    } else {
      switch (status) {
        case ListingStatus.sold:
          color = AppColors.error;
          label = 'SOLD';
          icon = Icons.shopping_bag_rounded;
          break;
        case ListingStatus.reserved:
          color = Colors.orange;
          label = 'RESERVED';
          icon = Icons.lock_clock_rounded;
          break;
        default:
          return const SizedBox.shrink();
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBadge(Listing listing) {
    final theme = Theme.of(context);
    final isNegotiable = listing.isNegotiable;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isNegotiable 
            ? AppColors.marketplaceBlue.withValues(alpha: 0.1) 
            : theme.colorScheme.onSurface.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isNegotiable ? 'Negotiable' : 'Fixed Price',
        style: TextStyle(
          color: isNegotiable ? AppColors.marketplaceBlue : theme.colorScheme.onSurfaceVariant, 
          fontSize: 12, 
          fontWeight: FontWeight.bold
        ),
      ),
    );
  }

  Widget _buildConditionSection(Listing listing) {
    final theme = Theme.of(context);
    final cond = listing.condition;
    String label;
    String explanation;
    Color color;

    switch (cond) {
      case ListingCondition.newCondition:
        label = 'Brand New';
        explanation = 'Item is in its original packaging, never used.';
        color = AppColors.success;
        break;
      case ListingCondition.likeNew:
        label = 'Like New';
        explanation = 'Item is in perfect condition, looks unused.';
        color = Colors.blue;
        break;
      case ListingCondition.good:
        label = 'Excellent';
        explanation = 'Minor signs of use, fully functional.';
        color = Colors.orange;
        break;
      case ListingCondition.fair:
        label = 'Fair';
        explanation = 'Significant wear, works but may have minor issues.';
        color = Colors.red;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_outline_rounded, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  explanation,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(Listing listing) {
    final images = listing.imageUrls ?? <String>[];
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
                      child: GestureDetector(
                        onTap: () => _openFullScreenGallery(_currentPage, listing),
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (i) => setState(() => _currentPage = i),
                          itemCount: images.isEmpty ? 1 : images.length,
                          itemBuilder: (context, index) {
                            return Hero(
                              tag: index == 0 ? (widget.heroTag ?? 'listing_img_${listing.id}') : 'listing_img_${listing.id}_$index',
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
                                onTap: () {
                                  _pageController.animateToPage(idx, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                                  setState(() => _currentPage = idx);
                                },
                                onLongPress: () => _openFullScreenGallery(idx, listing),
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
                  _buildCircleButton(Icons.ios_share, () => _shareListing(listing)),
                  const SizedBox(width: 12),
                  _buildCircleButton(
                    _isSaved ? Icons.favorite : Icons.favorite_border, 
                    () => _toggleSave(listing),
                    iconColor: _isSaved ? AppColors.error : Theme.of(context).colorScheme.onSurface,
                  ),
                  const SizedBox(width: 12),
                  _buildCircleButton(Icons.report_gmailerrorred_rounded, () => _showReportDialog(listing)),
                  const SizedBox(width: 12),
                  _buildBlockActionButton(listing.sellerId),
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
            color: Colors.black.withValues(alpha: 0.1),
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

  Widget _buildBlockActionButton(String sellerId) {
    final user = ref.watch(appUserProvider).valueOrNull;
    if (user == null || user.uid == sellerId) return const SizedBox.shrink();
    
    final isBlocked = user.blockedUids.contains(sellerId);
    
    return _buildCircleButton(
      isBlocked ? Icons.block_flipped : Icons.block_outlined, 
      () {
        if (isBlocked) {
          ref.read(authControllerProvider.notifier).unblockUser(sellerId);
        } else {
          _showBlockConfirmation(sellerId);
        }
      },
      iconColor: isBlocked ? AppColors.success : AppColors.error,
    );
  }

  void _showBlockConfirmation(String sellerId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Block Seller?'),
        content: const Text('You will no longer see listings or receive messages from this student.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(authControllerProvider.notifier).blockUser(sellerId);
              Navigator.pop(context);
              context.pop(); // Go back to marketplace
            }, 
            child: const Text('Block', style: TextStyle(color: AppColors.error))
          ),
        ],
      ),
    );
  }

  Widget _buildVerifiedBadgeRow(AsyncValue<AppUser> sellerAsync, Listing listing) {
    final theme = Theme.of(context);
    return sellerAsync.when(
      data: (seller) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (seller.isVerifiedSeller)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                children: [
                  Icon(Icons.verified, color: AppColors.success, size: 14),
                  SizedBox(width: 4),
                  Text('Verified Seller', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Listed ${DateFormatter.formatRelative(listing.createdAt)}',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              if (listing.updatedAt != null)
                Text(
                  'Updated ${DateFormatter.formatRelative(listing.updatedAt!)}',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 10),
                ),
              Text(
                '${listing.viewsCount} views',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
      loading: () => const SizedBox(height: 28),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSpecsGrid(Listing listing) {
    final attributes = listing.attributes;
    final List<Map<String, dynamic>> specItems = [];

    // Add Condition first
    specItems.add({
      'icon': Icons.sentiment_satisfied_alt_rounded,
      'label': 'Condition',
      'value': listing.condition.name.replaceFirst('newCondition', 'New'),
    });

    if (listing.quantity > 1) {
      specItems.add({
        'icon': Icons.inventory_2_outlined,
        'label': 'Quantity',
        'value': listing.quantity.toString(),
      });
    }

    // Add legacy fields if present and not in attributes
    if (listing.brand != null && !attributes.containsKey('brand')) {
      specItems.add({'icon': Icons.branding_watermark_outlined, 'label': 'Brand', 'value': listing.brand});
    }
    if (listing.storage != null && !attributes.containsKey('storage')) {
      specItems.add({'icon': Icons.storage_rounded, 'label': 'Storage', 'value': listing.storage});
    }
    if (listing.color != null && !attributes.containsKey('color')) {
      specItems.add({'icon': Icons.palette_outlined, 'label': 'Color', 'value': listing.color});
    }

    // Add dynamic attributes
    attributes.forEach((key, value) {
      if (value == null || value.toString().isEmpty) return;
      
      // Category-specific relevant fields only
      final category = listing.category;
      bool isRelevant = false;
      
      if (category == 'Phones & Accessories') {
         isRelevant = ['brand', 'model', 'storage', 'ram', 'batteryhealth'].contains(key.toLowerCase());
      } else if (category == 'Vehicle Accessories') {
         isRelevant = ['make', 'model', 'year', 'mileage', 'fueltype'].contains(key.toLowerCase());
      } else if (category == 'Shoes') {
         isRelevant = ['brand', 'size', 'material'].contains(key.toLowerCase());
      } else {
         isRelevant = true; // Show all for other categories
      }
      
      if (!isRelevant) return;

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

  Widget _buildSellerCard(AsyncValue<AppUser> sellerAsync, Listing listing) {
    final theme = Theme.of(context);
    return sellerAsync.when(
      data: (seller) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: seller.photoUrl != null ? NetworkImage(seller.photoUrl!) : null,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
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
                              style: theme.textTheme.titleSmall?.copyWith(
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
                          if (seller.isOnline) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.orange,
                                borderRadius: BorderRadius.circular(6),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withValues(alpha: 0.3),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.bolt_rounded, color: Colors.white, size: 10),
                                  SizedBox(width: 2),
                                  Text(
                                    'Available Now', 
                                    style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: OutlinedButton(
                    onPressed: () => context.push('/seller-profile', extra: listing.sellerId),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.8)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      minimumSize: const Size(0, 36),
                    ),
                    child: Text(
                      'View Profile', 
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSellerActivityInfo(seller),
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
                Icon(Icons.calendar_today_outlined, size: 16, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text('Member since ${DateFormat.yMMM().format(seller.createdAt ?? DateTime.now())}', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
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
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.shield_outlined, color: AppColors.success),
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
            Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildSimilarItems(Listing listing) {
    final similarAsync = ref.watch(similarListingsProvider(listing));
    
    return similarAsync.when(
      data: (listings) {
        if (listings.isEmpty) return const SizedBox.shrink();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            Text(
              'Similar Listings', 
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
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
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildMoreFromSeller(String sellerId, Listing listing) {
    if (sellerId.isEmpty) return const SizedBox.shrink();
    
    final moreFromSellerAsync = ref.watch(moreFromSellerProvider(sellerId));
    
    return moreFromSellerAsync.when(
      data: (listings) {
        final others = listings.where((l) => l.id != listing.id).toList();
        if (others.isEmpty) return const SizedBox.shrink();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'More From This Seller', 
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/seller-profile', extra: sellerId),
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: others.length,
                itemBuilder: (context, index) => Container(
                  width: 170,
                  margin: const EdgeInsets.only(right: 16),
                  child: MarketplaceCard(
                    listing: others[index], 
                    index: index,
                    heroTag: 'hero_detail_seller_${others[index].id}',
                  ),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSellerActivityInfo(AppUser seller) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _activityItem('Response', seller.responseRate),
        _activityItem('Active', seller.lastSeen != null ? DateFormatter.formatRelative(seller.lastSeen!) : 'Recently'),
        _activityItem('Listings', seller.activeListingsCount.toString()),
      ],
    );
  }

  Widget _activityItem(String label, String value) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
        Text(label, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }

  Widget _buildStickyActionBar(bool isOwner, Listing listing) {
    final theme = Theme.of(context);
    final status = listing.status;
    final isSold = status == ListingStatus.sold;

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
                icon: Icon(Icons.chat_bubble_outline, color: isSold ? AppColors.grey : AppColors.marketplaceBlue),
                onPressed: (isOwner || isSold) ? null : () => _startChat(listing),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: (isOwner || isSold) ? null : () => _showMakeOfferSheet(listing),
                  style: FilledButton.styleFrom(
                    backgroundColor: isSold ? AppColors.grey : AppColors.marketplaceBlue,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    isSold ? 'Item Sold' : (isOwner ? 'Your Listing' : 'Make an Offer'), 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class FullScreenGallery extends StatelessWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullScreenGallery({super.key, required this.imageUrls, required this.initialIndex});

  @override
  Widget build(BuildContext context) {
    final PageController pageController = PageController(initialPage: initialIndex);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: pageController,
            itemCount: imageUrls.length,
            itemBuilder: (context, index) {
              return Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Hero(
                    tag: 'listing_img_full_$index',
                    child: OptimizedImage(
                      imageUrl: imageUrls[index],
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 40,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black.withOpacity(0.5),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: ListenableBuilder(
                  listenable: pageController,
                  builder: (context, child) {
                    final page = pageController.hasClients ? (pageController.page?.round() ?? initialIndex) : initialIndex;
                    return Text(
                      '${page + 1} / ${imageUrls.length}',
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
