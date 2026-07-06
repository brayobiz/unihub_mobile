import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
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
import '../../domain/models/viewing_request.dart';
import '../../shared/providers.dart';
import '../../../chat/shared/providers.dart';
import '../../../chat/domain/models/chat_context.dart';
import '../../../../services/history_service.dart';
import '../widgets/housing_card.dart';
import '../../../../core/location/controllers/campus_maps_controller.dart';
import '../../../../core/constants/campus_constants.dart';

class HousingDetailsScreen extends ConsumerWidget {
  final HousingListing? listing;
  final String listingId;
  final String? heroTag;

  const HousingDetailsScreen({
    super.key, 
    this.listing, 
    required this.listingId,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch real-time housing listing updates for views, status, etc.
    final listingAsync = ref.watch(housingListingProvider(listingId));
    
    return listingAsync.when(
      data: (fetchedListing) {
        final currentListing = fetchedListing ?? listing;
        if (currentListing == null) {
          return const Scaffold(body: Center(child: Text('Property no longer available.')));
        }

        return _HousingDetailContent(
          listing: currentListing,
          heroTag: heroTag,
        );
      },
      loading: () => listing != null 
          ? _HousingDetailContent(listing: listing!, heroTag: heroTag, isLoading: true)
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }
}

class _HousingDetailContent extends ConsumerStatefulWidget {
  final HousingListing listing;
  final String? heroTag;
  final bool isLoading;

  const _HousingDetailContent({
    required this.listing,
    this.heroTag,
    this.isLoading = false,
  });

  @override
  ConsumerState<_HousingDetailContent> createState() => _HousingDetailContentState();
}

class _HousingDetailContentState extends ConsumerState<_HousingDetailContent> {
  bool _isDescriptionExpanded = false;
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _recordHistory(widget.listing);
    });
  }

  void _recordHistory(HousingListing listing) {
    ref.read(recentHistoryProvider.notifier).addItem(HistoryItem(
      id: listing.id,
      type: 'housing',
      title: listing.title,
      imageUrl: listing.images.isNotEmpty ? listing.images.first : null,
      timestamp: DateTime.now(),
    ));
    
    // Also record view in repo if not the plug themselves
    final userId = ref.read(firebaseAuthProvider).currentUser?.uid;
    if (userId != listing.plugId) {
      ref.read(housingRepositoryProvider).incrementViews(listing.id);
    }
  }

  void _shareListing() {
    final listing = widget.listing;
    final text = 'Check out this ${listing.title} at ${listing.location} for KES ${NumberFormat("#,###").format(listing.rent)}! \n\nDownload UniHub to view more: https://unihub.app/housing/${listing.id}';
    Share.share(text);
  }

  void _showReportDialog() {
    final listing = widget.listing;
    final reasons = [
      'Fake property',
      'Incorrect location',
      'Scam or suspicious',
      'Already taken/Sold',
      'Incorrect price',
      'Inappropriate photos',
      'Other'
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report Property'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: reasons.map((reason) => ListTile(
            title: Text(reason),
            onTap: () async {
              final user = ref.read(appUserProvider).valueOrNull;
              if (user != null) {
                await ref.read(housingRepositoryProvider).reportListing(
                  listingId: listing.id,
                  reporterId: user.uid,
                  reason: reason,
                  category: listing.title,
                );
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Report submitted. Our team will review this listing shortly.')),
                  );
                }
              }
            },
          )).toList(),
        ),
      ),
    );
  }

  void _handleCall(HousingListing listing) async {
    final plug = ref.read(userByIdProvider(listing.plugId)).valueOrNull;
    if (plug == null || (plug.phoneNumber == null && plug.whatsappNumber == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Plug contact information not available.')));
      return;
    }

    final number = plug.phoneNumber ?? plug.whatsappNumber;
    final url = Uri.parse('tel:$number');
    
    // Increment Analytics
    ref.read(housingRepositoryProvider).incrementCallCount(listing.id);

    if (await canLaunchUrl(url)) {
      await launchUrl(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch dialer.')));
      }
    }
  }

  void _handleChat() async {
    final listing = widget.listing;
    final currentUser = ref.read(appUserProvider).valueOrNull;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to contact the plug')));
      return;
    }

    if (currentUser.uid == listing.plugId) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This is your own listing.')));
      return;
    }

    // Increment Analytics
    ref.read(housingRepositoryProvider).incrementChatCount(listing.id);

    final chatContext = ChatContext(
      type: 'housing',
      id: listing.id,
      title: listing.title,
      thumbnail: listing.images.isNotEmpty ? listing.images.first : null,
      metadata: {
        'rent': listing.rent,
        'location': listing.location,
      },
    );

    final convId = await ref.read(chatRepositoryProvider).getOrCreateConversation(
      participantIds: [currentUser.uid, listing.plugId],
      context: chatContext,
    );

    if (mounted) {
      context.push('/chat', extra: {
        'conversationId': convId,
        'otherUserName': listing.plugName,
        'context': chatContext,
      });
    }
  }

  void _showBookingDialog() {
    final listing = widget.listing;
    final plug = ref.read(userByIdProvider(listing.plugId)).valueOrNull;
    if (plug == null) return;

    DateTime? selectedDate;
    final notesController = TextEditingController();
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(modalContext).viewInsets.bottom,
          ),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
                ),
                const SizedBox(height: 24),
                Text('Book a Viewing', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
                const SizedBox(height: 8),
                Text('Request a time to visit this property', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                const SizedBox(height: 32),
                
                // Date Picker Trigger
                InkWell(
                  onTap: () async {
                    final date = await showDatePicker(
                      context: modalContext,
                      initialDate: DateTime.now().add(const Duration(days: 1)),
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (date != null) {
                      setModalState(() => selectedDate = date);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.colorScheme.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month, color: theme.colorScheme.primary),
                        const SizedBox(width: 12),
                        Text(
                          selectedDate != null 
                              ? DateFormat('EEEE, MMMM d, y').format(selectedDate!) 
                              : 'Select Preferred Date',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: selectedDate != null ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: 'Notes for the Plug (Optional)',
                    hintText: 'e.g. "I can come after 4 PM"',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: FilledButton(
                    onPressed: selectedDate == null ? null : () async {
                      final user = ref.read(appUserProvider).valueOrNull;
                      if (user == null) return;

                      final request = ViewingRequest(
                        id: const Uuid().v4(),
                        listingId: listing.id,
                        listingTitle: listing.title,
                        studentId: user.uid,
                        studentName: user.fullName,
                        plugId: plug.uid,
                        plugName: plug.fullName,
                        preferredDate: selectedDate!,
                        notes: notesController.text.trim(),
                        createdAt: DateTime.now(),
                      );

                      await ref.read(housingRepositoryProvider).submitViewingRequest(request);
                      
                      if (context.mounted) {
                        Navigator.pop(modalContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Viewing request sent! You will be notified when confirmed.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Send Request', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final listing = widget.listing;
    final currencyFormat = NumberFormat.currency(symbol: 'KES ', decimalDigits: 0);

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
                            '${CampusConstants.getDisplayName(listing.campus)} • ${listing.location}', 
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (listing.previousRent != null && listing.previousRent! > listing.rent) ...[
                              _PriceDropBadge(),
                              const SizedBox(height: 4),
                              Text(
                                currencyFormat.format(listing.previousRent),
                                style: TextStyle(
                                  decoration: TextDecoration.lineThrough,
                                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            Text(
                              currencyFormat.format(listing.rent),
                              style: theme.textTheme.headlineMedium?.copyWith(
                                fontSize: 28, 
                                fontWeight: FontWeight.w900, 
                                color: (listing.previousRent != null && listing.previousRent! > listing.rent)
                                  ? AppColors.success
                                  : theme.colorScheme.primary
                              ),
                            ),
                          ],
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
                    _HousingSpecsGrid(listing: listing),
                    const SizedBox(height: 24),
                    Text('Description', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
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
                            _isDescriptionExpanded ? 'Read Less' : 'Read More',
                            style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    _AmenitiesSection(listing: listing),
                    const SizedBox(height: 24),
                    _LocationMapSection(listing: listing),
                    const SizedBox(height: 24),
                    _PlugCard(listing: listing),
                    const SizedBox(height: 24),
                    _TrustScorecard(listing: listing),
                    const SizedBox(height: 24),
                    _PropertyReviewsSection(listing: listing),
                    const SizedBox(height: 24),
                    const _SafetyBanner(),
                    const SizedBox(height: 24),
                    _SimilarProperties(listing: listing),
                    const SizedBox(height: 120),
                  ]),
                ),
              ),
            ],
          ),
          _StickyActionBar(
            listing: listing,
            onCall: () => _handleCall(listing),
            onChat: _handleChat,
            onBook: _showBookingDialog,
          ),
          if (widget.isLoading)
             const Positioned.fill(
               child: Center(child: CircularProgressIndicator()),
             ),
        ],
      ),
    );
  }

  Widget _buildImageGallery(HousingListing listing) {
    final images = listing.images;
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
                      child: PageView.builder(
                        controller: _pageController,
                        onPageChanged: (i) => setState(() => _currentPage = i),
                        itemCount: images.isEmpty ? 1 : images.length,
                        itemBuilder: (context, index) {
                          return GestureDetector(
                            onTap: () => _showFullScreenGallery(images, index),
                            child: Hero(
                              tag: index == 0 ? (widget.heroTag ?? 'housing_img_${listing.id}') : 'housing_img_${listing.id}_$index',
                              child: OptimizedImage(
                                imageUrl: images.isEmpty ? '' : images[index],
                                fit: BoxFit.cover,
                              ),
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
              child: _CircleButton(icon: Icons.arrow_back, onTap: () => context.pop(), semanticLabel: 'Back to housing search'),
            ),
            Positioned(
              top: topPadding + 8,
              right: 16,
              child: Row(
                children: [
                  _CompareButton(listing: listing),
                  const SizedBox(width: 12),
                  _CircleButton(icon: Icons.ios_share, onTap: _shareListing, semanticLabel: 'Share property details'),
                  const SizedBox(width: 12),
                  _SaveHousingButton(listing: listing),
                  const SizedBox(width: 12),
                  _CircleButton(icon: Icons.report_gmailerrorred_rounded, onTap: _showReportDialog, semanticLabel: 'Report this property for review'),
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
               _VideoTourButton(videoUrl: listing.videoUrl!),
          ],
        ),
      ),
    );
  }

  void _showFullScreenGallery(List<String> images, int initialIndex) {
    showDialog(
      context: context,
      useSafeArea: false,
      builder: (context) => FullScreenGallery(images: images, initialIndex: initialIndex),
    );
  }
}

class _PriceDropBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.trending_down_rounded, color: AppColors.success, size: 12),
          const SizedBox(width: 4),
          Text(
            'PRICE DROP', 
            style: TextStyle(color: AppColors.success, fontSize: 9, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _VerifiedBadgeRow extends ConsumerWidget {
  final HousingListing listing;
  const _VerifiedBadgeRow({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final plugAsync = ref.watch(userByIdProvider(listing.plugId));

    return plugAsync.when(
      data: (plug) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (plug != null && plug.isVerifiedPlug)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.verified, color: theme.colorScheme.primary, size: 14),
                  const SizedBox(width: 4),
                  Text('Verified Plug', style: TextStyle(color: theme.colorScheme.primary, fontSize: 11, fontWeight: FontWeight.bold)),
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
}

class _HousingSpecsGrid extends StatelessWidget {
  final HousingListing listing;
  const _HousingSpecsGrid({required this.listing});

  @override
  Widget build(BuildContext context) {
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

    specItems.add({
      'icon': Icons.chair_outlined,
      'label': 'Furnishing',
      'value': listing.isFurnished ? 'Furnished' : 'Unfurnished',
    });

    if (listing.distance.isNotEmpty) {
      specItems.add({
        'icon': Icons.directions_walk_rounded,
        'label': 'Distance',
        'value': listing.distance,
      });
    }

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
          color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.2),
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

class _AmenitiesSection extends StatelessWidget {
  final HousingListing listing;
  const _AmenitiesSection({required this.listing});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (listing.amenities.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Amenities', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: listing.amenities.map((amenity) => _AmenityCard(amenity: amenity)).toList(),
        ),
      ],
    );
  }
}

class _AmenityCard extends StatelessWidget {
  final String amenity;
  const _AmenityCard({required this.amenity});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    IconData icon = _getAmenityIcon(amenity);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
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
}

class _LocationMapSection extends ConsumerWidget {
  final HousingListing listing;
  const _LocationMapSection({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final mapState = ref.watch(campusMapsControllerProvider);
    final listingCampus = CampusConstants.getById(listing.campus) ?? CampusConstants.getById(listing.university);
    
    final hasCoords = listing.latitude != null && listing.longitude != null;
    
    if (!hasCoords && listingCampus == null) return const SizedBox.shrink();

    final centerLat = listing.latitude ?? listingCampus!.latitude;
    final centerLng = listing.longitude ?? listingCampus!.longitude;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Location', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            if (hasCoords)
              TextButton.icon(
                onPressed: () async {
                  final url = 'https://www.google.com/maps/search/?api=1&query=${listing.latitude},${listing.longitude}';
                  if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url));
                },
                icon: const Icon(Icons.directions_outlined, size: 18),
                label: const Text('Open in Maps', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(centerLat, centerLng),
                    initialZoom: 15,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.unihub.mobile',
                    ),
                    if (hasCoords)
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: LatLng(listing.latitude!, listing.longitude!),
                            width: 80,
                            height: 80,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text('Hostel', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ),
                                Icon(Icons.location_on, color: theme.colorScheme.primary, size: 40),
                              ],
                            ),
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: mapState.allLandmarks.take(5).map((l) => Marker(
                        point: LatLng(l.latitude, l.longitude),
                        width: 30,
                        height: 30,
                        child: Icon(Icons.school, size: 16, color: theme.colorScheme.secondary.withOpacity(0.7)),
                      )).toList(),
                    ),
                  ],
                ),
                if (!hasCoords)
                  Container(
                    color: Colors.black26,
                    alignment: Alignment.center,
                    child: const Text(
                      'Approximate area shown',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.directions_walk_rounded, size: 16, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              listing.distance,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ],
    );
  }
}

