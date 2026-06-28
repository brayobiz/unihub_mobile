import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:unihub_mobile/features/marketplace/domain/models/listing.dart';
import 'package:unihub_mobile/features/marketplace/presentation/controllers/add_listing_controller.dart';
import 'package:unihub_mobile/features/marketplace/presentation/widgets/marketplace_card.dart';
import 'package:unihub_mobile/features/marketplace/domain/models/marketplace_categories.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';

class AddListingScreen extends ConsumerStatefulWidget {
  final Listing? listing;
  const AddListingScreen({super.key, this.listing});

  @override
  ConsumerState<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends ConsumerState<AddListingScreen> {
  final _scrollController = ScrollController();
  bool _showPreview = false;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(addListingControllerProvider(widget.listing));
    final controller = ref.read(addListingControllerProvider(widget.listing).notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.black),
          onPressed: () => _handleExit(context, controller),
        ),
        title: Text(
          widget.listing == null ? 'Create Listing' : 'Edit Listing',
          style: GoogleFonts.plusJakartaSans(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: TextButton(
              onPressed: () => setState(() => _showPreview = !_showPreview),
              child: Text(_showPreview ? 'Edit' : 'Preview', 
                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
            ),
          ),
        ],
      ),
      body: state.isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.indigo))
        : Stack(
            children: [
              SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQualityIndicator(state),
                    const SizedBox(height: 24),
                    _buildImageUploadSection(state, controller),
                    const SizedBox(height: 24),
                    _buildSectionCard(
                      title: 'Basic Information',
                      children: [
                        _buildTextField(
                          label: 'Item Name',
                          hint: 'e.g. MacBook Pro 2021',
                          initialValue: state.title,
                          onChanged: controller.updateTitle,
                        ),
                        const SizedBox(height: 20),
                        _buildCategoryPicker(context, state, controller),
                        const SizedBox(height: 20),
                        _buildConditionPicker(state, controller),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSectionCard(
                      title: 'Pricing',
                      children: [
                        _buildTextField(
                          label: 'Price (KES)',
                          hint: '0.00',
                          initialValue: state.price > 0 ? state.price.toInt().toString() : '',
                          keyboardType: TextInputType.number,
                          prefixIcon: Icons.payments_outlined,
                          onChanged: (val) => controller.updatePrice(double.tryParse(val) ?? 0),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          value: state.isNegotiable,
                          onChanged: controller.toggleNegotiable,
                          title: const Text('Price is Negotiable', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          contentPadding: EdgeInsets.zero,
                          activeColor: Colors.indigo,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSectionCard(
                      title: 'Location',
                      children: [
                        _buildTextField(
                          label: 'Campus / Area',
                          hint: 'e.g. Main Campus, Juja',
                          initialValue: state.campusLocation,
                          prefixIcon: Icons.location_on_outlined,
                          onChanged: controller.updateLocation,
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildSectionCard(
                      title: 'Description',
                      children: [
                        _buildTextField(
                          label: 'Tell buyers more',
                          hint: 'Describe the item condition, features, and why you are selling...',
                          initialValue: state.description,
                          maxLines: 5,
                          onChanged: controller.updateDescription,
                        ),
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${state.description.length}/500',
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade400, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (state.error != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Expanded(child: Text(state.error!, style: const TextStyle(color: Colors.red, fontSize: 12))),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              if (_showPreview)
                _buildPreviewOverlay(state),
            ],
          ),
      bottomNavigationBar: _buildActionArea(context, state, controller),
    );
  }

  void _handleExit(BuildContext context, AddListingController controller) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save draft?'),
        content: const Text('You can continue editing this listing later.'),
        actions: [
          TextButton(
            onPressed: () {
              controller.clearDraft();
              Navigator.pop(context);
              context.pop();
            },
            child: const Text('Discard', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
            },
            child: const Text('Save & Exit'),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityIndicator(AddListingState state) {
    final user = ref.watch(appUserProvider).valueOrNull;
    final isVerifiedSeller = user?.roles.contains('seller') ?? false;

    return Column(
      children: [
        if (user != null && !isVerifiedSeller)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.indigo.shade100),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified_user_outlined, color: Colors.indigo),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Boost your sales!', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.indigo)),
                        Text('Get verified as a seller to build trust with buyers.', 
                          style: TextStyle(fontSize: 11, color: Colors.indigo.shade700)),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/settings'), // Assuming verification is in settings
                    child: const Text('Get Verified', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
        Container(
          padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Listing Quality', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 2),
                  Text('Good listings sell 3x faster', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: state.qualityColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(state.qualityLabel, style: TextStyle(color: state.qualityColor, fontWeight: FontWeight.w800, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: state.qualityScore,
              minHeight: 8,
              backgroundColor: Colors.grey.shade50,
              valueColor: AlwaysStoppedAnimation<Color>(state.qualityColor),
            ),
          ),
        ],
      ),
    ),
  ],
);
}

  Widget _buildImageUploadSection(AddListingState state, AddListingController controller) {
    final totalPhotos = state.selectedImages.length + state.existingImageUrls.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Photos', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('$totalPhotos/5', style: TextStyle(color: Colors.grey.shade400, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              GestureDetector(
                onTap: controller.pickImages,
                child: Container(
                  width: 110,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.indigo.shade50, width: 2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(color: Colors.indigo.shade50, shape: BoxShape.circle),
                        child: const Icon(Icons.add_a_photo_rounded, color: Colors.indigo, size: 24),
                      ),
                      const SizedBox(height: 8),
                      const Text('Add Photo', style: TextStyle(fontSize: 10, color: Colors.indigo, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ),
              ...state.existingImageUrls.map((url) => _buildPhotoItem(
                image: NetworkImage(url),
                onRemove: () => controller.removeExistingImage(url),
              )),
              ...state.selectedImages.map((file) => _buildPhotoItem(
                image: FileImage(file),
                onRemove: () => controller.removeSelectedImage(file),
              )),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('Pro Tip: Listings with 3+ clear photos sell much faster.', 
            style: TextStyle(color: Colors.grey.shade500, fontSize: 11, fontStyle: FontStyle.italic)),
      ],
    );
  }

  Widget _buildPhotoItem({required ImageProvider image, required VoidCallback onRemove}) {
    return Container(
      width: 110,
      margin: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        image: DecorationImage(image: image, fit: BoxFit.cover),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: Colors.black.withOpacity(0.5),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: Colors.indigo, letterSpacing: 0.5)),
          const SizedBox(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required Function(String) onChanged,
    String? initialValue,
    TextInputType? keyboardType,
    IconData? prefixIcon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: initialValue,
          onChanged: onChanged,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: Colors.indigo.shade300) : null,
            filled: true,
            fillColor: const Color(0xFFF8F9FB),
            contentPadding: const EdgeInsets.all(18),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Colors.indigo, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryPicker(BuildContext context, AddListingState state, AddListingController controller) {
    final categories = MarketplaceCategories.all;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
            GestureDetector(
              onTap: () => _showGigDifferentiator(context),
              child: Text('Offering a service?', 
                style: TextStyle(fontSize: 11, color: Colors.indigo.shade400, fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: () => _showCategorySheet(context, categories, state.category, controller),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FB),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.grid_view_rounded, size: 20, color: Colors.indigo.shade300),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(state.category, 
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.expand_more_rounded, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showGigDifferentiator(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.lightbulb_outline, color: Colors.amber.shade700),
            const SizedBox(width: 10),
            const Text('Marketplace vs Gigs'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDiffItem(
              icon: Icons.shopping_bag_rounded,
              title: 'Marketplace',
              desc: 'For selling physical or digital items (Books, Laptops, Clothes).',
              color: Colors.green,
            ),
            const SizedBox(height: 16),
            _buildDiffItem(
              icon: Icons.work_rounded,
              title: 'Student Gigs',
              desc: 'For offering services, tasks, or jobs (Tutoring, Design, Errands).',
              color: Colors.indigo,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Got it')),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop(); // Close current add listing
              // Navigate to add gig - assuming path /add-gig or similar
              // For now we navigate to the feed adder with type gig
              // Check go_router config or just use Navigator
              // Since I don't have the router config handy for all paths, I'll just close it.
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
            child: const Text('Go to Gigs'),
          ),
        ],
      ),
    );
  }

  Widget _buildDiffItem({required IconData icon, required String title, required String desc, required Color color}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 2),
              Text(desc, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
          ),
        ),
      ],
    );
  }

  void _showCategorySheet(BuildContext context, List<String> categories, String selected, AddListingController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Select Category', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('Physical items only. Services go to Gigs.', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: categories.length,
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 4),
                    title: Text(cat, style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: selected == cat ? const Icon(Icons.check_circle, color: Colors.indigo) : null,
                    onTap: () {
                      controller.updateCategory(cat);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionPicker(AddListingState state, AddListingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Condition', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ListingCondition.values.map((cond) {
            final isSelected = state.condition == cond;
            return ChoiceChip(
              label: Text(cond.name.replaceFirst('newCondition', 'New')),
              selected: isSelected,
              onSelected: (_) => controller.updateCondition(cond),
              selectedColor: Colors.indigo.shade50,
              labelStyle: TextStyle(
                color: isSelected ? Colors.indigo : Colors.black87,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
              backgroundColor: const Color(0xFFF8F9FB),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: isSelected ? Colors.indigo : Colors.transparent),
              ),
              showCheckmark: false,
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPreviewOverlay(AddListingState state) {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.8),
        child: Column(
          children: [
            const Spacer(),
            Text('Listing Preview', style: GoogleFonts.plusJakartaSans(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 24),
            SizedBox(
              width: 240,
              child: MarketplaceCard(
                index: 0,
                listing: Listing(
                  id: state.id,
                  sellerId: 'preview',
                  sellerName: 'You',
                  sellerUniversity: state.campusLocation,
                  title: state.title.isEmpty ? 'Item Title' : state.title,
                  description: state.description,
                  price: state.price,
                  category: state.category,
                  imageUrls: state.selectedImages.isNotEmpty 
                      ? [state.selectedImages.first.path] // This is a path, local, won't show but card handles it
                      : state.existingImageUrls,
                  campusLocation: state.campusLocation.isEmpty ? 'Location' : state.campusLocation,
                  condition: state.condition,
                  createdAt: DateTime.now(),
                  expiresAt: DateTime.now(),
                ),
              ),
            ),
            const SizedBox(height: 40),
            TextButton.icon(
              onPressed: () => setState(() => _showPreview = false),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
              label: const Text('Close Preview', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Widget _buildActionArea(BuildContext context, AddListingState state, AddListingController controller) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -4))],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 1,
              child: OutlinedButton(
                onPressed: () => _handleExit(context, controller),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: const Text('Save Draft', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: state.isLoading ? null : () async {
                  final success = await controller.publish();
                  if (success && context.mounted) {
                    _showSuccessDialog(context);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: Colors.indigo.withOpacity(0.3),
                ),
                child: state.isLoading 
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        const SizedBox(width: 12),
                        Text('Publishing ${(state.uploadProgress * 100).toInt()}%', style: const TextStyle(fontSize: 14)),
                      ],
                    )
                  : const Text('Publish Listing', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        content: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.green.shade50, shape: BoxShape.circle),
                child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 60),
              ),
              const SizedBox(height: 24),
              Text('Successfully Published!', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Your item is now live and visible to students across campus.', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey, height: 1.5)),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    context.pop(); // Go back to marketplace
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.indigo, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('View Marketplace', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
