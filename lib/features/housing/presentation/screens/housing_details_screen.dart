import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/core/widgets/optimized_image.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../auth/shared/providers.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../domain/models/housing_listing.dart';
import '../../domain/models/housing_review.dart';
import '../../shared/providers.dart';
import '../../../chat/shared/providers.dart';
import '../../../chat/domain/models/chat_context.dart';
import '../../../../services/history_service.dart';
import '../widgets/housing_card.dart';

class HousingDetailsScreen extends ConsumerStatefulWidget {
  final HousingListing listing;
  final String? heroTag;

  const HousingDetailsScreen({super.key, required this.listing, this.heroTag});

  @override
  ConsumerState<HousingDetailsScreen> createState() => _HousingDetailsScreenState();
}

class _HousingDetailsScreenState extends ConsumerState<HousingDetailsScreen> {
  bool _isDescriptionExpanded = false;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(recentHistoryProvider.notifier).addItem(HistoryItem(
        id: widget.listing.id,
        type: 'housing',
        title: widget.listing.title,
        imageUrl: widget.listing.images.isNotEmpty ? widget.listing.images.first : null,
        timestamp: DateTime.now(),
      ));
      
      // Record view logic could be added here if the repository supports it
    });
  }

  void _toggleSave() {
    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to save listings')));
      return;
    }
    
    final savedListings = ref.read(savedHousingProvider).valueOrNull ?? [];
    final isSaved = savedListings.any((l) => l.id == widget.listing.id);

    if (isSaved) {
      ref.read(housingRepositoryProvider).unsaveListing(user.uid, widget.listing.id);
    } else {
      ref.read(housingRepositoryProvider).saveListing(user.uid, widget.listing.id);
    }
    ref.invalidate(savedHousingProvider);
  }

  void _handleChat() async {
    final currentUser = ref.read(appUserProvider).valueOrNull;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to contact the plug')));
      return;
    }

    if (currentUser.uid == widget.listing.plugId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This is your own listing.')));
      return;
    }

    final chatContext = ChatContext(
      type: 'housing',
      id: widget.listing.id,
      title: widget.listing.title,
      thumbnail: widget.listing.images.isNotEmpty ? widget.listing.images.first : null,
      metadata: {
        'rent': widget.listing.rent,
        'location': widget.listing.location,
      },
    );

    final convId = await ref.read(chatRepositoryProvider).getOrCreateConversation(
      participantIds: [currentUser.uid, widget.listing.plugId],
      context: chatContext,
    );

    if (mounted) {
      context.push('/chat', extra: {
        'conversationId': convId,
        'otherUserName': widget.listing.plugName,
        'context': chatContext,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final initialListing = widget.listing;
    
    // Watch real-time housing listing updates for views, status, etc.
    final listingAsync = ref.watch(housingListingProvider(initialListing.id));
    
    return listingAsync.when(
      data: (listing) {
        if (listing == null) {
          return const Scaffold(body: Center(child: Text('Property no longer available.')));
        }

        final currencyFormat = NumberFormat.currency(symbol: 'KES ', decimalDigits: 0);
        final plugAsync = ref.watch(userByIdProvider(listing.plugId));
        final savedListingsAsync = ref.watch(savedHousingProvider);
        final isSaved = savedListingsAsync.valueOrNull?.any((l) => l.id == listing.id) ?? false;

        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: Stack(
            children: [
              CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildImageGallery(isSaved, listing),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          _buildVerifiedBadgeRow(plugAsync, listing),
                          const SizedBox(height: 12),
                          Text(
                            listing.title,
                            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Icon(Icons.location_on_rounded, size: 16, color: theme.colorScheme.primary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${listing.campus} • ${listing.location}', 
                                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                currencyFormat.format(listing.rent),
                                style: theme.textTheme.headlineMedium?.copyWith(
                                  fontSize: 26, 
                                  fontWeight: FontWeight.w900, 
                                  color: theme.colorScheme.primary
                                ),
                              ),
                              Text(
                                ' / month',
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          if (listing.deposit > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                'Deposit: ${currencyFormat.format(listing.deposit)}',
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                            ),
                          const SizedBox(height: 24),
                          _buildSpecsGrid(listing),
                          const SizedBox(height: 32),
                          Text('Description', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 12),
                          Text(
                            listing.description,
                            maxLines: _isDescriptionExpanded ? null : 4,
                            style: TextStyle(color: theme.colorScheme.onSurface, height: 1.6, fontSize: 15),
                          ),
                          if (listing.description.length > 150)
                            GestureDetector(
                              onTap: () => setState(() => _isDescriptionExpanded = !_isDescriptionExpanded),
                              child: Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  _isDescriptionExpanded ? 'Read less' : 'Read more',
                                  style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          const SizedBox(height: 32),
                          _buildAmenitiesSection(listing),
                          const SizedBox(height: 32),
                          _buildPlugCard(plugAsync, listing),
                          const SizedBox(height: 24),
                          _buildSafetyBanner(),
                          const SizedBox(height: 32),
                          _buildSimilarProperties(listing),
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              _buildStickyActionBar(listing),
            ],
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildImageGallery(bool isSaved, HousingListing listing) {
    final images = listing.images;
    final topPadding = MediaQuery.of(context).padding.top;
    final theme = Theme.of(context);
    
    return SliverAppBar(
      expandedHeight: 420,
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
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (i) => setState(() => _currentPage = i),
                        itemCount: images.isEmpty ? 1 : images.length,
                        itemBuilder: (context, index) {
                          return Hero(
                            tag: index == 0 ? (widget.heroTag ?? 'housing_img_${listing.id}') : 'housing_img_${listing.id}_$index',
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
                  _buildCircleButton(Icons.ios_share, () => Share.share('Check out this ${listing.type.name} at ${listing.location} on UniHub!')),
                  const SizedBox(width: 12),
                  _buildCircleButton(
                    isSaved ? Icons.favorite : Icons.favorite_border, 
                    _toggleSave,
                    iconColor: isSaved ? AppColors.error : theme.colorScheme.onSurface,
                  ),
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
            if (listing.videoUrl != null)
               Positioned(
                bottom: 24,
                right: images.length > 1 ? MediaQuery.of(context).size.width * 0.32 : 24,
                child: GestureDetector(
                  onTap: () async {
                    final url = Uri.parse(listing.videoUrl!);
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10)],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.play_circle_fill, color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 6),
                        Text('Video Tour', style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
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

  Widget _buildVerifiedBadgeRow(AsyncValue<AppUser?> plugAsync, HousingListing listing) {
    final theme = Theme.of(context);
    return plugAsync.when(
      data: (plug) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (plug != null && plug.isVerifiedPlug)
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
                  Text('Verified Plug', style: TextStyle(color: AppColors.verifiedSellerIcon, fontSize: 11, fontWeight: FontWeight.bold)),
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
                  Text('Direct Listing', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Posted ${DateFormatter.formatRelative(listing.createdAt)}',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Text(
                '${listing.views} views',
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

  Widget _buildSpecsGrid(HousingListing listing) {
    final listing = widget.listing;
    final List<Map<String, dynamic>> specItems = [];

    specItems.add({
      'icon': Icons.home_work_outlined,
      'label': 'Property Type',
      'value': _formatHousingType(listing.type),
    });

    specItems.add({
      'icon': Icons.people_outline_rounded,
      'label': 'Occupancy',
      'value': _formatGenderRestriction(listing.genderRestriction),
    });

    if (listing.isFurnished) {
      specItems.add({
        'icon': Icons.chair_outlined,
        'label': 'Furnishing',
        'value': 'Furnished',
      });
    } else {
      specItems.add({
        'icon': Icons.chair_outlined,
        'label': 'Furnishing',
        'value': 'Unfurnished',
      });
    }

    if (listing.distance.isNotEmpty) {
      specItems.add({
        'icon': Icons.directions_walk_rounded,
        'label': 'Distance',
        'value': listing.distance,
      });
    }

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
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7), fontSize: 10)),
            Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: theme.colorScheme.onSurface), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildAmenitiesSection(HousingListing listing) {
    final theme = Theme.of(context);
    if (listing.amenities.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Amenities', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: listing.amenities.map((amenity) => _buildAmenityCard(amenity)).toList(),
        ),
      ],
    );
  }

  Widget _buildAmenityCard(String amenity) {
    final theme = Theme.of(context);
    IconData icon = _getAmenityIcon(amenity);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Text(
            amenity, 
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface),
          ),
        ],
      ),
    );
  }

  IconData _getAmenityIcon(String amenity) {
    final a = amenity.toLowerCase();
    if (a.contains('water')) return Icons.water_drop_outlined;
    if (a.contains('wifi') || a.contains('internet')) return Icons.wifi_rounded;
    if (a.contains('security') || a.contains('cctv')) return Icons.security_rounded;
    if (a.contains('token') || a.contains('electricity')) return Icons.electric_bolt_rounded;
    if (a.contains('parking')) return Icons.local_parking_rounded;
    if (a.contains('furnished')) return Icons.chair_outlined;
    if (a.contains('laundry')) return Icons.local_laundry_service_outlined;
    if (a.contains('borehole')) return Icons.waves_rounded;
    if (a.contains('balcony')) return Icons.balcony_rounded;
    if (a.contains('kitchen')) return Icons.kitchen_outlined;
    if (a.contains('wardrobe')) return Icons.door_sliding_outlined;
    if (a.contains('shower')) return Icons.shower_outlined;
    return Icons.check_circle_outline_rounded;
  }

  Widget _buildPlugCard(AsyncValue<AppUser?> plugAsync, HousingListing listing) {
    final theme = Theme.of(context);
    return plugAsync.when(
      data: (plug) {
        if (plug == null) return const SizedBox.shrink();
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: plug.photoUrl != null ? NetworkImage(plug.photoUrl!) : null,
                    backgroundColor: theme.colorScheme.surfaceVariant,
                    child: plug.photoUrl == null ? Text(plug.fullName[0], style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurfaceVariant)) : null,
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
                                plug.fullName, 
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (plug.isVerifiedPlug) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.verified, color: theme.colorScheme.primary, size: 16),
                            ],
                            if (plug.isOnline) ...[
                              const SizedBox(width: 8),
                              Container(
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
                            Text('${plug.averageRating} (${plug.ratingsCount} reviews)', 
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                            const SizedBox(width: 8),
                            Text('•', style: TextStyle(color: theme.colorScheme.outlineVariant)),
                            const SizedBox(width: 8),
                            Text('${plug.displayTrustScore.toInt()}% Trust', 
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                          ],
                        ),
                        ),
                      ],
                    ),
                  ),
                  OutlinedButton(
                    onPressed: () => context.push('/plug-profile/${plug.uid}'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: BorderSide(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Text('View', style: TextStyle(fontSize: 12, color: theme.colorScheme.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
              const SizedBox(height: 16),
              _buildPlugDetailRow(Icons.bolt_rounded, 'Response rate', plug.responseRate),
              const SizedBox(height: 12),
              _buildPlugDetailRow(Icons.access_time_rounded, 'Response time', 'Usually within 1 hr'),
              const SizedBox(height: 12),
              _buildPlugDetailRow(Icons.calendar_today_rounded, 'Member since', 
                plug.createdAt != null ? DateFormat('MMMM yyyy').format(plug.createdAt!) : 'Recent'),
              const SizedBox(height: 12),
              _buildPlugDetailRow(Icons.school_outlined, 'University', plug.university ?? 'UniHub Student'),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildPlugDetailRow(IconData icon, String label, String value) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7)),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13)),
        const Spacer(),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: theme.colorScheme.onSurface)),
      ],
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
                Text('Secure Viewing Guarantee', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
                Text('Only pay deposit after viewing and signing a lease.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: theme.colorScheme.outlineVariant),
        ],
      ),
    );
  }

  Widget _buildSimilarProperties(HousingListing listing) {
    final theme = Theme.of(context);
    final similarAsync = ref.watch(housingListingsProvider(10)); // Simplified: just show top listings for now
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Similar Properties', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SizedBox(
          height: 240,
          child: similarAsync.when(
            data: (listings) {
              final filtered = listings.where((l) => l.id != listing.id).toList();
              if (filtered.isEmpty) return const Center(child: Text('No similar properties found'));
              
              return ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: filtered.length,
                itemBuilder: (context, index) => SizedBox(
                  width: 180,
                  child: HousingCard(
                    listing: filtered[index],
                    isCompact: true,
                    margin: const EdgeInsets.only(right: 16),
                    onTap: () => context.push('/housing-details', extra: filtered[index]),
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildStickyActionBar(HousingListing listing) {
    final theme = Theme.of(context);
    final isTaken = listing.status == HousingStatus.taken;
    
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
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
                icon: Icon(Icons.chat_bubble_outline, color: theme.colorScheme.primary),
                onPressed: _handleChat,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 56,
                child: FilledButton(
                  onPressed: isTaken ? null : _handleChat,
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: Text(
                    isTaken ? 'Already Taken' : 'Contact House Plug', 
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

  String _formatHousingType(HousingType type) {
    return switch(type) {
      HousingType.hostel => 'Hostel',
      HousingType.bedsitter => 'Bedsitter',
      HousingType.singleRoom => 'Single Room',
      HousingType.oneBedroom => '1 Bedroom',
      HousingType.twoBedroom => '2 Bedroom',
      HousingType.airbnb => 'Airbnb',
      HousingType.shortStay => 'Short Stay',
    };
  }

  String _formatGenderRestriction(GenderRestriction restriction) {
    return switch(restriction) {
      GenderRestriction.mixed => 'Mixed / Any',
      GenderRestriction.maleOnly => 'Male Students Only',
      GenderRestriction.femaleOnly => 'Female Students Only',
    };
  }
}