class _PlugCard extends ConsumerWidget {
  final HousingListing listing;
  const _PlugCard({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final plugAsync = ref.watch(userByIdProvider(listing.plugId));

    return plugAsync.when(
      data: (plug) {
        if (plug == null) return const SizedBox.shrink();
        return Container(
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
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: plug.photoUrl != null ? NetworkImage(plug.photoUrl!) : null,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
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
                              _OnlineBadge(),
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
                            Text('${plug.averageRating.toStringAsFixed(1)} (${plug.ratingsCount} reviews)',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                            const SizedBox(width: 8),
                            Text('•', style: TextStyle(color: theme.colorScheme.outlineVariant.withOpacity(0.5))),
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
                      side: BorderSide(color: theme.colorScheme.outlineVariant.withOpacity(0.8)),
                    ),
                    child: Text('View', style: TextStyle(fontSize: 12, color: theme.colorScheme.primary)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
              const SizedBox(height: 16),
              _PlugDetailRow(icon: Icons.bolt_rounded, label: 'Response rate', value: plug.responseRate),
              const SizedBox(height: 12),
              const _PlugDetailRow(icon: Icons.access_time_rounded, label: 'Typically responds', value: 'Within 2 hrs'),
              const SizedBox(height: 12),
              _PlugDetailRow(icon: Icons.check_circle_outline_rounded, label: 'Successful deals', value: '${plug.completedSalesCount}'),
              const SizedBox(height: 12),
              _PlugDetailRow(icon: Icons.calendar_today_rounded, label: 'Member since', 
                value: plug.createdAt != null ? DateFormat('MMMM yyyy').format(plug.createdAt!) : 'Recent'),
              const SizedBox(height: 12),
              _PlugDetailRow(icon: Icons.school_outlined, label: 'University', value: plug.university ?? 'UniHub Student'),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _OnlineBadge extends StatelessWidget {
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

class _PlugDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _PlugDetailRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
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
}

class _TrustScorecard extends ConsumerWidget {
  final HousingListing listing;
  const _TrustScorecard({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final plug = ref.watch(userByIdProvider(listing.plugId)).valueOrNull;
    final diff = DateTime.now().difference(listing.lastVerifiedAt);
    final isFresh = diff.inHours < 24;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.shield_rounded, color: theme.colorScheme.primary, size: 20),
              const SizedBox(width: 8),
              Text('Trust & Safety Profile', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: theme.colorScheme.onSurface)),
            ],
          ),
          const SizedBox(height: 20),
          _TrustMetricRow(
            icon: Icons.verified_user_rounded, 
            label: 'Provider Identity', 
            value: plug?.isVerified == true ? 'Verified' : 'Unverified',
            valueColor: plug?.isVerified == true ? AppColors.success : theme.colorScheme.error
          ),
          const SizedBox(height: 12),
          _TrustMetricRow(
            icon: Icons.update_rounded, 
            label: 'Listing Freshness', 
            value: isFresh ? 'Verified Today' : 'Last verified ${diff.inDays}d ago',
            valueColor: isFresh ? AppColors.success : theme.colorScheme.onSurfaceVariant
          ),
          const SizedBox(height: 12),
          _TrustMetricRow(
            icon: Icons.handshake_rounded, 
            label: 'Successful Deals', 
            value: '${plug?.completedSalesCount ?? 0} secured',
            valueColor: AppColors.success
          ),
          const SizedBox(height: 12),
          _TrustMetricRow(
            icon: Icons.star_rounded, 
            label: 'Marketplace Rating', 
            value: '${plug?.averageRating ?? "0.0"} / 5.0',
            valueColor: Colors.amber
          ),
        ],
      ),
    );
  }
}

class _TrustMetricRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _TrustMetricRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7)),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value, style: TextStyle(color: valueColor, fontWeight: FontWeight.w900, fontSize: 13)),
      ],
    );
  }
}

