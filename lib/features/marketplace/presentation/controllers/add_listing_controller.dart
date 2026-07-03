import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/campus_constants.dart';
import '../../domain/models/listing.dart';
import 'package:unihub_mobile/features/marketplace/shared/providers.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/shared/storage_repository.dart';

class AddListingState {
  final String id;
  final String title;
  final String description;
  final double price;
  final String category;
  final List<File> selectedImages;
  final List<String> existingImageUrls;
  final String campusLocation;
  final ListingCondition condition;
  final String? brand;
  final String? storage;
  final String? color;
  final bool isNegotiable;
  final int quantity;
  final List<String> tags;
  final bool isLoading;
  final double uploadProgress;
  final String? error;
  final Map<String, dynamic> attributes;
  final int currentStep;
  final bool isEditing;

  AddListingState({
    required this.id,
    this.title = '',
    this.description = '',
    this.price = 0.0,
    this.category = 'Electronics',
    this.selectedImages = const [],
    this.existingImageUrls = const [],
    this.campusLocation = '',
    this.condition = ListingCondition.good,
    this.brand,
    this.storage,
    this.color,
    this.isNegotiable = false,
    this.quantity = 1,
    this.tags = const [],
    this.isLoading = false,
    this.uploadProgress = 0,
    this.error,
    this.attributes = const {},
    this.currentStep = 0,
    this.isEditing = false,
  });

  double get qualityScore {
    int totalPoints = 0;
    const int maxPoints = 8;
    
    if (title.length > 10) totalPoints++;
    if (description.length > 50) totalPoints++;
    if (price > 0) totalPoints++;
    if (selectedImages.isNotEmpty || existingImageUrls.isNotEmpty) totalPoints += 2;
    if (campusLocation.isNotEmpty) totalPoints++;
    if (attributes.isNotEmpty) totalPoints++;
    if (condition != ListingCondition.good) totalPoints++;

    return totalPoints / maxPoints;
  }

  String get qualityLabel {
    final s = qualityScore;
    if (s < 0.4) return 'Basic';
    if (s < 0.7) return 'Great';
    return 'Professional';
  }

  Color get qualityColor {
    final s = qualityScore;
    if (s < 0.4) return const Color(0xFFFF4B4B);
    if (s < 0.7) return const Color(0xFFFFB800);
    return const Color(0xFF00C566);
  }

  AddListingState copyWith({
    String? title,
    String? description,
    double? price,
    String? category,
    List<File>? selectedImages,
    List<String>? existingImageUrls,
    String? campusLocation,
    ListingCondition? condition,
    String? brand,
    String? storage,
    String? color,
    bool? isNegotiable,
    int? quantity,
    List<String>? tags,
    bool? isLoading,
    double? uploadProgress,
    String? error,
    Map<String, dynamic>? attributes,
    int? currentStep,
    bool? isEditing,
  }) {
    return AddListingState(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      price: price ?? this.price,
      category: category ?? this.category,
      selectedImages: selectedImages ?? this.selectedImages,
      existingImageUrls: existingImageUrls ?? this.existingImageUrls,
      campusLocation: campusLocation ?? this.campusLocation,
      condition: condition ?? this.condition,
      brand: brand ?? this.brand,
      storage: storage ?? this.storage,
      color: color ?? this.color,
      isNegotiable: isNegotiable ?? this.isNegotiable,
      quantity: quantity ?? this.quantity,
      tags: tags ?? this.tags,
      isLoading: isLoading ?? this.isLoading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      error: error,
      attributes: attributes ?? this.attributes,
      currentStep: currentStep ?? this.currentStep,
      isEditing: isEditing ?? this.isEditing,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'price': price,
      'category': category,
      'campusLocation': campusLocation,
      'condition': condition.name,
      'brand': brand,
      'storage': storage,
      'color': color,
      'isNegotiable': isNegotiable,
      'quantity': quantity,
      'tags': tags,
      'attributes': attributes,
      'currentStep': currentStep,
      'isEditing': isEditing,
    };
  }
}

class AddListingController extends StateNotifier<AddListingState> {
  final Ref _ref;
  static const String _draftKey = 'listing_draft_v5';

  AddListingController(this._ref, Listing? initialListing) 
    : super(_createInitialState(initialListing)) {
    if (initialListing == null) {
      _loadDraft();
    }
  }

  static AddListingState _createInitialState(Listing? listing) {
    if (listing == null) {
      return AddListingState(id: const Uuid().v4(), isEditing: false);
    }
    return AddListingState(
      id: listing.id,
      title: listing.title,
      description: listing.description,
      price: listing.price,
      category: listing.category,
      existingImageUrls: listing.imageUrls,
      campusLocation: listing.campusLocation,
      condition: listing.condition,
      brand: listing.brand,
      storage: listing.storage,
      color: listing.color,
      isNegotiable: listing.isNegotiable,
      quantity: listing.quantity,
      tags: listing.tags,
      attributes: listing.attributes,
      currentStep: 0,
      isEditing: true,
    );
  }

  void updateTitle(String val) {
    state = state.copyWith(title: val);
    if (!state.isEditing) _saveDraft();
  }

  void updateDescription(String val) {
    state = state.copyWith(description: val);
    if (!state.isEditing) _saveDraft();
  }

  void updatePrice(double val) {
    state = state.copyWith(price: val);
    if (!state.isEditing) _saveDraft();
  }

  void updateCategory(String val) {
    state = state.copyWith(category: val, attributes: {});
    if (!state.isEditing) _saveDraft();
  }

  void updateCondition(ListingCondition val) {
    state = state.copyWith(condition: val);
    if (!state.isEditing) _saveDraft();
  }

  void updateLocation(String val) {
    state = state.copyWith(campusLocation: val);
    if (!state.isEditing) _saveDraft();
  }

