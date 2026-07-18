import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:unihub_mobile/core/location/models/location_data.dart';
import '../../domain/models/event.dart';
import '../../shared/providers.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/shared/storage_repository.dart';

class CreateEventState {
  final String id;
  final String organizerId;
  final String campusId;
  final String title;
  final String description;
  final String categoryId;
  final List<File> selectedImages;
  final List<String> existingImageUrls;
  final LocationData? venue;
  final String venueRoom;
  final DateTime? startAt;
  final DateTime? endAt;
  final EventVisibility visibility;
  final bool isRegistrationRequired;
  final String? registrationUrl;
  final int? maxCapacity;
  
  final bool isLoading;
  final String? error;
  final int currentStep;
  final bool isEditing;
  final DateTime? createdAt;

  CreateEventState({
    required this.id,
    required this.organizerId,
    required this.campusId,
    this.title = '',
    this.description = '',
    this.categoryId = '',
    this.selectedImages = const [],
    this.existingImageUrls = const [],
    this.venue,
    this.venueRoom = '',
    this.startAt,
    this.endAt,
    this.visibility = EventVisibility.public,
    this.isRegistrationRequired = false,
    this.registrationUrl,
    this.maxCapacity,
    this.isLoading = false,
    this.error,
    this.currentStep = 0,
    this.isEditing = false,
    this.createdAt,
  });