class _PropertyReviewsSection extends ConsumerWidget {
  final HousingListing listing;
  const _PropertyReviewsSection({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reviewsAsync = ref.watch(housingListingReviewsProvider(listing.id));
    final user = ref.watch(appUserProvider).valueOrNull;
    final isOwnListing = user?.uid == listing.plugId;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Property Reviews', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            if (!isOwnListing && user != null)
              reviewsAsync.when(
                data: (reviews) {
                  final existingReview = reviews.where((r) => r.userId == user.uid).firstOrNull;
                  return TextButton.icon(
                    onPressed: () => _showAddReviewDialog(context, ref, existingReview),
                    icon: Icon(existingReview != null ? Icons.edit_note_rounded : Icons.add_comment_outlined, size: 18),
                    label: Text(existingReview != null ? 'Edit My Review' : 'Add Review', style: const TextStyle(fontWeight: FontWeight.bold)),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
          ],
        ),
        const SizedBox(height: 16),
        reviewsAsync.when(
          data: (reviews) {
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
                    Text('No reviews yet. Be the first to share your experience!', 
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
              itemCount: reviews.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) => _ReviewCard(review: reviews[index]),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  void _showAddReviewDialog(BuildContext context, WidgetRef ref, HousingReview? existingReview) {
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
                  'How was your interaction with ${listing.plugName}?',
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
                    hintText: 'Was the property as described? Was the plug professional?',
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

                      final review = HousingReview(
                        id: existingReview?.id ?? const Uuid().v4(),
                        plugId: listing.plugId,
                        listingId: listing.id,
                        userId: user.uid,
                        userName: user.fullName,
                        userPhotoUrl: user.photoUrl,
                        comment: commentController.text.trim(),
                        rating: rating,
                        createdAt: DateTime.now(),
                      );

                      await ref.read(housingRepositoryProvider).submitReview(review);
                      
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

class _ReviewCard extends StatelessWidget {
  final HousingReview review;
  const _ReviewCard({required this.review});

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
                radius: 16,
                backgroundImage: (review.userPhotoUrl != null && review.userPhotoUrl!.isNotEmpty) 
                    ? NetworkImage(review.userPhotoUrl!) 
                    : null,
                child: (review.userPhotoUrl == null || review.userPhotoUrl!.isEmpty) 
                    ? Text(review.userName.isNotEmpty ? review.userName[0].toUpperCase() : 'U') 
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(review.userName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(DateFormatter.formatRelative(review.createdAt), style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 10)),
                  ],
                ),
              ),
              Row(
                children: List.generate(5, (index) => Icon(
                  index < review.rating ? Icons.star_rounded : Icons.star_outline_rounded,
                  color: Colors.amber,
                  size: 14,
                )),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(review.comment, style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface, height: 1.4)),
        ],
      ),
    );
  }
}