  void updateBrand(String? val) {
    state = state.copyWith(brand: val);
    if (!state.isEditing) _saveDraft();
  }

  void updateStorage(String? val) {
    state = state.copyWith(storage: val);
    if (!state.isEditing) _saveDraft();
  }

  void updateColor(String? val) {
    state = state.copyWith(color: val);
    if (!state.isEditing) _saveDraft();
  }

  void toggleNegotiable(bool val) {
    state = state.copyWith(isNegotiable: val);
    if (!state.isEditing) _saveDraft();
  }

  void updateQuantity(int val) {
    state = state.copyWith(quantity: val);
    if (!state.isEditing) _saveDraft();
  }

  void updateTags(List<String> val) {
    state = state.copyWith(tags: val);
    if (!state.isEditing) _saveDraft();
  }

  void updateAttribute(String key, dynamic value) {
    final newAttr = Map<String, dynamic>.from(state.attributes);
    newAttr[key] = value;
    state = state.copyWith(attributes: newAttr);
    if (!state.isEditing) _saveDraft();
  }

  void nextStep() {
    if (state.currentStep < 2) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  Future<void> pickImages() async {
    try {
      final picker = ImagePicker();
      final images = await picker.pickMultiImage();
      if (images.isNotEmpty) {
        final current = List<File>.from(state.selectedImages);
        current.addAll(images.map((i) => File(i.path)));
        state = state.copyWith(selectedImages: current);
      }
    } catch (_) {}
  }

  void removeSelectedImage(File file) {
    final current = List<File>.from(state.selectedImages);
    current.remove(file);
    state = state.copyWith(selectedImages: current);
  }

  void reorderSelectedImages(int oldIndex, int newIndex) {
    final current = List<File>.from(state.selectedImages);
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex < 0 || oldIndex >= current.length) return;
    final item = current.removeAt(oldIndex);
    if (newIndex < 0 || newIndex > current.length) {
      current.add(item);
    } else {
      current.insert(newIndex, item);
    }
    state = state.copyWith(selectedImages: current);
  }

  void removeExistingImage(String url) {
    final current = List<String>.from(state.existingImageUrls);
    current.remove(url);
    state = state.copyWith(existingImageUrls: current);
  }

  Future<void> _saveDraft() async {
    if (state.isEditing) return; // Don't save drafts while editing existing items
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_draftKey, jsonEncode(state.toMap()));
    } catch (_) {}
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftJson = prefs.getString(_draftKey);
      if (draftJson != null) {
        final data = jsonDecode(draftJson);
        state = state.copyWith(
          title: data['title']?.toString() ?? '',
          description: data['description']?.toString() ?? '',
          price: (data['price'] ?? 0.0).toDouble(),
          category: data['category']?.toString() ?? 'Electronics',
          campusLocation: data['campusLocation']?.toString() ?? '',
          brand: data['brand']?.toString(),
          storage: data['storage']?.toString(),
          color: data['color']?.toString(),
          isNegotiable: data['isNegotiable'] == true,
          quantity: int.tryParse(data['quantity']?.toString() ?? '1') ?? 1,
          tags: (data['tags'] as List?)?.map((e) => e.toString()).toList() ?? [],
          attributes: Map<String, dynamic>.from(data['attributes'] ?? {}),
          currentStep: 0, // Always start at step 0
          isEditing: false,
        );
      }
    } catch (_) {
      await clearDraft();
    }
  }

  Future<void> clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_draftKey);
    } catch (_) {}
  }

  Future<bool> publish() async {
    if (state.title.isEmpty || state.price <= 0) {
      state = state.copyWith(error: 'Please provide a title and price');
      return false;
    }

    state = state.copyWith(isLoading: true, uploadProgress: 0, error: null);
    try {
      final user = _ref.read(appUserProvider).valueOrNull;
      if (user == null) throw Exception('User not found');

      final imageUrls = [...state.existingImageUrls];
      
      for (var i = 0; i < state.selectedImages.length; i++) {
        final url = await _ref.read(storageRepositoryProvider).uploadFile(
          path: 'listings/${state.id}',
          id: 'image_${DateTime.now().millisecondsSinceEpoch}_$i',
          file: state.selectedImages[i],
          onProgress: (sent, total) {
             state = state.copyWith(
               uploadProgress: (i / state.selectedImages.length) + 
                              ((sent / total) / state.selectedImages.length)
             );
          },
        );
        imageUrls.add(url);
      }

      state = state.copyWith(uploadProgress: 1.0);

      final listing = Listing(
        id: state.id,
        sellerId: user.uid,
        sellerName: user.fullName,
        sellerUniversity: CampusConstants.resolveToId(user.university) ?? user.university ?? 'Campus',
        sellerTrustScore: user.trustScore,
        title: state.title,
        description: state.description,
        price: state.price,
        category: state.category,
        imageUrls: imageUrls,
        campusLocation: state.campusLocation,
        condition: state.condition,
        brand: state.brand,
        storage: state.storage,
        color: state.color,
        isNegotiable: state.isNegotiable,
        quantity: state.quantity,
        tags: state.tags,
        attributes: state.attributes,
        createdAt: state.isEditing 
            ? (_ref.read(listingProvider(state.id)).value?.createdAt ?? DateTime.now())
            : DateTime.now(),
        updatedAt: state.isEditing ? DateTime.now() : null,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );

      if (state.isEditing) {
        await _ref.read(marketplaceRepositoryProvider).updateListing(listing);
      } else {
        await _ref.read(marketplaceRepositoryProvider).createListing(listing);
        await clearDraft();
      }

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final addListingControllerProvider = 
    StateNotifierProvider.family<AddListingController, AddListingState, Listing?>((ref, listing) {
  return AddListingController(ref, listing);
});
