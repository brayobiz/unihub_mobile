import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'dart:math' as math;
import '../models/location_data.dart';

final locationServiceProvider = Provider((ref) => LocationService());

class LocationService {
  Future<bool> isLocationServiceEnabled() async {
    return await geo.Geolocator.isLocationServiceEnabled();
  }

  Future<PermissionStatus> checkPermission() async {
    return await Permission.location.status;
  }

  Future<PermissionStatus> requestPermission() async {
    return await Permission.location.request();
  }

  Future<LocationData?> getCurrentLocation() async {
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      return LocationData(
        latitude: position.latitude,
        longitude: position.longitude,
      );
    } catch (e) {
      return null;
    }
  }

  double calculateDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    const double p = 0.017453292519943295;
    final double a = 0.5 -
        math.cos((endLat - startLat) * p) / 2 +
        math.cos(startLat * p) *
            math.cos(endLat * p) *
            (1 - math.cos((endLng - startLng) * p)) /
            2;
    return 12742 * math.asin(math.sqrt(a)); // returns distance in km
  }
}