class _SafetyBanner extends StatelessWidget {
  const _SafetyBanner();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _showSafetyChecklist(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.success.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            const Icon(Icons.security_rounded, color: AppColors.success),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Secure Viewing Checklist', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: theme.colorScheme.onSurface)),
                  Text('5 steps to stay safe while house hunting.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: AppColors.success, size: 16),
          ],
        ),
      ),
    );
  }

  void _showSafetyChecklist(BuildContext context) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 24),
            Text('Safety First', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Always follow these rules to avoid fraud:', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(height: 32),
            _safetyItem(context, Icons.visibility_rounded, 'View First', 'Never pay a deposit before physically inspecting the property.'),
            _safetyItem(context, Icons.person_pin_rounded, 'Public Meetings', 'Always meet the Plug at the property or a public campus location.'),
            _safetyItem(context, Icons.description_rounded, 'Sign a Lease', 'Ensure you have a written, signed agreement before transferring funds.'),
            _safetyItem(context, Icons.payments_rounded, 'Traceable Payments', 'Use MPESA or Bank transfers. Avoid cash where possible for record-keeping.'),
            _safetyItem(context, Icons.report_problem_rounded, 'Report Suspicion', 'If a Plug asks for "booking fees" without viewing, report them immediately.'),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                child: const Text('I Understand', style: TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _safetyItem(BuildContext context, IconData icon, String title, String body) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: theme.colorScheme.primary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(body, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SimilarProperties extends ConsumerWidget {
  final HousingListing listing;
  const _SimilarProperties({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final similarAsync = ref.watch(housingListingsProvider(10));
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Similar Properties', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800, color: theme.colorScheme.onSurface)),
        const SizedBox(height: 16),
        SizedBox(
          height: 240,
          child: similarAsync.when(
            data: (listings) {
              final filtered = listings.where((l) => 
                l.id != listing.id && 
                (l.type == listing.type || l.location == listing.location)
              ).toList();
              
              if (filtered.isEmpty) {
                final campusFiltered = listings.where((l) => l.id != listing.id).toList();
                if (campusFiltered.isEmpty) return const SizedBox.shrink();
                return _buildSimilarList(context, campusFiltered);
              }
              
              return _buildSimilarList(context, filtered);
            },
            loading: () => Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildSimilarList(BuildContext context, List<HousingListing> listings) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: listings.length,
      itemBuilder: (context, index) => SizedBox(
        width: 220,
        child: HousingCard(
          listing: listings[index],
          isCompact: true,
          margin: const EdgeInsets.only(right: 16),
          onTap: () => context.push('/housing-detail/${listings[index].id}', extra: listings[index]),
        ),
      ),
    );
  }
}

class _StickyActionBar extends StatelessWidget {
  final HousingListing listing;
  final VoidCallback onCall;
  final VoidCallback onChat;
  final VoidCallback onBook;

  const _StickyActionBar({
    required this.listing,
    required this.onCall,
    required this.onChat,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTaken = listing.status == HousingStatus.taken;
    
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: RepaintBoundary(
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
                  icon: Icon(Icons.group_add_outlined, color: theme.colorScheme.primary),
                  onPressed: () => context.push('/add-roommate', extra: listing),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: IconButton(
                  icon: Icon(Icons.call_outlined, color: theme.colorScheme.primary),
                  onPressed: onCall,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 56,
                width: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: IconButton(
                  icon: Icon(Icons.chat_bubble_outline, color: theme.colorScheme.primary),
                  onPressed: onChat,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: isTaken ? null : onBook,
                    icon: const Icon(Icons.event_available),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    label: Text(
                      isTaken ? 'Already Taken' : 'Book Viewing',
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
  final String? semanticLabel;

  const _CircleButton({required this.icon, required this.onTap, this.iconColor, this.semanticLabel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: semanticLabel,
      button: true,
      child: Container(
        height: 48,
        width: 48,
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
          icon: Icon(icon, color: iconColor ?? theme.colorScheme.onSurface, size: 22),
          onPressed: onTap,
          padding: EdgeInsets.zero,
          tooltip: semanticLabel,
        ),
      ),
    );
  }
}

class _CompareButton extends ConsumerWidget {
  final HousingListing listing;
  const _CompareButton({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final comparisonList = ref.watch(housingComparisonProvider);
    final isInComparison = comparisonList.any((l) => l.id == listing.id);

    return _CircleButton(
      icon: Icons.compare_arrows_rounded, 
      onTap: () {
        if (isInComparison) {
          ref.read(housingComparisonProvider.notifier).state = 
            comparisonList.where((l) => l.id != listing.id).toList();
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from comparison')));
        } else {
          if (comparisonList.length >= 3) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comparison limit is 3 properties')));
            return;
          }
          ref.read(housingComparisonProvider.notifier).state = [...comparisonList, listing];
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to comparison')));
        }
      }, 
      iconColor: isInComparison ? theme.colorScheme.primary : null,
      semanticLabel: 'Add to side by side comparison',
    );
  }
}

class _SaveHousingButton extends ConsumerWidget {
  final HousingListing listing;
  const _SaveHousingButton({required this.listing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final savedListingsAsync = ref.watch(savedHousingProvider);
    final isSaved = savedListingsAsync.valueOrNull?.any((l) => l.id == listing.id) ?? false;

    return _CircleButton(
      icon: isSaved ? Icons.favorite : Icons.favorite_border, 
      onTap: () {
        final user = ref.read(appUserProvider).valueOrNull;
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please log in to save listings')));
          return;
        }
        
        if (isSaved) {
          ref.read(housingRepositoryProvider).unsaveListing(user.uid, listing.id);
        } else {
          ref.read(housingRepositoryProvider).saveListing(user.uid, listing.id);
        }
        ref.invalidate(savedHousingProvider);
      },
      iconColor: isSaved ? AppColors.error : theme.colorScheme.onSurface,
      semanticLabel: isSaved ? 'Remove from saved housing' : 'Save property for later',
    );
  }
}

class _VideoTourButton extends StatelessWidget {
  final String videoUrl;
  const _VideoTourButton({required this.videoUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Positioned(
      bottom: 24,
      right: 24,
      child: GestureDetector(
        onTap: () async {
          final url = Uri.parse(videoUrl);
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
    );
  }
}

class FullScreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const FullScreenGallery({super.key, required this.images, required this.initialIndex});

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> {
  late PageController _controller;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: widget.images.length,
            onPageChanged: (i) => setState(() => _currentIndex = i),
            itemBuilder: (context, index) => InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: OptimizedImage(
                imageUrl: widget.images[index],
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${widget.images.length}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
