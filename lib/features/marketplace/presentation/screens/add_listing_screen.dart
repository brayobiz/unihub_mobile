import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/features/marketplace/domain/models/listing.dart';
import 'package:unihub_mobile/features/marketplace/presentation/controllers/add_listing_controller.dart';
import 'package:unihub_mobile/features/marketplace/presentation/widgets/marketplace_card.dart';
import 'package:unihub_mobile/features/marketplace/domain/models/marketplace_categories.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/core/widgets/creation_success_dialog.dart';
import 'package:unihub_mobile/features/ads/ads_module.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AddListingScreen extends ConsumerStatefulWidget {
  final Listing? listing;
  const AddListingScreen({super.key, this.listing});

  @override
  ConsumerState<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends ConsumerState<AddListingScreen> {
  late final PageController _pageController;
  bool _showPreview = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 0);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(appUserProvider).valueOrNull;
    final state = ref.watch(addListingControllerProvider(widget.listing));
    final controller = ref.read(addListingControllerProvider(widget.listing).notifier);

    final int currentStep = state.currentStep;

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface, size: 20),
          onPressed: () {
            if (currentStep > 0) {
              _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
              controller.previousStep();
            } else {
              _handleExit(context, controller);
            }
          },
        ),
        title: Column(
          children: [
            Text(
              widget.listing == null ? 'Create Listing' : 'Edit Listing',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurface, 
                fontWeight: FontWeight.bold, 
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 4),
            _buildStepIndicator(currentStep),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(_showPreview ? Icons.edit_note_rounded : Icons.remove_red_eye_outlined, color: theme.colorScheme.primary),
              onPressed: () => setState(() => _showPreview = !_showPreview),
            ),
          ),
        ],
      ),
      body: state.isLoading 
        ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
        : Stack(
            children: [
              PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1(state, controller),
                  _buildStep2(state, controller),
                  _buildStep3(state, controller),
                ],
              ),
              if (_showPreview)
                _buildPreviewOverlay(state),
            ],
          ),
      bottomNavigationBar: _buildBottomAction(state, controller),
    );
  }

  Widget _buildStepIndicator(int currentStep) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        final bool isActive = index <= currentStep;
        return Container(
          width: 24,
          height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            color: isActive ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Widget _buildStep1(AddListingState state, AddListingController controller) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQualityIndicator(state),
          const SizedBox(height: 32),
          Text(
            'What are you selling?', 
            style: theme.textTheme.displaySmall?.copyWith(
              fontSize: 22, 
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select a category and add photos of your item.', 
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          _buildCategoryGrid(state, controller),
          const SizedBox(height: 32),
          _buildImageUploadSection(state, controller),
        ],
      ),
    );
  }

  Widget _buildStep2(AddListingState state, AddListingController controller) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Item Details', 
            style: theme.textTheme.displaySmall?.copyWith(
              fontSize: 22, 
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Provide more information about your ${state.category.toLowerCase()}.', 
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 32),
          _buildTextField(
            label: 'Listing Title',
            hint: 'e.g. iPhone 13 Pro Max - 256GB',
            initialValue: state.title,
            onChanged: (val) => controller.updateTitle(val),
          ),
          const SizedBox(height: 24),
          _buildConditionPicker(state, controller),
          const SizedBox(height: 32),
          _buildSectionHeader(context, 'Specifications', Icons.settings_suggest_outlined),
          const SizedBox(height: 16),
          _buildCategorySpecificFields(state, controller),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 10),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildStep3(AddListingState state, AddListingController controller) {
    final theme = Theme.of(context);
    final user = ref.watch(appUserProvider).valueOrNull;
    final bool isVerified = user?.isIdentityVerified == true || 
                           user?.isStudentVerified == true || 
                           user?.accountType == 'business';
    final int quantity = state.quantity;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Final Details', 
            style: theme.textTheme.displaySmall?.copyWith(
              fontSize: 22, 
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 32),
          _buildTextField(
            label: 'Price (KES)',
            hint: '0.00',
            initialValue: state.price > 0 ? state.price.toInt().toString() : '',
            keyboardType: TextInputType.number,
            prefixIcon: Icons.payments_outlined,
            onChanged: (val) {
              final d = double.tryParse(val);
              if (d != null) controller.updatePrice(d);
            },
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            value: state.isNegotiable,
            onChanged: (val) => controller.toggleNegotiable(val),
            title: Text(
              'Negotiable', 
              style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
            ),
            subtitle: Text('Allow buyers to make offers', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
            contentPadding: EdgeInsets.zero,
            activeTrackColor: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          _buildSectionHeader(context, 'Growth Phase: Free Promotions', Icons.rocket_launch_outlined),
          const SizedBox(height: 8),
          if (isVerified)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'As a verified user, you get premium visibility for free during our Early Bird phase!',
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            )
          else
            InkWell(
              onTap: () => context.push('/trust-center'),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline_rounded, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Premium Visibility Locked',
                            style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                          ),
                          Text(
                            'Verify your identity to unlock Boost, Feature, and Sponsored slots for free!',
                            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: theme.colorScheme.primary),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          _buildPromotionToggle(
            title: 'Feature Listing',
            subtitle: 'Place your item in the "Featured" section for 7 days.',
            value: state.promoteAsFeatured,
            onChanged: isVerified ? (val) => controller.togglePromoteFeatured(val) : null,
          ),
          _buildPromotionToggle(
            title: 'Sponsored Slot',
            subtitle: 'Keep your item at the top of search results for 3 days.',
            value: state.promoteAsSponsored,
            onChanged: isVerified ? (val) => controller.togglePromoteSponsored(val) : null,
          ),
          _buildPromotionToggle(
            title: 'Instant Boost',
            subtitle: 'Push your listing to the top of the "Recently Added" feed.',
            value: state.applyBoost,
            onChanged: isVerified ? (val) => controller.toggleApplyBoost(val) : null,
          ),
          const SizedBox(height: 24),
          _buildTextField(
            label: 'Quantity (Optional)',
            hint: '1',
            initialValue: quantity.toString(),
            keyboardType: TextInputType.number,
            onChanged: (val) {
              final q = int.tryParse(val);
              if (q != null) controller.updateQuantity(q);
            },
          ),
          const SizedBox(height: 32),
          _buildTextField(
            label: 'Description',
            hint: 'Describe your item in detail...',
            initialValue: state.description,
            maxLines: 5,
            onChanged: (val) => controller.updateDescription(val),
          ),
          const SizedBox(height: 32),
          _buildTextField(
            label: 'Meetup Location',
            hint: 'e.g. Student Center, Main Campus',
            initialValue: state.campusLocation,
            prefixIcon: Icons.location_on_outlined,
            onChanged: (val) => controller.updateLocation(val),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid(AddListingState state, AddListingController controller) {
    final theme = Theme.of(context);
    const categories = MarketplaceCategories.all;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.9,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        final bool isSelected = state.category == cat;
        return GestureDetector(
          onTap: () => controller.updateCategory(cat),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? theme.colorScheme.primary.withValues(alpha: 0.05) : theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(MarketplaceCategories.getIcon(cat), style: const TextStyle(fontSize: 24)),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Text(
                    cat,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageUploadSection(AddListingState state, AddListingController controller) {
    final theme = Theme.of(context);
    final int totalPhotos = state.selectedImages.length + state.existingImageUrls.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Photos', 
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold, 
                fontSize: 16,
                color: theme.colorScheme.onSurface,
              ),
            ),
            Text(
              '$totalPhotos/10', 
              style: TextStyle(
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5), 
                fontSize: 13, 
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 120,
          child: ReorderableListView(
            scrollDirection: Axis.horizontal,
            onReorder: (int oldIdx, int newIdx) {
              controller.reorderSelectedImages(oldIdx, newIdx);
            },
            proxyDecorator: (child, index, animation) => child,
            children: [
              GestureDetector(
                key: const ValueKey('add_button'),
                onTap: () => controller.pickImages(),
                child: Container(
                  width: 120,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5), width: 2, style: BorderStyle.solid),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_a_photo_outlined, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5), size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'Add Photo', 
                        style: TextStyle(
                          fontSize: 12, 
                          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5), 
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              ...state.existingImageUrls.map((url) => _buildPhotoItem(
                key: ValueKey(url),
                image: NetworkImage(url),
                onRemove: () => controller.removeExistingImage(url),
                isHero: state.existingImageUrls.indexOf(url) == 0 && state.selectedImages.isEmpty,
              )),
              ...state.selectedImages.map((file) => _buildPhotoItem(
                key: ValueKey(file.path),
                image: FileImage(file),
                onRemove: () => controller.removeSelectedImage(file),
                isHero: state.selectedImages.indexOf(file) == 0 && state.existingImageUrls.isEmpty,
              )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoItem({required Key key, required ImageProvider image, required VoidCallback onRemove, bool isHero = false}) {
    return Container(
      key: key,
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        image: DecorationImage(image: image, fit: BoxFit.cover),
      ),
      child: Stack(
        children: [
          if (isHero)
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFF007BFF), borderRadius: BorderRadius.circular(8)),
                child: const Text('Cover', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.close, size: 16, color: Colors.black),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategorySpecificFields(AddListingState state, AddListingController controller) {
    switch (state.category) {
      case MarketplaceCategories.electronics:
      case MarketplaceCategories.phones:
      case MarketplaceCategories.computers:
        return Column(
          children: [
            _buildAttributeField('Brand', 'e.g. Apple, Samsung', 'brand', state, controller),
            const SizedBox(height: 16),
            _buildAttributeField('Model', 'e.g. iPhone 13 Pro', 'model', state, controller),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildAttributeField('Storage', 'e.g. 256GB', 'storage', state, controller)),
                const SizedBox(width: 16),
                Expanded(child: _buildAttributeField('Color', 'e.g. Sierra Blue', 'color', state, controller)),
              ],
            ),
          ],
        );
      case MarketplaceCategories.vehicles:
        return Column(
          children: [
            Row(
              children: [
                Expanded(child: _buildAttributeField('Make', 'e.g. Toyota', 'make', state, controller)),
                const SizedBox(width: 16),
                Expanded(child: _buildAttributeField('Model', 'e.g. Corolla', 'model', state, controller)),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildAttributeField('Year', 'e.g. 2018', 'year', state, controller, keyboardType: TextInputType.number)),
                const SizedBox(width: 16),
                Expanded(child: _buildAttributeField('Mileage', 'e.g. 45,000 km', 'mileage', state, controller)),
              ],
            ),
          ],
        );
      case MarketplaceCategories.fashion:
      case MarketplaceCategories.shoes:
        return Column(
          children: [
            _buildAttributeField('Brand', 'e.g. Zara', 'brand', state, controller),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildAttributeField('Size', 'e.g. XL, 42', 'size', state, controller)),
                const SizedBox(width: 16),
                Expanded(child: _buildAttributeField('Gender', 'e.g. Unisex', 'gender', state, controller)),
              ],
            ),
            const SizedBox(height: 16),
            _buildAttributeField('Material', 'e.g. Cotton, Leather', 'material', state, controller),
          ],
        );
      case MarketplaceCategories.books:
        return Column(
          children: [
            _buildAttributeField('Author', 'e.g. J.K. Rowling', 'author', state, controller),
            const SizedBox(height: 16),
            _buildAttributeField('Edition', 'e.g. 3rd Edition', 'edition', state, controller),
          ],
        );
      case MarketplaceCategories.furniture:
      case MarketplaceCategories.homeEssentials:
      case MarketplaceCategories.kitchen:
        return Column(
          children: [
            _buildAttributeField('Type', 'e.g. Dining Table, Blender', 'type', state, controller),
            const SizedBox(height: 16),
            _buildAttributeField('Material', 'e.g. Wood, Metal', 'material', state, controller),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildAttributeField('Dimensions', 'e.g. 120x80cm', 'dimensions', state, controller)),
                const SizedBox(width: 16),
                Expanded(child: _buildAttributeField('Color', 'e.g. Oak', 'color', state, controller)),
              ],
            ),
          ],
        );
      case MarketplaceCategories.sports:
        return Column(
          children: [
            _buildAttributeField('Type', 'e.g. Treadmill, Racket', 'type', state, controller),
            const SizedBox(height: 16),
            _buildAttributeField('Brand', 'e.g. Adidas, York', 'brand', state, controller),
          ],
        );
      default:
        return Column(
          children: [
            _buildAttributeField('Brand', 'Optional', 'brand', state, controller),
            const SizedBox(height: 16),
            _buildAttributeField('Color', 'Optional', 'color', state, controller),
          ],
        );
    }
  }

  Widget _buildAttributeField(String label, String hint, String key, AddListingState state, AddListingController controller, {TextInputType? keyboardType}) {
    return _buildTextField(
      label: label,
      hint: hint,
      initialValue: state.attributes[key]?.toString() ?? '',
      keyboardType: keyboardType,
      onChanged: (val) => controller.updateAttribute(key, val),
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
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label, 
          style: TextStyle(
            fontSize: 14, 
            fontWeight: FontWeight.bold, 
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          initialValue: initialValue,
          onChanged: onChanged,
          keyboardType: keyboardType,
          maxLines: maxLines,
          style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: theme.colorScheme.onSurfaceVariant) : null,
            filled: true,
            fillColor: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
            contentPadding: const EdgeInsets.all(20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildConditionPicker(AddListingState state, AddListingController controller) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Condition', 
          style: TextStyle(
            fontSize: 14, 
            fontWeight: FontWeight.bold, 
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: ListingCondition.values.map((cond) {
            final bool isSelected = state.condition == cond;
            return Expanded(
              child: GestureDetector(
                onTap: () => controller.updateCondition(cond),
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      cond.name.replaceFirst('newCondition', 'New'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPromotionToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    final theme = Theme.of(context);
    final bool isEnabled = onChanged != null;

    return SwitchListTile(
      value: isEnabled ? value : false,
      onChanged: onChanged,
      title: Text(
        title, 
        style: TextStyle(
          fontWeight: FontWeight.bold, 
          color: isEnabled ? theme.colorScheme.onSurface : theme.colorScheme.onSurface.withValues(alpha: 0.4), 
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        subtitle, 
        style: theme.textTheme.bodySmall?.copyWith(
          color: isEnabled ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        ),
      ),
      contentPadding: EdgeInsets.zero,
      activeTrackColor: theme.colorScheme.primary,
    );
  }

  Widget _buildQualityIndicator(AddListingState state) {
    final theme = Theme.of(context);
    final double qualityScore = state.qualityScore;
    final Color qualityColor = state.qualityColor;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: qualityColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Listing Quality: ${state.qualityLabel}', 
                    style: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800, fontSize: 14, color: qualityColor)),
                ],
              ),
              Text('${(qualityScore * 100).toInt()}%', 
                style: TextStyle(color: qualityColor, fontWeight: FontWeight.w900, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: qualityScore,
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceVariant.withValues(alpha: 0.3),
              valueColor: AlwaysStoppedAnimation<Color>(qualityColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction(AddListingState state, AddListingController controller) {
    final theme = Theme.of(context);
    final int currentStep = state.currentStep;
    final bool isLastStep = currentStep >= 2;
    
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: Row(
        children: [
          if (currentStep > 0) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  if (_pageController.hasClients) {
                    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  }
                  controller.previousStep();
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
                child: Text(
                  'Back', 
                  style: TextStyle(color: theme.colorScheme.onSurface, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: state.isLoading ? null : () async {
                if (isLastStep) {
                  final success = await controller.publish();
                  if (success && mounted) {
                    _showSuccessDialog(context);
                  }
                } else {
                  if (_pageController.hasClients) {
                    _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  }
                  controller.nextStep();
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(
                isLastStep ? (widget.listing == null ? 'Create Listing' : 'Save Changes') : 'Continue',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewOverlay(AddListingState state) {
    final theme = Theme.of(context);
    final int quantity = state.quantity;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.9),
        child: Column(
          children: [
            const Spacer(),
            Text('Listing Preview', style: theme.textTheme.titleLarge?.copyWith(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
            const SizedBox(height: 32),
            SizedBox(
              width: 280,
              child: MarketplaceCard(
                index: 0,
                listing: Listing(
                  id: state.id,
                  sellerId: 'preview',
                  sellerName: 'You',
                  sellerUniversity: state.campusLocation.isEmpty ? 'University' : state.campusLocation,
                  title: state.title.isEmpty ? 'Item Title' : state.title,
                  description: state.description,
                  price: state.price,
                  category: state.category,
                  imageUrls: state.selectedImages.isNotEmpty 
                      ? state.selectedImages.map((e) => e.path).toList()
                      : state.existingImageUrls,
                  campusLocation: state.campusLocation,
                  condition: state.condition,
                  isNegotiable: state.isNegotiable,
                  quantity: quantity,
                  attributes: state.attributes,
                  createdAt: DateTime.now(),
                  expiresAt: DateTime.now(),
                ),
              ),
            ),
            const SizedBox(height: 48),
            IconButton(
              onPressed: () => setState(() => _showPreview = false),
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 40),
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  void _handleExit(BuildContext context, AddListingController controller) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Discard changes'),
        content: const Text('You have unsaved changes. Are you sure you want to discard them?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep Editing'),
          ),
          TextButton(
            onPressed: () {
              controller.clearDraft();
              Navigator.pop(context);
              context.pop();
            },
            child: const Text('Discard', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showSuccessDialog(BuildContext context) {
    // Attempt to show interstitial ad before the success dialog
    ref.read(adServiceProvider).loadInterstitialAd(
      onAdLoaded: (ad) {
        ref.read(adServiceProvider).showInterstitialAd(
          ad,
          onAdDismissed: () {
             if (mounted) _displaySuccessDialog(context);
          },
        );
      },
      onAdFailedToLoad: (_) {
         if (mounted) _displaySuccessDialog(context);
      },
    );
  }

  void _displaySuccessDialog(BuildContext context) {
    CreationSuccessDialog.show(
      context,
      title: widget.listing == null ? 'Item Listed!' : 'Listing Updated!',
      message: widget.listing == null
          ? 'Your item is now live on UniHub! Interested students can now view and make offers.'
          : 'Your listing has been successfully updated.',
    );
  }
}
