import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlugApplicationState {
  final int currentStep;
  final String intro;
  final String? selectedCampus;
  final String areasServed;
  final String hasExperience;
  final String experienceLevel; // e.g. "Newcomer", "1-2 years", "3+ years"
  final String additionalInfo;

  PlugApplicationState({
    this.currentStep = 0,
    this.intro = '',
    this.selectedCampus,
    this.areasServed = '',
    this.hasExperience = 'No',
    this.experienceLevel = 'Newcomer',
    this.additionalInfo = '',
  });

  PlugApplicationState copyWith({
    int? currentStep,
    String? intro,
    String? selectedCampus,
    String? areasServed,
    String? hasExperience,
    String? experienceLevel,
    String? additionalInfo,
  }) {
    return PlugApplicationState(
      currentStep: currentStep ?? this.currentStep,
      intro: intro ?? this.intro,
      selectedCampus: selectedCampus ?? this.selectedCampus,
      areasServed: areasServed ?? this.areasServed,
      hasExperience: hasExperience ?? this.hasExperience,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      additionalInfo: additionalInfo ?? this.additionalInfo,
    );
  }
}

class PlugApplicationController extends StateNotifier<PlugApplicationState> {
  PlugApplicationController() : super(PlugApplicationState());

  void updateStep(int step) => state = state.copyWith(currentStep: step);
  
  void updateProfessional({
    String? intro,
    String? campus,
    String? areas,
  }) {
    state = state.copyWith(
      intro: intro,
      selectedCampus: campus,
      areasServed: areas,
    );
  }

  void updateExperience({
    String? hasExperience,
    String? level,
    String? additionalInfo,
  }) {
    state = state.copyWith(
      hasExperience: hasExperience,
      experienceLevel: level,
      additionalInfo: additionalInfo,
    );
  }

  void reset() => state = PlugApplicationState();
}

final plugApplicationControllerProvider =
    StateNotifierProvider<PlugApplicationController, PlugApplicationState>((ref) {
  return PlugApplicationController();
});
