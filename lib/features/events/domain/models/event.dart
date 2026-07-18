import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unihub_mobile/core/location/models/location_data.dart';

enum EventStatus { draft, submitted, approved, scheduled, live, ended, archived, cancelled, removed }
enum EventVisibility { public, campusOnly, inviteOnly }

class Event {
  final String id;
  final String organizerId;
  final String campusId;
  final String title;
  final String description;
  final String categoryId;
  final List<String> imageUrls;
  
  final LocationData venue;
  final String venueRoom; // Specific room/hall info
  
  final DateTime startAt;
  final DateTime endAt;
  
  final EventStatus status;
  final EventVisibility visibility;
  
  // Settings
  final bool isRegistrationRequired;
  final String? registrationUrl;
  final int? maxCapacity;
  final int currentAttendeeCount;
  final int savedCount;
  
  // Metadata
  final List<String> tags;
  final Map<String, dynamic> metadata;
  
  // Audit
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final bool isDeleted;

  bool get isExpired => endAt.isBefore(DateTime.now());
  bool get isUpcoming => startAt.isAfter(DateTime.now());
  bool get isLive => startAt.isBefore(DateTime.now()) && endAt.isAfter(DateTime.now());

  Event({
    required this.id,
    required this.organizerId,
    required this.campusId,
    required this.title,
    required this.description,
    required this.categoryId,
    this.imageUrls = const [],
    required this.venue,
    this.venueRoom = '',
    required this.startAt,
    required this.endAt,
    this.status = EventStatus.draft,
    this.visibility = EventVisibility.public,
    this.isRegistrationRequired = false,
    this.registrationUrl,
    this.maxCapacity,
    this.currentAttendeeCount = 0,
    this.savedCount = 0,
    this.tags = const [],
    this.metadata = const {},
    required this.createdAt,
    this.updatedAt,
    required this.createdBy,
    this.isDeleted = false,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'organizerId': organizerId,
      'campusId': campusId,
      'title': title,
      'description': description,
      'categoryId': categoryId,
      'imageUrls': imageUrls,
      'venue': venue.toJson(),
      'venueRoom': venueRoom,
      'startAt': Timestamp.fromDate(startAt),
      'endAt': Timestamp.fromDate(endAt),
      'status': status.name,
      'visibility': visibility.name,
      'isRegistrationRequired': isRegistrationRequired,
      'registrationUrl': registrationUrl,
      'maxCapacity': maxCapacity,
      'currentAttendeeCount': currentAttendeeCount,
      'savedCount': savedCount,
      'tags': tags,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'createdBy': createdBy,
      'isDeleted': isDeleted,
      'searchKeywords': title.toLowerCase().split(' '),
    };
  }

  factory Event.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    // DEFENSIVE: Handle missing or null timestamps
    DateTime parseTimestamp(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is Timestamp) return value.toDate();
      return DateTime.now();
    }

    // DEFENSIVE: Parse LocationData safely
    LocationData parseVenue(dynamic venueData) {
      try {
        if (venueData is Map<String, dynamic>) {
          return LocationData.fromJson(venueData);
        }
      } catch (e) {
        // Fall back to empty location
      }
      return LocationData.fromJson({});
    }

    return Event(
      id: doc.id,
      organizerId: data['organizerId'] ?? '',
      campusId: data['campusId'] ?? '',
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      categoryId: data['categoryId'] ?? '',
      imageUrls: List<String>.from(data['imageUrls'] ?? []),
      venue: parseVenue(data['venue']),
      venueRoom: data['venueRoom'] ?? '',
      startAt: parseTimestamp(data['startAt']),
      endAt: parseTimestamp(data['endAt']),
      status: EventStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => EventStatus.draft,
      ),
      visibility: EventVisibility.values.firstWhere(
        (e) => e.name == data['visibility'],
        orElse: () => EventVisibility.public,
      ),
      isRegistrationRequired: data['isRegistrationRequired'] ?? false,
      registrationUrl: data['registrationUrl'],
      maxCapacity: data['maxCapacity'],
      currentAttendeeCount: data['currentAttendeeCount'] ?? 0,
      savedCount: data['savedCount'] ?? 0,
      tags: List<String>.from(data['tags'] ?? []),
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
      createdAt: parseTimestamp(data['createdAt']),
      updatedAt: (data['updatedAt'] is Timestamp) ? (data['updatedAt'] as Timestamp).toDate() : null,
      createdBy: data['createdBy'] ?? '',
      isDeleted: data['isDeleted'] ?? false,
    );
  }

  Event copyWith({
    String? title,
    String? description,
    String? categoryId,
    List<String>? imageUrls,
    LocationData? venue,
    String? venueRoom,
    DateTime? startAt,
    DateTime? endAt,
    EventStatus? status,
    EventVisibility? visibility,
    bool? isRegistrationRequired,
    String? registrationUrl,
    int? maxCapacity,
    int? currentAttendeeCount,
    int? savedCount,
    List<String>? tags,
    Map<String, dynamic>? metadata,
    DateTime? updatedAt,
    bool? isDeleted,
  }) {
    return Event(
      id: id,
      organizerId: organizerId,
      campusId: campusId,
      title: title ?? this.title,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      imageUrls: imageUrls ?? this.imageUrls,
      venue: venue ?? this.venue,
      venueRoom: venueRoom ?? this.venueRoom,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
      status: status ?? this.status,
      visibility: visibility ?? this.visibility,
      isRegistrationRequired: isRegistrationRequired ?? this.isRegistrationRequired,
      registrationUrl: registrationUrl ?? this.registrationUrl,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      currentAttendeeCount: currentAttendeeCount ?? this.currentAttendeeCount,
      savedCount: savedCount ?? this.savedCount,
      tags: tags ?? this.tags,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}
