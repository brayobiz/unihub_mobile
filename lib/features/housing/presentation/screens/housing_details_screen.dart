import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:unihub_mobile/core/widgets/optimized_image.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/housing_listing.dart';
import '../../domain/models/housing_review.dart';
import '../../shared/providers.dart';
import 'package:intl/intl.dart';
import '../../../../services/history_service.dart';

class HousingDetailsScreen extends ConsumerStatefulWidget {
  final HousingListing listing;
  const HousingDetailsScreen({super.key, required this.listing});

  @override
  ConsumerState<HousingDetailsScreen> createState() => _HousingDetailsScreenState();
}

class _HousingDetailsScreenState extends ConsumerState<HousingDetailsScreen> {
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
    });
  }

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final currencyFormat = NumberFormat.currency(symbol: 'KES ', decimalDigits: 0);
    final reviewsAsync = ref.watch(plugReviewsProvider(listing.plugId));
    final savedListingsAsync = ref.watch(savedHousingProvider);
    final isSaved = savedListingsAsync.valueOrNull?.any((l) => l.id == listing.id) ?? false;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, ref, isSaved),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderSection(currencyFormat),
                  const SizedBox(height: 24),
                  _buildPlugInfo(context),
                  const SizedBox(height: 32),
                  _buildActionButtons(context),
                  const SizedBox(height: 40),
                  _buildDescriptionSection(),
                  const SizedBox(height: 32),
                  _buildAmenitiesSection(),
                  const SizedBox(height: 32),
                  _buildReviewsSection(context, reviewsAsync),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context, currencyFormat),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, WidgetRef ref, bool isSaved) {
    final listing = widget.listing;
    return SliverAppBar(
      expandedHeight: 400,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.white,
      leading: Padding(
        padding: const EdgeInsets.all(8.0),
        child: CircleAvatar(
          backgroundColor: Colors.black.withOpacity(0.3),
          child: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'housing_${listing.id}',
              child: PageView.builder(
                itemCount: listing.images.isNotEmpty ? listing.images.length : 1,
                itemBuilder: (context, index) => OptimizedImage(
                  imageUrl: listing.images.isNotEmpty ? listing.images[index] : 'https://images.unsplash.com/photo-1522708323590-d24dbb6b0267?q=80&w=2070&auto=format&fit=crop',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            if (listing.videoUrl != null)
              Positioned(
                bottom: 24,
                right: 24,
                child: FloatingActionButton.extended(
                  onPressed: () {}, // Open video walkthrough
                  backgroundColor: Colors.white,
                  icon: const Icon(Icons.play_circle_filled, color: Color(0xFF1677F2)),
                  label: const Text('Video Tour', style: TextStyle(color: Color(0xFF1677F2), fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: CircleAvatar(
            backgroundColor: Colors.black.withOpacity(0.3),
            child: IconButton(
              icon: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
              onPressed: () {
                Share.share('Check out this ${listing.type.name} at ${listing.location} for KES ${listing.rent.toInt()}/mo on UniHub!');
              },
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12.0, top: 8.0, bottom: 8.0),
          child: CircleAvatar(
            backgroundColor: Colors.black.withOpacity(0.3),
            child: IconButton(
              icon: Icon(
                isSaved ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                color: isSaved ? Colors.red : Colors.white, 
                size: 20
              ),
              onPressed: () {
                final userId = ref.read(appUserProvider).valueOrNull?.uid;
                if (userId != null) {
                  if (isSaved) {
                    ref.read(housingRepositoryProvider).unsaveListing(userId, listing.id);
                  } else {
                    ref.read(housingRepositoryProvider).saveListing(userId, listing.id);
                  }
                  ref.invalidate(savedHousingProvider);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderSection(NumberFormat format) {
    final listing = widget.listing;
    final isTaken = listing.status == HousingStatus.taken;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1677F2).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    listing.type.name.replaceAll(RegExp(r'(?=[A-Z])'), ' ').toUpperCase(),
                    style: const TextStyle(color: Color(0xFF1677F2), fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                  ),
                ),
                if (isTaken) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'TAKEN',
                      style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                  ),
                ],
              ],
            ),
            Text(
              'Updated ${DateFormat.yMMMd().format(listing.updatedAt)}',
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          listing.title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF1A1C1E),
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Icon(Icons.location_on_rounded, size: 20, color: Color(0xFF1677F2)),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${listing.university} • ${listing.location}', 
                style: const TextStyle(color: Color(0xFF475569), fontWeight: FontWeight.w600, fontSize: 15),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPlugInfo(BuildContext context) {
    final listing = widget.listing;
    final plugAsync = ref.watch(userByIdProvider(listing.plugId));
    final plug = plugAsync.valueOrNull;
    final isVerified = plug?.isVerified ?? false;
    final trustScore = plug?.trustScore ?? 70.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1677F2).withOpacity(0.2), width: 2),
            ),
            child: CircleAvatar(
              radius: 26,
              backgroundImage: listing.plugPhotoUrl != null ? NetworkImage(listing.plugPhotoUrl!) : null,
              child: listing.plugPhotoUrl == null ? Text(listing.plugName[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)) : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Listed by', style: TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(listing.plugName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: Color(0xFF1A1C1E))),
                    if (isVerified)
                      const Padding(
                        padding: EdgeInsets.only(left: 4),
                        child: Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 16),
                      ),
                  ],
                ),
                Text(
                  isVerified ? 'Verified Platform Plug • ${trustScore.toInt()}% Trust' : 'Housing Plug',
                  style: TextStyle(color: isVerified ? const Color(0xFF10B981) : const Color(0xFF64748B), fontSize: 12, fontWeight: FontWeight.w700)
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => context.push('/plug-profile/${listing.plugId}'),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Text('View', style: TextStyle(color: Color(0xFF1677F2), fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            icon: Icons.chat_bubble_rounded,
            label: 'Message',
            onTap: () => _handleChat(context),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionButton(
            icon: Icons.phone_rounded,
            label: 'Call',
            onTap: () async {
              final url = Uri.parse('tel:${widget.listing.plugId}'); // Note: Should be plug's phone, but we use ID as fallback for now if phone is missing in listing
              if (await canLaunchUrl(url)) {
                await launchUrl(url);
              }
            },
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionButton(
            icon: Icons.report_problem_rounded,
            label: 'Report',
            color: const Color(0xFFFEF2F2),
            iconColor: const Color(0xFFEF4444),
            onTap: () => _showReportDialog(context),
          ),
        ),
      ],
    );
  }

  void _handleChat(BuildContext context) {
    // Navigate to chat with Plug
    // For now, we need to create or get conversation ID.
    // Simplifying for Phase 1 polish: use a common route.
    context.push('/chat', extra: {
      'otherUserId': widget.listing.plugId,
      'otherUserName': widget.listing.plugName,
      'title': widget.listing.title,
    });
  }

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => _HousingReportDialog(listing: widget.listing),
    );
  }

  Widget _buildActionButton({
    required IconData icon, 
    required String label, 
    required VoidCallback onTap,
    Color? color,
    Color? iconColor,
  }) {
    return Material(
      color: color ?? const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: iconColor ?? const Color(0xFF1A1C1E), size: 22),
              const SizedBox(height: 6),
              Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: iconColor ?? const Color(0xFF1A1C1E))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('About this property', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1C1E))),
        const SizedBox(height: 16),
        Text(
          widget.listing.description,
          style: const TextStyle(height: 1.6, color: Color(0xFF475569), fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildAmenitiesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Amenities', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1C1E))),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: widget.listing.amenities.map((a) => _buildAmenityChip(a)).toList(),
        ),
      ],
    );
  }

  Widget _buildAmenityChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_rounded, size: 18, color: Color(0xFF10B981)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1C1E))),
        ],
      ),
    );
  }

  Widget _buildReviewsSection(BuildContext context, AsyncValue reviewsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Plug Reviews', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1C1E))),
            TextButton(
              onPressed: () {}, 
              child: const Text('See all', style: TextStyle(color: Color(0xFF1677F2), fontWeight: FontWeight.w800))
            ),
          ],
        ),
        const SizedBox(height: 8),
        reviewsAsync.when(
          data: (reviews) => reviews.isEmpty 
            ? Container(
                padding: const EdgeInsets.all(20),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    const Text('No reviews for this plug yet.', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => _showReviewDialog(context),
                      icon: const Icon(Icons.rate_review_outlined, size: 18),
                      label: const Text('Be the first to review'),
                    ),
                  ],
                ),
              )
            : Column(
                children: [
                  ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: reviews.length > 2 ? 2 : reviews.length,
                    itemBuilder: (context, index) => _buildReviewItem(reviews[index]),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showReviewDialog(context),
                    icon: const Icon(Icons.rate_review_outlined, size: 18),
                    label: const Text('Write a Review'),
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => const Text('Error loading reviews'),
        ),
      ],
    );
  }

  void _showReviewDialog(BuildContext context) {
    // We'll need a stateful widget for the dialog to handle star selection
    showDialog(
      context: context,
      builder: (context) => _HousingReviewDialog(listing: widget.listing),
    );
  }

  Widget _buildReviewItem(dynamic review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 16, 
                backgroundImage: review.userPhotoUrl != null ? NetworkImage(review.userPhotoUrl!) : null,
                child: review.userPhotoUrl == null ? const Icon(Icons.person, size: 16) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(review.userName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF1A1C1E))),
              ),
              Row(
                children: List.generate(5, (i) => Icon(
                  Icons.star_rounded, 
                  size: 16, 
                  color: i < review.rating ? const Color(0xFFFFB800) : const Color(0xFFE2E8F0)
                )),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(review.comment, style: const TextStyle(fontSize: 14, color: Color(0xFF475569), fontWeight: FontWeight.w500, height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, NumberFormat format) {
    final listing = widget.listing;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 20, offset: const Offset(0, -4))
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  format.format(listing.rent),
                  style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF1677F2)),
                ),
                Text(
                  'Deposit: ${format.format(listing.deposit)}', 
                  style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w700)
                ),
              ],
            ),
            const SizedBox(width: 24),
            Expanded(
              child: SizedBox(
                height: 58,
                child: FilledButton(
                  onPressed: listing.status == HousingStatus.taken ? null : () {
                    // Quick Chat
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF1677F2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 0,
                  ),
                  child: Text(
                    listing.status == HousingStatus.taken ? 'Property Taken' : 'Book Viewing', 
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)
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

class _HousingReportDialog extends ConsumerStatefulWidget {
  final HousingListing listing;
  const _HousingReportDialog({required this.listing});

  @override
  ConsumerState<_HousingReportDialog> createState() => _HousingReportDialogState();
}

class _HousingReportDialogState extends ConsumerState<_HousingReportDialog> {
  String _selectedCategory = 'Scam';
  final _reasonController = TextEditingController();
  bool _isSubmitting = false;

  final _categories = ['Scam', 'Fake listing', 'Already occupied', 'Duplicate', 'Offensive content', 'Wrong information'];

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    setState(() => _isSubmitting = true);
    
    try {
      await ref.read(housingRepositoryProvider).reportListing(
        listingId: widget.listing.id,
        reporterId: user.uid,
        category: _selectedCategory,
        reason: _reasonController.text.trim(),
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report submitted. Thank you for keeping UniHub safe.')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Report Listing', style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Why are you reporting this?', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.map((c) => ChoiceChip(
                label: Text(c, style: TextStyle(fontSize: 12, color: _selectedCategory == c ? Colors.white : Colors.black87)),
                selected: _selectedCategory == c,
                onSelected: (val) => setState(() => _selectedCategory = c),
                selectedColor: const Color(0xFF1677F2),
              )).toList(),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'Additional details (optional)',
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
          child: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Submit Report'),
        ),
      ],
    );
  }
}

class _HousingReviewDialog extends ConsumerStatefulWidget {
  final HousingListing listing;
  const _HousingReviewDialog({required this.listing});

  @override
  ConsumerState<_HousingReviewDialog> createState() => _HousingReviewDialogState();
}

class _HousingReviewDialogState extends ConsumerState<_HousingReviewDialog> {
  double _rating = 5;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    setState(() => _isSubmitting = true);
    
    try {
      final review = HousingReview(
        id: '',
        plugId: widget.listing.plugId,
        userId: user.uid,
        userName: user.fullName,
        userPhotoUrl: user.photoUrl,
        comment: _commentController.text.trim(),
        rating: _rating,
        createdAt: DateTime.now(),
      );

      await ref.read(housingRepositoryProvider).submitReview(review);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('Rate your experience', style: TextStyle(fontWeight: FontWeight.bold)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('How was your interaction with this plug?', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) => IconButton(
              icon: Icon(
                index < _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                color: const Color(0xFFFFB800),
                size: 32,
              ),
              onPressed: () => setState(() => _rating = index + 1.0),
            )),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _commentController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Share your feedback...',
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1677F2)),
          child: _isSubmitting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Submit'),
        ),
      ],
    );
  }
}
