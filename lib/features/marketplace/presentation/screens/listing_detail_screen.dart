import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/core/widgets/optimized_image.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../auth/shared/providers.dart';
import 'package:unihub_mobile/features/auth/domain/models/app_user.dart';
import 'package:unihub_mobile/features/auth/presentation/controllers/auth_controller.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/offer.dart';
import '../../domain/models/review.dart';
import '../../shared/providers.dart';
import '../../../chat/domain/models/chat_context.dart';
import '../../../chat/shared/providers.dart';
import '../widgets/marketplace_card.dart';
import '../../../../services/history_service.dart';
import 'package:uuid/uuid.dart';

class ListingDetailScreen extends ConsumerWidget {
  final Listing? listing;
  final String listingId;
  final String? heroTag;

  const ListingDetailScreen({
    super.key, 
    this.listing, 
    required this.listingId,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch real-time listing updates for viewsCount, price changes, etc.
    final listingAsync = ref.watch(listingProvider(listingId));
    
    return listingAsync.when(
      data: (fetchedListing) {
        final currentListing = fetchedListing ?? listing;
        if (currentListing == null) {
          return const Scaffold(body: Center(child: Text('Listing no longer available.')));
        }

        return _ListingDetailContent(
          key: ValueKey('detail_$listingId'),
          listing: currentListing,
          heroTag: heroTag,
        );
      },
      loading: () => listing != null 
          ? _ListingDetailContent(
              key: ValueKey('detail_$listingId'),
              listing: listing!, 
              heroTag: heroTag, 
              isLoading: true,
            )
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _ListingDetailContent extends ConsumerStatefulWidget {
  final Listing listing;
  final String? heroTag;
  final bool isLoading;

  const _ListingDetailContent({
    super.key,
    required this.listing,
    this.heroTag,
    this.isLoading = false,
  });

  @override
  ConsumerState<_ListingDetailContent> createState() => _ListingDetailContentState();
}

class _ListingDetailContentState extends ConsumerState<_ListingDetailContent> {
  bool _isDescriptionExpanded = false;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recordViewAndHistory(widget.listing);
    });
  }

  void _recordViewAndHistory(Listing listing) {
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
  }

  void _startChat() async {
    final listing = widget.listing;
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
      thumbnail: listing.imageUrls.isNotEmpty ? listing.imageUrls.first : null,
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

  void _shareListing() {
    final listing = widget.listing;
    final text = 'Check out this ${listing.title} for KES ${NumberFormat("#,###").format(listing.price)} on UniHub Marketplace! \n\nDownload UniHub to view more: https://unihub.app/marketplace/${listing.id}';
    Share.share(text);
    ref.read(marketplaceRepositoryProvider).recordShare(listing.id);
  }

  void _showReportDialog() {
    final listing = widget.listing;
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

  void _showMakeOfferSheet() {
    final listing = widget.listing;
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
                  'Listing Price: KES ${NumberFormat("#,###").format(listing.price)}', 
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
    final currentUser = ref.watch(appUserProvider).valueOrNull;
    final bool isOwner = currentUser != null && currentUser.uid == listing.sellerId;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Stack(
        children: [
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildImageGallery(listing),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 20),
                    _VerifiedBadgeRow(listing: listing),
                    const SizedBox(height: 12),
                    _AvailabilityBadge(listing: listing),
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
                          'KES ${NumberFormat("#,###").format(listing.price)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 26, 
                            fontWeight: FontWeight.w900, 
                            color: AppColors.marketplaceBlue,
                          ),
                        ),
                        const SizedBox(width: 12),
                        _PriceBadge(listing: listing),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _ConditionSection(listing: listing),
                    const SizedBox(height: 24),
                    _SpecsGrid(listing: listing),
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
                        _isDescriptionExpanded ? 'Read Less' : '... Read More',
                        style: const TextStyle(color: AppColors.marketplaceBlue, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _SellerCard(listing: listing),
                    _ReviewsSection(listing: listing),
                    _MoreFromSeller(listing: listing),
                    const _SafetyBanner(),
                    _SimilarItems(listing: listing),
                    const SizedBox(height: 120),
                  ]),
                ),
              ),
            ],
          ),
          _StickyActionBar(
            listing: listing,
            isOwner: isOwner,
            onStartChat: _startChat,
            onMakeOffer: _showMakeOfferSheet,
          ),
          if (widget.isLoading)
             const Positioned.fill(
               child: Center(child: CircularProgressIndicator()),
             ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(Listing listing) {
    final images = listing.imageUrls;
    final topPadding = MediaQuery.of(context).padding.top;
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    
    final theme = Theme.of(context);
    return SliverAppBar(
      expandedHeight: isLandscape ? 280 : 420,
      pinned: true,
      elevation: 0,
      backgroundColor: theme.colorScheme.surface,
      automaticallyImplyLeading: false,
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          children: [
            Row(
              children: [
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
            Positioned(
              top: topPadding + 8,
              left: 16,
              child: _CircleButton(icon: Icons.arrow_back, onTap: () => context.pop()),
            ),
            Positioned(
              top: topPadding + 8,
              right: 16,
              child: Row(
                children: [
                  _CircleButton(icon: Icons.ios_share, onTap: _shareListing),
                  const SizedBox(width: 12),
                  _SaveButton(listing: listing),
                  const SizedBox(width: 12),
                  _CircleButton(icon: Icons.report_gmailerrorred_rounded, onTap: _showReportDialog),
                  const SizedBox(width: 12),
                  _BlockButton(sellerId: listing.sellerId),
                ],
              ),
            ),
            if (images.isNotEmpty)
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
}

class _VerifiedBadgeRow extends ConsumerWidget {
  final Listing listing;
  const _VerifiedBadgeRow({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sellerAsync = ref.watch(otherUserProvider(listing.sellerId));

    return sellerAsync.when(
      data: (seller) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (seller.isVerifiedSeller)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
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
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
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
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7), fontSize: 10),
                ),
              Text(
                '${listing.viewsCount} views',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7), fontSize: 10),
              ),
            ],
          ),
        ],
      ),
      loading: () => const SizedBox(height: 28),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  final Listing listing;
  const _AvailabilityBadge({required this.listing});

  @override
  Widget build(BuildContext context) {
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
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
}

