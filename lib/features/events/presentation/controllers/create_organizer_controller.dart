import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/organizer.dart';
import '../../shared/providers.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/shared/storage_repository.dart';

class CreateOrganizerState {
  final String id;
  final String name;
  final String bio;
  final String campusId;
  final OrganizerType type;
  final File? logoFile;
  final String? logoUrl;
  final File? bannerFile;
  final String? bannerUrl;
  final String contactEmail;
  final String contactPhone;
  final Map<String, String> socialLinks;
  
  final bool isLoading;
  final String? error;
  final bool isEditing;

  CreateOrganizerState({
    required this.id,
    this.name = '',
    this.bio = '',
    this.campusId = '',
    this.type = OrganizerType.student,
    this.logoFile,
    this.logoUrl,
    this.bannerFile,
    this.bannerUrl,
    this.contactEmail = '',
    this.contactPhone = '',
    this.socialLinks = const {},
    this.isLoading = false,
    this.error,
    this.isEditing = false,
  });

  CreateOrganizerState copyWith({
    String? name,
    String? bio,
    String? campusId,
    OrganizerType? type,
    File? logoFile,
    String? logoUrl,
    File? bannerFile,
    String? bannerUrl,
    String? contactEmail,
    String? contactPhone,
    Map<String, String>? socialLinks,
    bool? isLoading,
    String? error,
    bool? isEditing,
  }) {
    return CreateOrganizerState(
      id: id,
      name: name ?? this.name,
      bio: bio ?? this.bio,
      campusId: campusId ?? this.campusId,
      type: type ?? this.type,
      logoFile: logoFile ?? this.logoFile,
      logoUrl: logoUrl ?? this.logoUrl,
      bannerFile: bannerFile ?? this.bannerFile,
      bannerUrl: bannerUrl ?? this.bannerUrl,
      contactEmail: contactEmail ?? this.contactEmail,
      contactPhone: contactPhone ?? this.contactPhone,
      socialLinks: socialLinks ?? this.socialLinks,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      isEditing: isEditing ?? this.isEditing,
    );
  }
}

class CreateOrganizerController extends StateNotifier<CreateOrganizerState> {
  final Ref _ref;

  CreateOrganizerController(this._ref, Organizer? initialOrganizer)
      : super(_createInitialState(_ref, initialOrganizer));

  static CreateOrganizerState _createInitialState(Ref ref, Organizer? organizer) {
    if (organizer == null) {
      final user = ref.read(appUserProvider).valueOrNull;
      return CreateOrganizerState(
        id: const Uuid().v4(),
        campusId: user?.university ?? '',
      );
    }
    return CreateOrganizerState(
      id: organizer.id,
      name: organizer.name,
      bio: organizer.bio,
      campusId: organizer.campusId,
      type: organizer.type,
      logoUrl: organizer.logoUrl,
      bannerUrl: organizer.bannerUrl,
      contactEmail: organizer.contactEmail ?? '',
      contactPhone: organizer.contactPhone ?? '',
      socialLinks: organizer.socialLinks,
      isEditing: true,
    );
  }

  void updateName(String val) => state = state.copyWith(name: val, error: null);
  void updateBio(String val) => state = state.copyWith(bio: val, error: null);
  void updateType(OrganizerType val) => state = state.copyWith(type: val, error: null);
  void updateCampus(String val) => state = state.copyWith(campusId: val, error: null);
  void updateContactEmail(String val) => state = state.copyWith(contactEmail: val, error: null);
  void updateContactPhone(String val) => state = state.copyWith(contactPhone: val, error: null);

  void updateLogo(File file) => state = state.copyWith(logoFile: file, error: null);
  void updateBanner(File file) => state = state.copyWith(bannerFile: file, error: null);

  Future<void> pickLogo() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
      if (image != null) {
        state = state.copyWith(logoFile: File(image.path), error: null);
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to pick logo');
    }
  }

  Future<void> pickBanner() async {
    try {
      final picker = ImagePicker();
      final image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
      if (image != null) {
        state = state.copyWith(bannerFile: File(image.path), error: null);
      }
    } catch (e) {
      state = state.copyWith(error: 'Failed to pick banner');
    }
  }

  bool validateStep(int step) {
    if (step == 0) {
      if (state.name.trim().isEmpty) {
        state = state.copyWith(error: 'Organizer Name is required');
        return false;
      }
      if (state.campusId.isEmpty) {
        state = state.copyWith(error: 'Target Campus is required');
        return false;
      }
      if (state.bio.trim().isEmpty) {
        state = state.copyWith(error: 'A short bio is required');
        return false;
      }
      if (state.bio.length < 20) {
        state = state.copyWith(error: 'Bio should be at least 20 characters');
        return false;
      }
    }
    
    if (step == 1) {
      if (state.logoFile == null && state.logoUrl == null) {
        if (state.type != OrganizerType.student) {
          state = state.copyWith(error: 'Official organizations must upload a logo');
          return false;
        }
      }
    }

    state = state.copyWith(error: null);
    return true;
  }

  void updateSocialLink(String platform, String url) {
    final newLinks = Map<String, String>.from(state.socialLinks);
    if (url.isEmpty) {
      newLinks.remove(platform);
    } else {
      newLinks[platform] = url;
    }
    state = state.copyWith(socialLinks: newLinks);
  }

  Future<bool> submit() async {
    if (state.name.isEmpty || state.bio.isEmpty || state.campusId.isEmpty) {
      state = state.copyWith(error: 'Please fill in all required fields');
      return false;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final user = _ref.read(appUserProvider).valueOrNull;
      if (user == null) throw Exception('User not authenticated');

      String? logoUrl = state.logoUrl;
      if (state.logoFile != null) {
        logoUrl = await _ref.read(storageRepositoryProvider).uploadFile(
          path: 'organizers/${state.id}',
          id: 'logo',
          file: state.logoFile!,
        );
      }

      String? bannerUrl = state.bannerUrl;
      if (state.bannerFile != null) {
        bannerUrl = await _ref.read(storageRepositoryProvider).uploadFile(
          path: 'organizers/${state.id}',
          id: 'banner',
          file: state.bannerFile!,
        );
      }

      final organizer = Organizer(
        id: state.id,
        ownerId: user.uid,
        name: state.name,
        bio: state.bio,
        logoUrl: logoUrl,
        bannerUrl: bannerUrl,
        campusId: state.campusId,
        type: state.type,
        contactEmail: state.contactEmail.isEmpty ? null : state.contactEmail,
        contactPhone: state.contactPhone.isEmpty ? null : state.contactPhone,
        socialLinks: state.socialLinks,
        createdAt: state.isEditing 
            ? (_ref.read(organizerProvider(state.id)).value?.createdAt ?? DateTime.now())
            : DateTime.now(),
        updatedAt: DateTime.now(),
      );

      if (state.isEditing) {
        await _ref.read(organizerRepositoryProvider).updateOrganizer(organizer);
        
        // If it was rejected, move it back to underReview upon edit
        final current = _ref.read(organizerProvider(state.id)).value;
        if (current?.verificationStatus == OrganizerVerificationStatus.rejected) {
          await _ref.read(organizerServiceProvider).submitForReview(organizer.id, user.uid);
        }
      } else {
        await _ref.read(organizerServiceProvider).createApplication(organizer, user.uid);
      }

      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }
}

final createOrganizerControllerProvider =
    StateNotifierProvider.family<CreateOrganizerController, CreateOrganizerState, Organizer?>((ref, organizer) {
  return CreateOrganizerController(ref, organizer);
});
