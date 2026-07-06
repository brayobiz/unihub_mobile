import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/landmark.dart';
import '../models/campus.dart';
import '../models/map_marker.dart';
import '../repositories/landmark_repository.dart';
import '../repositories/campus_repository.dart';
import '../../../features/auth/shared/providers.dart';
import '../../../features/auth/domain/models/app_user.dart';
import '../../../features/events/domain/models/event.dart';
import '../../../features/events/domain/repositories/event_repository.dart';
import '../../../features/events/shared/providers.dart';
import '../utils/landmark_ui_utils.dart';

class CampusMapsState {
  final Campus? selectedCampus;
  final List<Campus> campuses;
  final List<Landmark> allLandmarks;
  final List<Landmark> filteredLandmarks;
  final List<Event> events;
  final Set<String> favoriteLandmarkIds;
  final List<String> recentLandmarkIds;
  final String searchQuery;
  final Set<LandmarkCategory> activeCategories;
  final bool isLoading;
  final String? error;
  final Landmark? selectedLandmark;
  final Event? selectedEvent;
  final bool favoritesOnly;
  final bool showEvents;

  CampusMapsState({
    this.selectedCampus,
    this.campuses = const <Campus>[],
    this.allLandmarks = const <Landmark>[],
    this.filteredLandmarks = const <Landmark>[],
    this.events = const <Event>[],
    this.favoriteLandmarkIds = const <String>{},
    this.recentLandmarkIds = const <String>[],
    this.searchQuery = '',
    this.activeCategories = const <LandmarkCategory>{},
    this.isLoading = false,
    this.error,
    this.selectedLandmark,
    this.selectedEvent,
    this.favoritesOnly = false,
    this.showEvents = true,
  });

  CampusMapsState copyWith({
    Campus? selectedCampus,
    List<Campus>? campuses,
    List<Landmark>? allLandmarks,
    List<Landmark>? filteredLandmarks,
    List<Event>? events,
    Set<String>? favoriteLandmarkIds,
    List<String>? recentLandmarkIds,
    String? searchQuery,
    Set<LandmarkCategory>? activeCategories,
    bool? isLoading,
    String? error,
    Landmark? selectedLandmark,
    Event? selectedEvent,
    bool? favoritesOnly,
    bool? showEvents,
    bool clearSelectedLandmark = false,
    bool clearSelectedEvent = false,
  }) {
    return CampusMapsState(
      selectedCampus: selectedCampus ?? this.selectedCampus,
      campuses: campuses ?? this.campuses,
      allLandmarks: allLandmarks ?? this.allLandmarks,
      filteredLandmarks: filteredLandmarks ?? this.filteredLandmarks,
      events: events ?? this.events,
      favoriteLandmarkIds: favoriteLandmarkIds ?? this.favoriteLandmarkIds,
      recentLandmarkIds: recentLandmarkIds ?? this.recentLandmarkIds,
      searchQuery: searchQuery ?? this.searchQuery,
      activeCategories: activeCategories ?? this.activeCategories,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? (isLoading == true ? null : this.error),
      selectedLandmark: clearSelectedLandmark ? null : (selectedLandmark ?? this.selectedLandmark),
      selectedEvent: clearSelectedEvent ? null : (selectedEvent ?? this.selectedEvent),
      favoritesOnly: favoritesOnly ?? this.favoritesOnly,
      showEvents: showEvents ?? this.showEvents,
    );
  }
}

class CampusMapsController extends StateNotifier<CampusMapsState> {
  final LandmarkRepository _landmarkRepository;
  final CampusRepository _campusRepository;
  final EventRepository _eventRepository;
  final SharedPreferences _prefs;
  final AppUser? _initialUser;
  static const String _favsKey = 'campus_map_favorites';
  static const String _recentKey = 'campus_map_recent';

  CampusMapsController(
    this._landmarkRepository,
    this._campusRepository,
    this._eventRepository,
    this._prefs,
    this._initialUser,
  ) : super(CampusMapsState()) {
    _init();
  }

  Future<void> _init() async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      // Load local storage
      final favs = _prefs.getStringList(_favsKey)?.toSet() ?? {};
      final recent = _prefs.getStringList(_recentKey) ?? [];
      
      // Load all campuses for the picker
      final allCampuses = await _campusRepository.getCampuses();
      
      state = state.copyWith(
        favoriteLandmarkIds: favs,
        recentLandmarkIds: recent,
        campuses: allCampuses,
      );

      // 1. User Preference: Use the provided user from the provider watch
      if (_initialUser?.university != null) {
        final userCampus = await _campusRepository.getCampusById(_initialUser!.university!);
        if (userCampus != null) {
          await selectCampus(userCampus);
          return;
        }
      }

      // 2. Smart Discovery: Try to find where the user is geographically
      final discoveredCampus = await _campusRepository.discoverNearestCampus();
      if (discoveredCampus != null) {
        await selectCampus(discoveredCampus);
        return;
      }

