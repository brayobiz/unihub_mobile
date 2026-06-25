import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
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
  final bool isNegotiable;
  final bool isLoading;
  final double uploadProgress;
  final String? error;
  final Map<String, dynamic> extraFields;

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
    this.isNegotiable = false,
    this.isLoading = false,
    this.uploadProgress = 0,
    this.error,
    this.extraFields = const {},
  });

  double get qualityScore {
    double score = 0;
    if (title.length > 10) score += 0.2;
    if (description.length > 50) score += 0.3;
    if (price > 0) score += 0.1;
    if (selectedImages.isNotEmpty || existingImageUrls.isNotEmpty) score += 0.2;
    if (campusLocation.isNotEmpty) score += 0.2;
    return score;
  }

  String get qualityLabel {
    final s = qualityScore;
    if (s < 0.4) return 'Needs Work';
    if (s < 0.7) return 'Good';
    return 'Excellent';
  }

  Color get qualityColor {
    final s = qualityScore;
    if (s < 0.4) return Colors.red;
    if (s < 0.7) return Colors.orange;
    return Colors.green;
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
    bool? isNegotiable,
    bool? isLoading,
    double? uploadProgress,
    String? error,
    Map<String, dynamic>? extraFields,
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
      isNegotiable: isNegotiable ?? this.isNegotiable,
      isLoading: isLoading ?? this.isLoading,
      uploadProgress: uploadProgress ?? this.uploadProgress,
      error: error,
      extraFields: extraFields ?? this.extraFields,
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
      'isNegotiable': isNegotiable,
    };
  }
}

class AddListingController extends StateNotifier<AddListingState> {
  final Ref _ref;
  static const String _draftKey = 'listing_draft';

  AddListingController(this._ref, Listing? initialListing) 
    : super(AddListingState(id: initialListing?.id ?? const Uuid().v4())) {
    if (initialListing != null) {
      state = state.copyWith(
        title: initialListing.title,
        description: initialListing.description,
        price: initialListing.price,
        category: initialListing.category,
        existingImageUrls: initialListing.imageUrls,
        campusLocation: initialListing.campusLocation,
        condition: initialListing.condition,
      );
    } else {
      _loadDraft();
    }
  }

  void updateTitle(String val) {
    state = state.copyWith(title: val);
    _saveDraft();
  }

  void updateDescription(String val) {
    state = state.copyWith(description: val);
    _saveDraft();
  }

  void updatePrice(double val) {
    state = state.copyWith(price: val);
    _saveDraft();
  }

  void updateCategory(String val) {
    state = state.copyWith(category: val, extraFields: {});
    _saveDraft();
  }

  void updateCondition(ListingCondition val) {
    state = state.copyWith(condition: val);
    _saveDraft();
  }

  void updateLocation(String val) {
    state = state.copyWith(campusLocation: val);
    _saveDraft();
  }

  void toggleNegotiable(bool val) {
    state = state.copyWith(isNegotiable: val);
    _saveDraft();
  }

  Future<void> pickImages() async {
    final picker = ImagePicker();
    final images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      final current = List<File>.from(state.selectedImages);
      current.addAll(images.map((i) => File(i.path)));
      state = state.copyWith(selectedImages: current);
    }
  }

  void removeSelectedImage(File file) {
    final current = List<File>.from(state.selectedImages);
    current.remove(file);
    state = state.copyWith(selectedImages: current);
  }

  void removeExistingImage(String url) {
    final current = List<String>.from(state.existingImageUrls);
    current.remove(url);
    state = state.copyWith(existingImageUrls: current);
  }

  Future<void> _saveDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, jsonEncode(state.toMap()));
  }

  Future<void> _loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draftJson = prefs.getString(_draftKey);
    if (draftJson != null) {
      final data = jsonDecode(draftJson);
      state = state.copyWith(
        title: data['title'] ?? '',
        description: data['description'] ?? '',
        price: (data['price'] ?? 0.0).toDouble(),
        category: data['category'] ?? 'Electronics',
        campusLocation: data['campusLocation'] ?? '',
        isNegotiable: data['isNegotiable'] ?? false,
      );
    }
  }

  Future<void> clearDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
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
      
      // Upload New Images
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
        sellerUniversity: user.university ?? 'Campus',
        sellerTrustScore: user.trustScore,
        title: state.title,
        description: state.description,
        price: state.price,
        category: state.category,
        imageUrls: imageUrls,
        campusLocation: state.campusLocation,
        condition: state.condition,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 30)),
      );

      await _ref.read(marketplaceRepositoryProvider).createListing(listing);
      await clearDraft();
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
