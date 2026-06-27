import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlugApplicationState {
  final int currentStep;
  final String fullName;
  final String phoneNumber;
  final String? selectedCampus;
  final String intro;
  final String areasServed;
  final String hasExperience;
  final String experienceCount;
  final String? idDocumentPath;
  final String? profilePhotoPath;

  PlugApplicationState({
    this.currentStep = 0,
    this.fullName = '',
    this.phoneNumber = '',
    this.selectedCampus,
    this.intro = '',
    this.areasServed = '',
    this.hasExperience = 'No',
    this.experienceCount = '',
    this.idDocumentPath,
    this.profilePhotoPath,
  });

  PlugApplicationState copyWith({
    int? currentStep,
    String? fullName,
    String? phoneNumber,
    String? selectedCampus,
    String? intro,
    String? areasServed,
    String? hasExperience,
    String? experienceCount,
    String? idDocumentPath,
    String? profilePhotoPath,
  }) {
    return PlugApplicationState(
      currentStep: currentStep ?? this.currentStep,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      selectedCampus: selectedCampus ?? this.selectedCampus,
      intro: intro ?? this.intro,
      areasServed: areasServed ?? this.areasServed,
      hasExperience: hasExperience ?? this.hasExperience,
      experienceCount: experienceCount ?? this.experienceCount,
      idDocumentPath: idDocumentPath ?? this.idDocumentPath,
      profilePhotoPath: profilePhotoPath ?? this.profilePhotoPath,
    );
  }
}

class PlugApplicationController extends StateNotifier<PlugApplicationState> {
  PlugApplicationController() : super(PlugApplicationState());

  void updateStep(int step) => state = state.copyWith(currentStep: step);
  
  void updatePersonal({
    String? fullName,
    String? phoneNumber,
    String? campus,
  }) {
    state = state.copyWith(
      fullName: fullName,
      phoneNumber: phoneNumber,
      selectedCampus: campus,
    );
  }

  void updateProfessional({
    String? intro,
    String? areas,
  }) {
    state = state.copyWith(
      intro: intro,
      areasServed: areas,
    );
  }

  void updateExperience({
    String? hasExperience,
    String? count,
  }) {
    state = state.copyWith(
      hasExperience: hasExperience,
      experienceCount: count,
    );
  }

  void updateIdDocument(String? path) => state = state.copyWith(idDocumentPath: path);
  void updateProfilePhoto(String? path) => state = state.copyWith(profilePhotoPath: path);

  void reset() => state = PlugApplicationState();
}

final plugApplicationControllerProvider =
    StateNotifierProvider<PlugApplicationController, PlugApplicationState>((ref) {
  return PlugApplicationController();
});