  CreateEventState copyWith({
    String? title,
    String? description,
    String? categoryId,
    List<File>? selectedImages,
    List<String>? existingImageUrls,
    LocationData? venue,
    String? venueRoom,
    DateTime? startAt,
    DateTime? endAt,
    EventVisibility? visibility,
    bool? isRegistrationRequired,
    String? registrationUrl,
    int? maxCapacity,
    bool? isLoading,
    String? error,
    int? currentStep,
    DateTime? createdAt,
  }) {
    return CreateEventState(
      id: id,
      organizerId: organizerId,
      campusId: campusId,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      selectedImages: selectedImages ?? this.selectedImages,
      existingImageUrls: existingImageUrls ?? this.existingImageUrls,
      venue: venue ?? this.venue,
      venueRoom: venueRoom ?? this.venueRoom,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      visibility: visibility ?? this.visibility,
      isRegistrationRequired: isRegistrationRequired ?? this.isRegistrationRequired,
      registrationUrl: registrationUrl ?? this.registrationUrl,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      currentStep: currentStep ?? this.currentStep,
      isEditing: isEditing,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

class CreateEventController extends StateNotifier<CreateEventState> {
  final Ref _ref;

  CreateEventController(this._ref, {Event? initialEvent, required String organizerId, required String campusId})
      : super(_createInitialState(initialEvent, organizerId, campusId));

  static CreateEventState _createInitialState(Event? event, String organizerId, String campusId) {
    if (event == null) {
      return CreateEventState(
        id: const Uuid().v4(),
        organizerId: organizerId,
        campusId: campusId,
      );
    }
    return CreateEventState(
      id: event.id,
      organizerId: event.organizerId,
      campusId: event.campusId,
      title: event.title,
      description: event.description,
      categoryId: event.categoryId,
      existingImageUrls: event.imageUrls,
      venue: event.venue,
      venueRoom: event.venueRoom,
      startAt: event.startAt,
      endAt: event.endAt,
      visibility: event.visibility,
      isRegistrationRequired: event.isRegistrationRequired,
      registrationUrl: event.registrationUrl,
      maxCapacity: event.maxCapacity,
      isEditing: true,
      createdAt: event.createdAt,
    );
  }

  void updateTitle(String val) => state = state.copyWith(title: val);
  void updateDescription(String val) => state = state.copyWith(description: val);
  void updateCategory(String val) => state = state.copyWith(categoryId: val);
  void updateVenue(LocationData val) => state = state.copyWith(venue: val);
  void updateVenueRoom(String val) => state = state.copyWith(venueRoom: val);
  void updateStartAt(DateTime val) => state = state.copyWith(startAt: val);
  void updateEndAt(DateTime val) => state = state.copyWith(endAt: val);
  
  void toggleRegistration(bool val) => state = state.copyWith(isRegistrationRequired: val);
  void updateRegistrationUrl(String val) => state = state.copyWith(registrationUrl: val);
  void updateMaxCapacity(int? val) => state = state.copyWith(maxCapacity: val);

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

  void removeExistingImage(String url) {
    final current = List<String>.from(state.existingImageUrls);
    current.remove(url);
    state = state.copyWith(existingImageUrls: current);
  }

  void nextStep() {
    if (state.currentStep < 5) {
      state = state.copyWith(currentStep: state.currentStep + 1);
    }
  }

  void previousStep() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  Future<bool> saveAsDraft() async {
    return _save(EventStatus.draft);
  }

  Future<bool> submit() async {
    return _save(EventStatus.submitted);
  }

  Future<bool> _save(EventStatus status) async {
    if (state.title.isEmpty || state.startAt == null || state.endAt == null || state.venue == null) {
      state = state.copyWith(error: 'Please fill in required fields');
      return false;
    }

    // Validate dates
    if (state.startAt!.isBefore(DateTime.now())) {
      state = state.copyWith(error: 'Event cannot start in the past');
      return false;
    }

    if (state.endAt!.isBefore(state.startAt!)) {
      state = state.copyWith(error: 'Event must end after it starts');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = _ref.read(appUserProvider).valueOrNull;
      if (user == null) throw Exception('User not authenticated');

      // Upload images with individual error handling
      final storage = _ref.read(storageRepositoryProvider);
      final uploadedUrls = <String>[];
      final failedImages = <int>[];

      for (var i = 0; i < state.selectedImages.length; i++) {
        try {
          final url = await storage.uploadFile(
            path: 'events/${state.id}',
            id: 'img_${DateTime.now().millisecondsSinceEpoch}_$i',
            file: state.selectedImages[i],
          );
          uploadedUrls.add(url);
        } catch (e) {
          failedImages.add(i);
        }
      }

      // If critical images failed, abort
      if (failedImages.isNotEmpty && uploadedUrls.isEmpty && state.selectedImages.isNotEmpty) {
        state = state.copyWith(
          isLoading: false,
          error: 'Failed to upload event images (${failedImages.length}/${state.selectedImages.length} failed). Please try again.'
        );
        return false;
      }

      // If some images failed, warn user
      if (failedImages.isNotEmpty) {
        // Log warning but continue with successful uploads
        print('⚠️ WARNING: ${failedImages.length} images failed to upload, but ${uploadedUrls.length} succeeded.');
      }

      final imageUrls = [...state.existingImageUrls, ...uploadedUrls];

      // Defensive: Validate organizer exists and user has permission
      if (state.organizerId.isEmpty) {
        throw Exception('Organizer ID is required');
      }

      final event = Event(
        id: state.id,
        organizerId: state.organizerId,
        campusId: state.campusId,
        title: state.title.trim(),
        description: state.description.trim(),
        categoryId: state.categoryId,
        imageUrls: imageUrls,
        venue: state.venue!,
        venueRoom: state.venueRoom,
        startAt: state.startAt!,
        endAt: state.endAt!,
        status: status,
        visibility: state.visibility,
        isRegistrationRequired: state.isRegistrationRequired,
        registrationUrl: state.registrationUrl,
        maxCapacity: state.maxCapacity,
        createdAt: state.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
        createdBy: user.uid,
      );

      if (state.isEditing) {
        await _ref.read(eventServiceProvider).updateEvent(event, user.uid);
      } else {
        await _ref.read(eventServiceProvider).createEvent(event, user.uid);
      }

      if (status == EventStatus.submitted) {
        // This handles validation and notifying admins
        await _ref.read(eventServiceProvider).submitEvent(event.id, user.uid);
      }

      // We don't set isLoading to false here on success because the UI 
      // will either show a success dialog or navigate away. 
      // Keeping it true prevents double-submissions during transitions.
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final createEventControllerProvider =
    StateNotifierProvider.family<CreateEventController, CreateEventState, ({Event? event, String organizerId, String campusId})>((ref, args) {
  return CreateEventController(ref, initialEvent: args.event, organizerId: args.organizerId, campusId: args.campusId);
});
