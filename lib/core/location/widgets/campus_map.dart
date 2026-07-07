import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/map_marker.dart';

class CampusMap extends StatefulWidget {
  final double initialLatitude;
  final double initialLongitude;
  final double initialZoom;
  final List<MapMarker> markers;
  final bool showUserLocation;
  final Function(MapMarker)? onMarkerTap;
  final Function(double lat, double lng)? onCameraMove;
  final MapController? mapController;

  const CampusMap({
    super.key,
    required this.initialLatitude,
    required this.initialLongitude,
    this.initialZoom = 15.0,
    this.markers = const [],
    this.showUserLocation = true,
    this.onMarkerTap,
    this.onCameraMove,
    this.mapController,
  });

  @override
  State<CampusMap> createState() => _CampusMapState();
}

class _CampusMapState extends State<CampusMap> {
  late final MapController _internalController;

  MapController get _mapController => widget.mapController ?? _internalController;

  @override
  void initState() {
    super.initState();
    _internalController = MapController();
  }

  @override
  void didUpdateWidget(CampusMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the initial coordinates changed significantly, move the camera
    if (widget.initialLatitude != oldWidget.initialLatitude ||
        widget.initialLongitude != oldWidget.initialLongitude) {
      _mapController.move(
        LatLng(widget.initialLatitude, widget.initialLongitude),
        widget.initialZoom,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: LatLng(widget.initialLatitude, widget.initialLongitude),
        initialZoom: widget.initialZoom,
        onPositionChanged: (position, hasGesture) {
          if (hasGesture && widget.onCameraMove != null && position.center != null) {
            widget.onCameraMove!(
              position.center!.latitude,
              position.center!.longitude,
            );
          }
        },
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.unihub.unihub_mobile',
        ),
        MarkerLayer(
          markers: widget.markers.map((marker) {
            return Marker(
              point: LatLng(marker.latitude, marker.longitude),
              width: 120,
              height: 60,
              alignment: const Alignment(0, 0.2),
              child: GestureDetector(
                onTap: () => widget.onMarkerTap?.call(marker),
                child: _buildMarkerWidget(marker),
              ),
            );
          }).toList(),
        ),
        if (widget.showUserLocation)
          MarkerLayer(
            markers: [
              // This is a placeholder for actual user location marker
              // In a real scenario, you'd watch a location provider
            ],
          ),
      ],
    );
  }

  Widget _buildMarkerWidget(MapMarker marker) {
    final color = _getMarkerColor(marker.markerType);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Icon(Icons.location_on, color: color, size: 36),
            Positioned(
              top: 5,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _getMarkerIcon(marker.markerType),
                  size: 12,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Text(
            marker.title,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Color _getMarkerColor(MarkerType type) {
    switch (type) {
      case MarkerType.housing:
        return Colors.orange;
      case MarkerType.marketplace:
        return Colors.blue;
      case MarkerType.event:
        return Colors.purple;
      case MarkerType.campus:
        return Colors.red;
      case MarkerType.generic:
        return Colors.grey;
    }
  }

  IconData _getMarkerIcon(MarkerType type) {
    switch (type) {
      case MarkerType.housing:
        return Icons.home_rounded;
      case MarkerType.marketplace:
        return Icons.shopping_bag_rounded;
      case MarkerType.event:
        return Icons.event_rounded;
      case MarkerType.campus:
        return Icons.school_rounded;
      case MarkerType.generic:
        return Icons.location_on_rounded;
    }
  }
}