      // 3. Fallback: Use the first campus in the list
      if (allCampuses.isNotEmpty) {
        await selectCampus(allCampuses.first);
      } else {
        state = state.copyWith(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to initialize maps: ${e.toString()}',
      );
    }
  }

  Future<void> selectCampus(Campus campus) async {
    state = state.copyWith(
      selectedCampus: campus, 
      isLoading: true, 
      error: null,
      searchQuery: '', 
      activeCategories: {},
      favoritesOnly: false,
      clearSelectedLandmark: true,
      clearSelectedEvent: true,
    );
    
    try {
      final results = await Future.wait([
        _landmarkRepository.getLandmarks(campus.id),
        _eventRepository.watchEventsByCampus(campus.id, statuses: [EventStatus.approved, EventStatus.scheduled, EventStatus.live]).first,
      ]);

      state = state.copyWith(
        allLandmarks: results[0] as List<Landmark>,
        filteredLandmarks: results[0] as List<Landmark>,
        events: results[1] as List<Event>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load campus data: ${e.toString()}',
      );
    }
  }

  void toggleEvents(bool show) {
    state = state.copyWith(showEvents: show);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _applyFilters();
  }

  void toggleCategory(LandmarkCategory category) {
    final categories = Set<LandmarkCategory>.from(state.activeCategories);
    if (categories.contains(category)) {
      categories.remove(category);
    } else {
      categories.add(category);
    }
    state = state.copyWith(activeCategories: categories);
    _applyFilters();
  }

  void toggleFavoritesOnly() {
    state = state.copyWith(favoritesOnly: !state.favoritesOnly);
    _applyFilters();
  }

  void _applyFilters() {
    List<Landmark> filtered = state.allLandmarks;

    if (state.favoritesOnly) {
      filtered = filtered.where((l) => state.favoriteLandmarkIds.contains(l.id)).toList();
    }

    if (state.searchQuery.isNotEmpty) {
      final query = state.searchQuery.toLowerCase();
      filtered = filtered.where((l) =>
          l.name.toLowerCase().contains(query) ||
          l.description.toLowerCase().contains(query)).toList();
    }

    if (state.activeCategories.isNotEmpty) {
      filtered = filtered.where((l) => state.activeCategories.contains(l.category)).toList();
    }

    state = state.copyWith(filteredLandmarks: filtered);
  }

  Future<void> selectLandmark(Landmark? landmark) async {
    state = state.copyWith(
      selectedLandmark: landmark,
      clearSelectedEvent: true,
    );
    if (landmark != null) {
      _addToRecent(landmark.id);
    }
  }

  void selectEvent(Event? event) {
    state = state.copyWith(
      selectedEvent: event,
      clearSelectedLandmark: true,
    );
  }

  void _addToRecent(String id) async {
    final recent = List<String>.from(state.recentLandmarkIds);
    recent.remove(id);
    recent.insert(0, id);
    if (recent.length > 10) recent.removeLast();
    
    state = state.copyWith(recentLandmarkIds: recent);
    await _prefs.setStringList(_recentKey, recent);
  }

  Future<void> toggleFavorite(String landmarkId) async {
    final favorites = Set<String>.from(state.favoriteLandmarkIds);
    if (favorites.contains(landmarkId)) {
      favorites.remove(landmarkId);
    } else {
      favorites.add(landmarkId);
    }
    state = state.copyWith(favoriteLandmarkIds: favorites);
    
    await _prefs.setStringList(_favsKey, favorites.toList());
  }

  bool isFavorite(String landmarkId) {
    return state.favoriteLandmarkIds.contains(landmarkId);
  }

  List<Landmark> getRecentLandmarks() {
    return state.recentLandmarkIds
        .map((id) => state.allLandmarks.where((l) => l.id == id).firstOrNull)
        .whereType<Landmark>()
        .toList();
  }
}

final campusMapsControllerProvider =
    StateNotifierProvider<CampusMapsController, CampusMapsState>((ref) {
  final landmarkRepo = ref.watch(landmarkRepositoryProvider);
  final campusRepo = ref.watch(campusRepositoryProvider);
  final eventRepo = ref.watch(eventRepositoryProvider);
  final prefs = ref.watch(sharedPreferencesProvider);
  final userAsync = ref.watch(appUserProvider);
  return CampusMapsController(landmarkRepo, campusRepo, eventRepo, prefs, userAsync.valueOrNull);
});

final campusMapMarkersProvider = Provider<List<MapMarker>>((ref) {
  final state = ref.watch(campusMapsControllerProvider);
  
  final List<MapMarker> markers = [];
  
  // 1. Landmarks
  markers.addAll(state.filteredLandmarks.map((l) => MapMarker(
    id: l.id,
    title: l.name,
    subtitle: LandmarkUIUtils.getLabel(l.category),
    latitude: l.latitude,
    longitude: l.longitude,
    markerType: _mapToMarkerType(l.category),
    payload: l,
  )));

  // 2. Events (if layer active)
  if (state.showEvents) {
    markers.addAll(state.events.map((e) => MapMarker(
      id: e.id,
      title: e.title,
      subtitle: 'Event',
      latitude: e.venue.latitude,
      longitude: e.venue.longitude,
      markerType: MarkerType.event,
      payload: e,
    )));
  }

  return markers;
});

MarkerType _mapToMarkerType(LandmarkCategory category) {
  switch (category) {
    case LandmarkCategory.accommodation:
      return MarkerType.housing;
    default:
      return MarkerType.campus;
  }
}
