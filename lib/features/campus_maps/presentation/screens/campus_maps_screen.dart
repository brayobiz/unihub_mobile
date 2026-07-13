import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:unihub_mobile/features/chat/domain/models/chat_context.dart';
import '../../../../core/location/controllers/campus_maps_controller.dart';
import '../../../../core/location/models/landmark.dart';
import '../../../../core/location/models/map_marker.dart';
import '../../../../core/location/widgets/campus_map.dart';
import '../../../../core/location/widgets/map_bottom_sheet.dart';
import '../../../../core/location/utils/landmark_ui_utils.dart';
import '../../../../core/location/repositories/campus_repository.dart';
import '../../../../core/location/models/campus.dart';
import '../../../../core/location/services/location_service.dart';
import '../../../../core/utils/permission_utils.dart';
import '../../../events/domain/models/event.dart';

class CampusMapsScreen extends ConsumerStatefulWidget {
  final String? initialEventId;
  const CampusMapsScreen({super.key, this.initialEventId});

  @override
  ConsumerState<CampusMapsScreen> createState() => _CampusMapsScreenState();
}

class _CampusMapsScreenState extends ConsumerState<CampusMapsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MapController _mapController = MapController();
  bool _showLegend = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialEventId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _selectInitialEvent();
      });
    }
  }

  Future<void> _selectInitialEvent() async {
    // Wait for data to be loaded
    int retries = 0;
    while (mounted && ref.read(campusMapsControllerProvider).isLoading && retries < 20) {
      await Future.delayed(const Duration(milliseconds: 500));
      retries++;
    }

    if (!mounted) return;

    final state = ref.read(campusMapsControllerProvider);
    final event = state.events.where((e) => e.id == widget.initialEventId).firstOrNull;
    if (event != null) {
      ref.read(campusMapsControllerProvider.notifier).selectEvent(event);
      _moveToEvent(event);
      _showEventDetails(context, event);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _recenter() async {
    final campus = ref.read(campusMapsControllerProvider).selectedCampus;
    final locationService = ref.read(locationServiceProvider);
    
    // Policy Compliance: Use prominent disclosure before requesting location
    final granted = await PermissionUtils.requestLocationPermission(context);
    
    if (granted) {
      final userLoc = await locationService.getCurrentLocation();
      if (userLoc != null) {
        _mapController.move(LatLng(userLoc.latitude, userLoc.longitude), 16.0);
        return;
      }
    } else {
      final status = await Permission.location.status;
      if (status.isPermanentlyDenied && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Location permission is required to show your position'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
    }

    if (campus != null) {
      _mapController.move(LatLng(campus.latitude, campus.longitude), campus.defaultZoom);
    }
  }

  void _moveToLandmark(Landmark landmark) {
    _mapController.move(LatLng(landmark.latitude, landmark.longitude), 17.0);
  }

  void _moveToEvent(Event event) {
    _mapController.move(LatLng(event.venue.latitude, event.venue.longitude), 17.0);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(campusMapsControllerProvider);
    final markers = ref.watch(campusMapMarkersProvider);
    final theme = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // The Map
          if (state.selectedCampus != null)
            CampusMap(
              mapController: _mapController,
              initialLatitude: state.selectedCampus!.latitude,
              initialLongitude: state.selectedCampus!.longitude,
              initialZoom: state.selectedCampus!.defaultZoom,
              markers: markers,
              onMarkerTap: (marker) {
                if (marker.markerType == MarkerType.event) {
                  final event = marker.payload as Event;
                  ref.read(campusMapsControllerProvider.notifier).selectEvent(event);
                  _moveToEvent(event);
                  _showEventDetails(context, event);
                } else {
                  final landmark = marker.payload as Landmark;
                  ref.read(campusMapsControllerProvider.notifier).selectLandmark(landmark);
                  _moveToLandmark(landmark);
                  _showLandmarkDetails(context, landmark);
                }
              },
            )
          else if (!state.isLoading && state.error == null)
            const Center(child: Text('No campus selected')),

          // UI Overlays
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Material(
              color: Colors.transparent,
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(context, ref, state),
                  ],
                ),
              ),
            ),
          ),

          // Map Control Buttons
          Positioned(
            right: 16,
            bottom: 120,
            child: Semantics(
              label: 'Map Controls',
              child: Column(
                children: [
                  _mapActionButton(
                    icon: Icons.layers_outlined,
                    onPressed: () => setState(() => _showLegend = !_showLegend),
                    active: _showLegend,
                    tooltip: 'Toggle Legend',
                  ),
                  const SizedBox(height: 12),
                  _mapActionButton(
                    icon: Icons.my_location,
                    onPressed: _recenter,
                    tooltip: 'Recenter to my location',
                  ),
                ],
              ),
            ),
          ),

          // Legend
          if (_showLegend)
            Positioned(
              right: 70,
              bottom: 160,
              child: _buildLegend(theme),
            ),

          // Recently Visited FAB-like list
          if (!state.isLoading && state.searchQuery.isEmpty && state.error == null)
            Positioned(
              left: 16,
              bottom: 24,
              child: _buildRecentPlaces(ref, state),
            ),
            
          // Loading Indicator
          if (state.isLoading)
            _buildLoadingOverlay(),

          // Error Indicator
          if (state.error != null)
            _buildErrorOverlay(state.error!),
        ],
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withOpacity(0.1),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: const Text('Discovering your campus...', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorOverlay(String error) {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(32),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text('Oops!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => ref.read(campusMapsControllerProvider.notifier).selectCampus(ref.read(campusMapsControllerProvider).selectedCampus ?? ref.read(campusMapsControllerProvider).campuses.first),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapActionButton({required IconData icon, required VoidCallback onPressed, bool active = false, String? tooltip}) {
    final theme = Theme.of(context);
    return FloatingActionButton.small(
      heroTag: null,
      onPressed: onPressed,
      tooltip: tooltip,
      backgroundColor: active ? theme.colorScheme.primary : theme.colorScheme.surface,
      foregroundColor: active ? theme.colorScheme.onPrimary : theme.colorScheme.onSurface,
      child: Icon(icon),
    );
  }

  Widget _buildHeader(BuildContext context, WidgetRef ref, CampusMapsState state) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.pop(context),
            style: IconButton.styleFrom(backgroundColor: theme.colorScheme.surface),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (val) => ref.read(campusMapsControllerProvider.notifier).setSearchQuery(val),
                decoration: InputDecoration(
                  hintText: 'Search library, hall, food...',
                  prefixIcon: const Icon(Icons.search),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  suffixIcon: _searchController.text.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          ref.read(campusMapsControllerProvider.notifier).setSearchQuery('');
                        },
                      )
                    : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          _buildCampusSelector(context, ref, state),
        ],
      ),
    );
  }

  Widget _buildCampusSelector(BuildContext context, WidgetRef ref, CampusMapsState state) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _showCampusPicker(context, ref),
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.3), blurRadius: 8)],
        ),
        child: Center(
          child: Text(
            state.selectedCampus?.shortName ?? '...',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }


  Widget _buildRecentPlaces(WidgetRef ref, CampusMapsState state) {
    final recent = ref.read(campusMapsControllerProvider.notifier).getRecentLandmarks();
    if (recent.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('RECENT PLACES', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            shrinkWrap: true,
            itemCount: recent.length,
            itemBuilder: (context, index) {
              final landmark = recent[index];
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  label: Text(landmark.name, style: const TextStyle(fontSize: 12)),
                  onPressed: () {
                    ref.read(campusMapsControllerProvider.notifier).selectLandmark(landmark);
                    _showLandmarkDetails(context, landmark);
                  },
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(ThemeData theme) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Map Legend', style: TextStyle(fontWeight: FontWeight.bold)),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.event_rounded, size: 16, color: Colors.purple),
                const SizedBox(width: 8),
                const Text('Events', style: TextStyle(fontSize: 12)),
              ],
            ),
          ),
          ...LandmarkCategory.values.map((cat) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(LandmarkUIUtils.getIcon(cat), size: 16, color: LandmarkUIUtils.getColor(cat)),
                const SizedBox(width: 8),
                Text(LandmarkUIUtils.getLabel(cat), style: const TextStyle(fontSize: 12)),
              ],
            ),
          )),
        ],
      ),
    );
  }

  void _showLandmarkDetails(BuildContext context, Landmark landmark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => MapBottomSheet(
        child: Column(
          children: [
            if (landmark.photos.isNotEmpty)
              Image.network(landmark.photos.first, height: 200, width: double.infinity, fit: BoxFit.cover),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(landmark.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: LandmarkUIUtils.getColor(landmark.category).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(LandmarkUIUtils.getIcon(landmark.category), size: 14, color: LandmarkUIUtils.getColor(landmark.category)),
                                  const SizedBox(width: 6),
                                  Text(LandmarkUIUtils.getLabel(landmark.category), style: TextStyle(color: LandmarkUIUtils.getColor(landmark.category), fontWeight: FontWeight.bold, fontSize: 12)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Consumer(builder: (context, ref, _) {
                        final isFav = ref.watch(campusMapsControllerProvider.notifier).isFavorite(landmark.id);
                        return IconButton(icon: Icon(isFav ? Icons.favorite : Icons.favorite_border, color: isFav ? Colors.red : null), onPressed: () => ref.read(campusMapsControllerProvider.notifier).toggleFavorite(landmark.id));
                      }),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _infoRow(Icons.description_outlined, landmark.description),
                  if (landmark.openingHours != null) _infoRow(Icons.access_time_rounded, landmark.openingHours!),
                  if (landmark.phone != null) _infoRow(Icons.phone_outlined, landmark.phone!),
                  if (!landmark.isAccessible) _infoRow(Icons.not_accessible_rounded, 'Limited accessibility reported'),
                  
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      _actionButton(Icons.share_outlined, 'Share', () {
                        final chatContext = ChatContext(
                          type: 'map',
                          id: landmark.id,
                          title: landmark.name,
                          thumbnail: landmark.photos.isNotEmpty ? landmark.photos.first : null,
                          metadata: {'latitude': landmark.latitude, 'longitude': landmark.longitude},
                        );
                        context.push('/share-to-chat', extra: chatContext);
                      }),
                      const SizedBox(width: 12),
                      _actionButton(Icons.copy_rounded, 'Copy', () {
                        Clipboard.setData(ClipboardData(text: '${landmark.latitude}, ${landmark.longitude}'));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Coordinates copied to clipboard')));
                      }),
                      const SizedBox(width: 12),
                      _actionButton(Icons.directions_outlined, 'Maps', () async {
                        final url = 'https://www.google.com/maps/search/?api=1&query=${landmark.latitude},${landmark.longitude}';
                        if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url));
                      }, primary: true),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEventDetails(BuildContext context, Event event) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => MapBottomSheet(
        child: Column(
          children: [
            if (event.imageUrls.isNotEmpty)
              Image.network(event.imageUrls.first, height: 200, width: double.infinity, fit: BoxFit.cover),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      event.status == EventStatus.live ? 'LIVE NOW' : 'UPCOMING',
                      style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _infoRow(Icons.calendar_today_outlined, DateFormat('EEEE, MMM dd, HH:mm').format(event.startAt)),
                  _infoRow(Icons.location_on_outlined, event.venue.address ?? 'TBA'),
                  if (event.venueRoom.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 32, bottom: 16),
                      child: Text(event.venueRoom, style: const TextStyle(color: Colors.grey)),
                    ),
                  
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      _actionButton(Icons.info_outline, 'Details', () {
                        Navigator.pop(context);
                        context.push('/events/${event.id}');
                      }),
                      const SizedBox(width: 12),
                      _actionButton(Icons.directions_outlined, 'Maps', () async {
                        final url = 'https://www.google.com/maps/search/?api=1&query=${event.venue.latitude},${event.venue.longitude}';
                        if (await canLaunchUrl(Uri.parse(url))) await launchUrl(Uri.parse(url));
                      }, primary: true),
                    ],
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14, height: 1.5))),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap, {bool primary = false}) {
    final theme = Theme.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: primary ? theme.colorScheme.primary : theme.colorScheme.surfaceVariant.withOpacity(0.3),
            borderRadius: BorderRadius.circular(12),
            border: primary ? null : Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            children: [
              Icon(icon, color: primary ? Colors.white : theme.colorScheme.primary, size: 20),
              const SizedBox(height: 4),
              Text(label, style: TextStyle(color: primary ? Colors.white : theme.colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }

  void _showCampusPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Consumer(
          builder: (context, ref, _) {
            final state = ref.watch(campusMapsControllerProvider);
            final campuses = state.campuses;
            
            return Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text('Switch Campus', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 8),
                const Divider(),
                Expanded(
                  child: campuses.isEmpty && !state.isLoading
                    ? const Center(child: Text('No campuses found'))
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: campuses.length,
                        itemBuilder: (context, index) {
                          final campus = campuses[index];
                          final isSelected = campus.id == state.selectedCampus?.id;
                          return ListTile(
                            leading: Icon(Icons.school_outlined, color: isSelected ? Theme.of(context).colorScheme.primary : null),
                            title: Text(campus.name, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w600)),
                            subtitle: Text('${campus.city}, ${campus.country}'),
                            trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary) : null,
                            onTap: () {
                              ref.read(campusMapsControllerProvider.notifier).selectCampus(campus);
                              _recenter();
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

}
