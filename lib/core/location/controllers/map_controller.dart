import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/map_marker.dart';

class MapState {
  final double latitude;
  final double longitude;
  final double zoom;
  final List<MapMarker> markers;
  final MapMarker? selectedMarker;
  final bool isLoading;
  final bool showUserLocation;

  MapState({
    required this.latitude,
    required this.longitude,
    this.zoom = 15.0,
    this.markers = const [],
    this.selectedMarker,
    this.isLoading = false,
    this.showUserLocation = true,
  });

  MapState copyWith({
    double? latitude,
    double? longitude,
    double? zoom,
    List<MapMarker>? markers,
    MapMarker? selectedMarker,
    bool? isLoading,
    bool? showUserLocation,
  }) {
    return MapState(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      zoom: zoom ?? this.zoom,
      markers: markers ?? this.markers,
      selectedMarker: selectedMarker ?? this.selectedMarker,
      isLoading: isLoading ?? this.isLoading,
      showUserLocation: showUserLocation ?? this.showUserLocation,
    );
  }
}

class MapController extends StateNotifier<MapState> {
  MapController()
      : super(MapState(
          latitude: -1.2801, // Default to Nairobi
          longitude: 36.8163,
        ));

  void updateCamera(double lat, double lng, {double? zoom}) {
    state = state.copyWith(
      latitude: lat,
      longitude: lng,
      zoom: zoom ?? state.zoom,
    );
  }

  void setMarkers(List<MapMarker> markers) {
    state = state.copyWith(markers: markers);
  }

  void selectMarker(MapMarker? marker) {
    if (marker == null) {
      state = state.copyWith(selectedMarker: null);
      return;
    }
    state = state.copyWith(
      selectedMarker: marker,
      latitude: marker.latitude,
      longitude: marker.longitude,
    );
  }

  void toggleUserLocation(bool show) {
    state = state.copyWith(showUserLocation: show);
  }

  void setLoading(bool loading) {
    state = state.copyWith(isLoading: loading);
  }
}

final mapControllerProvider =
    StateNotifierProvider.family<MapController, MapState, String>((ref, mapId) {
  return MapController();
});
