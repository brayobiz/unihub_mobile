import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../models/location_data.dart';
import 'campus_map.dart';

class LocationPicker extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String title;
  final String confirmLabel;

  const LocationPicker({
    super.key,
    this.initialLat,
    this.initialLng,
    this.title = 'Select Location',
    this.confirmLabel = 'Confirm',
  });

  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  late final ValueNotifier<LatLng> _currentLocation;
  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    _currentLocation = ValueNotifier(LatLng(
      widget.initialLat ?? -1.2801,
      widget.initialLng ?? 36.8163,
    ));
  }

  @override
  void dispose() {
    _mapController.dispose();
    _currentLocation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  LocationData(
                    latitude: _currentLocation.value.latitude,
                    longitude: _currentLocation.value.longitude,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(widget.confirmLabel),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          CampusMap(
            mapController: _mapController,
            initialLatitude: _currentLocation.value.latitude,
            initialLongitude: _currentLocation.value.longitude,
            onCameraMove: (lat, lng) {
              // Update value without triggering full screen build
              _currentLocation.value = LatLng(lat, lng);
            },
          ),
          
          // Fixed crosshair/pin in the center of the map
          IgnorePointer(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40), // Align pin tip to center
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<LatLng>(
                      valueListenable: _currentLocation,
                      builder: (context, location, child) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4),
                            ],
                          ),
                          child: const Text(
                            'Move map to pick',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }
                    ),
                    Icon(
                      Icons.location_on,
                      size: 48,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          Positioned(
            bottom: 24,
            right: 16,
            child: FloatingActionButton(
              heroTag: 'picker_my_location',
              onPressed: () async {
                final loc = await geo.Geolocator.getCurrentPosition();
                _mapController.move(LatLng(loc.latitude, loc.longitude), 16);
                _currentLocation.value = LatLng(loc.latitude, loc.longitude);
              },
              child: const Icon(Icons.my_location),
            ),
          ),
        ],
      ),
    );
  }
}