class _PriceBadge extends StatelessWidget {
  final Listing listing;
  const _PriceBadge({required this.listing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNegotiable = listing.isNegotiable;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isNegotiable 
            ? AppColors.marketplaceBlue.withOpacity(0.1) 
            : theme.colorScheme.onSurface.withOpacity(0.05),
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
}

class _ConditionSection extends StatelessWidget {
  final Listing listing;
  const _ConditionSection({required this.listing});

  @override
  Widget build(BuildContext context) {
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
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
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
}

class _SpecsGrid extends StatelessWidget {
  final Listing listing;
  const _SpecsGrid({required this.listing});

  @override
  Widget build(BuildContext context) {
    final attributes = listing.attributes;
    final List<Map<String, dynamic>> specItems = [];

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

    if (listing.brand != null && !attributes.containsKey('brand')) {
      specItems.add({'icon': Icons.branding_watermark_outlined, 'label': 'Brand', 'value': listing.brand});
    }
    if (listing.storage != null && !attributes.containsKey('storage')) {
      specItems.add({'icon': Icons.storage_rounded, 'label': 'Storage', 'value': listing.storage});
    }
    if (listing.color != null && !attributes.containsKey('color')) {
      specItems.add({'icon': Icons.palette_outlined, 'label': 'Color', 'value': listing.color});
    }

    attributes.forEach((key, value) {
      if (value == null || value.toString().isEmpty) return;
      
      final category = listing.category;
      bool isRelevant = false;
      
      if (category == 'Phones & Accessories') {
         isRelevant = ['brand', 'model', 'storage', 'ram', 'batteryhealth'].contains(key.toLowerCase());
      } else if (category == 'Vehicle Accessories') {
         isRelevant = ['make', 'model', 'year', 'mileage', 'fueltype'].contains(key.toLowerCase());
      } else if (category == 'Shoes') {
         isRelevant = ['brand', 'size', 'material'].contains(key.toLowerCase());
      } else {
         isRelevant = true;
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

    return RepaintBoundary(
      child: Column(
        children: [
          for (var i = 0; i < specItems.length; i += 2)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  _specItem(context, specItems[i]['icon'], specItems[i]['label'], specItems[i]['value']),
                  const SizedBox(width: 8),
                  if (i + 1 < specItems.length)
                    _specItem(context, specItems[i + 1]['icon'], specItems[i + 1]['label'], specItems[i + 1]['value'])
                  else
                    const Expanded(child: SizedBox.shrink()),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _specItem(BuildContext context, IconData icon, String label, String value) {
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
}

class _SellerCard extends ConsumerWidget {
  final Listing listing;
  const _SellerCard({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sellerAsync = ref.watch(otherUserProvider(listing.sellerId));

    return sellerAsync.when(
      data: (seller) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
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
                            _OnlineStatusBadge(),
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
                            Text("${seller.averageRating} (${seller.ratingsCount} reviews)", 
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                            const SizedBox(width: 8),
                            Text('•', style: TextStyle(color: theme.colorScheme.outlineVariant)),
                            const SizedBox(width: 8),
                            Text("${seller.completedSalesCount} sales", 
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
                    onPressed: () => context.push("/seller-profile/${listing.sellerId}", extra: listing.sellerId),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.8)),
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
            _SellerActivityInfo(seller: seller),
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
}

class _OnlineStatusBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.orange,
        borderRadius: BorderRadius.circular(6),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
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
    );
  }
}

class _SellerActivityInfo extends StatelessWidget {
  final AppUser seller;
  const _SellerActivityInfo({required this.seller});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _activityItem(context, 'Response', seller.responseRate),
        _activityItem(context, 'Active', seller.lastSeen != null ? DateFormatter.formatRelative(seller.lastSeen!) : 'Recently'),
        _activityItem(context, 'Listings', seller.activeListingsCount.toString()),
      ],
    );
  }

  Widget _activityItem(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
        Text(label, style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}

class _ReviewsSection extends ConsumerWidget {
  final Listing listing;
  const _ReviewsSection({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reviewsAsync = ref.watch(sellerReviewsProvider(listing.sellerId));
    final currentUser = ref.watch(appUserProvider).valueOrNull;
    final isOwner = currentUser?.uid == listing.sellerId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Seller Reviews',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (!isOwner && currentUser != null)
              reviewsAsync.when(
                data: (reviewsData) {
                  final reviews = reviewsData.map((json) => Review.fromJson(json)).toList();
                  final myReview = reviews.where((r) => r.reviewerId == currentUser.uid && r.listingId == listing.id).firstOrNull;
                  return TextButton.icon(
                    onPressed: () => _showAddReviewDialog(context, ref, myReview),
                    icon: Icon(myReview != null ? Icons.edit_note_rounded : Icons.add_comment_outlined, size: 18),
                    label: Text(myReview != null ? 'Edit My Review' : 'Rate Seller', style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
          ],
        ),
        const SizedBox(height: 16),
        reviewsAsync.when(
          data: (reviewsData) {
            final reviews = reviewsData.map((json) => Review.fromJson(json)).toList();
            if (reviews.isEmpty) {
              return Container(
                padding: const EdgeInsets.all(24),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Icon(Icons.rate_review_outlined, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    Text(
                      'No reviews for this seller yet.',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: reviews.length > 3 ? 3 : reviews.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _ReviewItem(review: reviews[index]),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _showAddReviewDialog(BuildContext context, WidgetRef ref, Review? existingReview) {
    final theme = Theme.of(context);
    double rating = existingReview?.rating ?? 5.0;
    final commentController = TextEditingController(text: existingReview?.comment);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  existingReview != null ? 'Update Review' : 'Rate Your Experience',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'How was your interaction with ${listing.sellerName}?',
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                
                // Star Rating
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final isSelected = index < rating;
                    return IconButton(
                      onPressed: () => setModalState(() => rating = index + 1.0),
                      icon: Icon(
                        isSelected ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: isSelected ? Colors.amber : theme.colorScheme.outlineVariant,
                        size: 40,
                      ),
                    );
                  }),
                ),
                
                const SizedBox(height: 32),
                TextField(
                  controller: commentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: 'Tell us more (Optional)',
                    hintText: 'Was the item as described? Was the seller responsive?',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: FilledButton(
                    onPressed: () async {
                      final user = ref.read(appUserProvider).valueOrNull;
                      if (user == null) return;

                      await ref.read(marketplaceRepositoryProvider).submitReview(
                        sellerId: listing.sellerId,
                        buyerId: user.uid,
                        listingId: listing.id,
                        rating: rating,
                        comment: commentController.text.trim(),
                      );
                      
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Thank you for your feedback!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Submit Review', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReviewItem extends StatelessWidget {
  final Review review;
  const _ReviewItem({required this.review});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                child: Text(
                  review.reviewerName.isNotEmpty ? review.reviewerName[0].toUpperCase() : 'U',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.reviewerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(
                      DateFormatter.formatRelative(review.createdAt),
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10),
                    ),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (index) => Icon(
                  index < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Colors.amber,
                  size: 12,
                )),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            review.comment,
            style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _MoreFromSeller extends ConsumerWidget {
  final Listing listing;
  const _MoreFromSeller({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sellerId = listing.sellerId;
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
                  onPressed: () => context.push("/seller-profile/$sellerId", extra: sellerId),
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
                    heroTag: "hero_detail_seller_${others[index].id}",
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
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
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
            Icon(Icons.chevron_right, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
          ],
        ),
      ),
    );
  }
}

class _SimilarItems extends ConsumerWidget {
  final Listing listing;
  const _SimilarItems({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    heroTag: "hero_detail_similar_${listings[index].id}",
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
}

class _StickyActionBar extends StatelessWidget {
  final Listing listing;
  final bool isOwner;
  final VoidCallback onStartChat;
  final VoidCallback onMakeOffer;

  const _StickyActionBar({
    required this.listing,
    required this.isOwner,
    required this.onStartChat,
    required this.onMakeOffer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = listing.status;
    final isSold = status == ListingStatus.sold;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: RepaintBoundary(
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
                  onPressed: (isOwner || isSold) ? null : onStartChat,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: FilledButton(
                    onPressed: (isOwner || isSold) ? null : onMakeOffer,
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
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const _CircleButton({required this.icon, required this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
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
}

class _SaveButton extends ConsumerWidget {
  final Listing listing;
  const _SaveButton({required this.listing});

  void _toggleSave(BuildContext context, WidgetRef ref) {
    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to save items')));
      return;
    }
    ref.read(marketplaceRepositoryProvider).toggleSaveListing(user.uid, listing.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedListingsAsync = ref.watch(savedListingsProvider);
    final isSaved = savedListingsAsync.valueOrNull?.any((l) => l.id == listing.id) ?? false;

    return _CircleButton(
      icon: isSaved ? Icons.favorite : Icons.favorite_border, 
      onTap: () => _toggleSave(context, ref),
      iconColor: isSaved ? AppColors.error : Theme.of(context).colorScheme.onSurface,
    );
  }
}

class _BlockButton extends ConsumerWidget {
  final String sellerId;
  const _BlockButton({required this.sellerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(appUserProvider).valueOrNull;
    if (user == null || user.uid == sellerId) return const SizedBox.shrink();
    
    final isBlocked = user.blockedUids.contains(sellerId);
    
    return _CircleButton(
      icon: isBlocked ? Icons.block_flipped : Icons.block_outlined, 
      onTap: () {
        if (isBlocked) {
          ref.read(authControllerProvider.notifier).unblockUser(sellerId);
        } else {
          _showBlockConfirmation(context, ref);
        }
      },
      iconColor: isBlocked ? AppColors.success : AppColors.error,
    );
  }

  void _showBlockConfirmation(BuildContext context, WidgetRef ref) {
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
                    tag: "listing_img_full_$index",
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
                      "${page + 1} / ${imageUrls.length}",
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
