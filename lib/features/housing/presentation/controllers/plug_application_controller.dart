import 'package:flutter_riverpod/flutter_riverpod.dart';

class PlugApplicationState {
  final int currentStep;
  final String intro;
  final String? selectedCampus;
  final List<String> serviceAreas;
  final List<String> specialties;
  final String availability; // e.g. "Available", "Unavailable"
  final String preferredContact; // e.g. "In-App Chat", "WhatsApp"
  final String additionalInfo;

  PlugApplicationState({
    this.currentStep = 0,
    this.intro = '',
    this.selectedCampus,
    this.serviceAreas = const [],
    this.specialties = const [],
    this.availability = 'Available',
    this.preferredContact = 'In-App Chat',
    this.additionalInfo = '',
  });

  PlugApplicationState copyWith({
    int? currentStep,
    String? intro,
    String? selectedCampus,
    List<String>? serviceAreas,
    List<String>? specialties,
    String? availability,
    String? preferredContact,
    String? additionalInfo,
  }) {
    return PlugApplicationState(
      currentStep: currentStep ?? this.currentStep,
      intro: intro ?? this.intro,
      selectedCampus: selectedCampus ?? this.selectedCampus,
      serviceAreas: serviceAreas ?? this.serviceAreas,
      specialties: specialties ?? this.specialties,
      availability: availability ?? this.availability,
      preferredContact: preferredContact ?? this.preferredContact,
      additionalInfo: additionalInfo ?? this.additionalInfo,
    );
  }
}

class PlugApplicationController extends StateNotifier<PlugApplicationState> {
  PlugApplicationController() : super(PlugApplicationState());

  void updateStep(int step) => state = state.copyWith(currentStep: step);
  
  void updateBasicInfo({
    String? intro,
    String? campus,
    String? contact,
  }) {
    state = state.copyWith(
      intro: intro,
      selectedCampus: campus,
      preferredContact: contact,
    );
  }

  void updateServiceDetails({
    List<String>? areas,
    String? availability,
    List<String>? specialties,
    String? additionalInfo,
  }) {
    state = state.copyWith(
      serviceAreas: areas,
      availability: availability,
      specialties: specialties,
      additionalInfo: additionalInfo,
    );
  }

  void toggleArea(String area) {
    final areas = List<String>.from(state.serviceAreas);
    if (areas.contains(area)) {
      areas.remove(area);
    } else {
      areas.add(area);
    }
    state = state.copyWith(serviceAreas: areas);
  }

  void toggleSpecialty(String specialty) {
    final specialties = List<String>.from(state.specialties);
    if (specialties.contains(specialty)) {
      specialties.remove(specialty);
    } else {
      specialties.add(specialty);
    }
    state = state.copyWith(specialties: specialties);
  }

  void setAvailability(String val) => state = state.copyWith(availability: val);
  void setPreferredContact(String val) => state = state.copyWith(preferredContact: val);

  void reset() => state = PlugApplicationState();
}

final plugApplicationControllerProvider =
    StateNotifierProvider<PlugApplicationController, PlugApplicationState>((ref) {
  return PlugApplicationController();
});
