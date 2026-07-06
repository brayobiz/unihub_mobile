import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/location_data.dart';
import 'location_service.dart';

final nearbyServiceProvider = Provider((ref) {
  final locationService = ref.watch(locationServiceProvider);
  return NearbyService(locationService);
});

class NearbyService {
  final LocationService _locationService;

  NearbyService(this._locationService);

  double calculateDistance(double lat1, double lng1, double lat2, double lng2) {
    return _locationService.calculateDistance(lat1, lng1, lat2, lng2);
  }

  List<T> sortByDistance<T>(
    LocationData currentPosition,
    List<T> items,
    double Function(T) getLat,
    double Function(T) getLng,
  ) {
    final List<T> sortedList = List.from(items);
    sortedList.sort((a, b) {
      final distanceA = calculateDistance(
        currentPosition.latitude,
        currentPosition.longitude,
        getLat(a),
        getLng(a),
      );
      final distanceB = calculateDistance(
        currentPosition.latitude,
        currentPosition.longitude,
        getLat(b),
        getLng(b),
      );
      return distanceA.compareTo(distanceB);
    });
    return sortedList;
  }

  List<T> filterWithinRadius<T>(
    LocationData currentPosition,
    List<T> items,
    double radiusInKm,
    double Function(T) getLat,
    double Function(T) getLng,
  ) {
    return items.where((item) {
      final distance = calculateDistance(
        currentPosition.latitude,
        currentPosition.longitude,
        getLat(item),
        getLng(item),
      );
      return distance <= radiusInKm;
    }).toList();
  }
}
