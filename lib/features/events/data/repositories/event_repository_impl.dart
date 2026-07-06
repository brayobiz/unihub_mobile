import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/event.dart';
import '../../domain/models/event_category.dart';
import '../../domain/repositories/event_repository.dart';

class EventRepositoryImpl implements EventRepository {
  final FirebaseFirestore _firestore;

  EventRepositoryImpl(this._firestore);

  @override
  Future<Event?> getEventById(String id) async {
    if (id.isEmpty) return null;
    final doc = await _firestore.collection('events').doc(id).get();
    if (!doc.exists) return null;
    return Event.fromFirestore(doc);
  }

  @override
  Stream<Event?> watchEventById(String id) {
    if (id.isEmpty) return Stream.value(null);
    return _firestore.collection('events').doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Event.fromFirestore(doc);
    });
  }

  @override
  Stream<List<Event>> watchEventsByCampus(String campusId, {
    List<EventStatus>? statuses,
    String? categoryId,
    DateTime? after,
    int? limit,
    Event? startAfter,
  }) {
    // We simplify the Firestore query to only equality filters to avoid complex composite index requirements.
    // Range filtering (after) and ordering (startAt) are handled in-memory.
    Query query = _firestore.collection('events')
        .where('campusId', isEqualTo: campusId)
        .where('isDeleted', isEqualTo: false);
    
    final List<String> statusNames = statuses != null && statuses.isNotEmpty
        ? statuses.map((s) => s.name).toList()
        : [
            EventStatus.approved.name,
            EventStatus.scheduled.name,
            EventStatus.live.name,
          ];

    query = query.where('status', whereIn: statusNames);

    if (categoryId != null) {
      query = query.where('categoryId', isEqualTo: categoryId);
    }

    // Limit is still useful to keep the payload reasonable if the campus is huge,
    // though in-memory sorting works best on the full upcoming set.
    if (limit != null && after == null) {
       query = query.limit(limit);
    }

    return query.snapshots().map((snapshot) {
      final events = snapshot.docs.map((d) => Event.fromFirestore(d)).toList();
      
      // Perform in-memory filtering and sorting to bypass Firestore index limitations
      var filteredEvents = events;
      
      if (after != null) {
        filteredEvents = filteredEvents.where((e) => e.startAt.isAfter(after) || e.startAt.isAtSameMomentAs(after)).toList();
      }

      // Sort by startAt ascending
      filteredEvents.sort((a, b) => a.startAt.compareTo(b.startAt));

      if (limit != null) {
        return filteredEvents.take(limit).toList();
      }
      
      return filteredEvents;
    });
  }

  @override
  Stream<List<Event>> watchEventsByOrganizer(String organizerId) {
    // DEFENSIVE: Validate organizerId
    if (organizerId.isEmpty || organizerId.trim().isEmpty) {
      return Stream.error(Exception('Invalid organizerId: cannot be empty'));
    }

    return _firestore.collection('events')
        .where('organizerId', isEqualTo: organizerId)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((s) {
          final events = s.docs.map((d) => Event.fromFirestore(d)).toList();
          // In-memory sort to avoid composite index requirements
          events.sort((a, b) => b.startAt.compareTo(a.startAt));
          return events;
        });
  }

  @override
  Future<void> createEvent(Event event) async {
    // DEFENSIVE: Validate event data
    if (event.id.isEmpty) {
      throw Exception('Event id cannot be empty');
    }
    if (event.organizerId.isEmpty) {
      throw Exception('Event organizerId cannot be empty');
    }
    if (event.campusId.isEmpty) {
      throw Exception('Event campusId cannot be empty');
    }
    if (event.title.trim().isEmpty) {
      throw Exception('Event title cannot be empty');
    }
    if (event.createdBy.isEmpty) {
      throw Exception('Event createdBy cannot be empty');
    }

    await _firestore.collection('events').doc(event.id).set(event.toFirestore());
  }

  @override
  Future<void> updateEvent(Event event) async {
    // DEFENSIVE: Validate event data
    if (event.id.isEmpty || event.id.trim().isEmpty) {
      throw Exception('Event id cannot be empty');
    }
    if (event.organizerId.isEmpty) {
      throw Exception('Event organizerId cannot be empty');
    }

    await _firestore.collection('events').doc(event.id).update(event.toFirestore());
  }

  @override
  Future<void> deleteEvent(String id) async {
    await _firestore.collection('events').doc(id).update({
      'isDeleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> reportEvent({
    required String eventId,
    required String reporterId,
    required String reason,
  }) async {
    await _firestore.collection('reports').add({
      'type': 'event',
      'targetId': eventId,
      'reporterId': reporterId,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  @override
  Future<List<EventCategory>> getCategories() async {
    final snapshot = await _firestore.collection('event_categories')
        .where('isActive', isEqualTo: true)
        .orderBy('priority', descending: true)
        .get();
    return snapshot.docs.map((d) => EventCategory.fromFirestore(d)).toList();
  }

  @override
  Stream<List<EventCategory>> watchCategories() {
    return _firestore.collection('event_categories')
        .where('isActive', isEqualTo: true)
        .orderBy('priority', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => EventCategory.fromFirestore(d)).toList());
  }

  @override
  Stream<List<Event>> watchFeaturedEvents(String campusId) {
    // Featured events are typically approved/scheduled and marked in metadata or have high engagement
    // For now, let's just use approved/scheduled/live events for the next 7 days
    return watchEventsByCampus(
      campusId,
      after: DateTime.now(),
      limit: 10,
    );
  }

  @override
  Stream<List<Event>> watchLiveEvents(String campusId) {
    return _firestore.collection('events')
        .where('campusId', isEqualTo: campusId)
        .where('status', isEqualTo: EventStatus.live.name)
        .where('isDeleted', isEqualTo: false)
        .snapshots()
        .map((s) => s.docs.map((d) => Event.fromFirestore(d)).toList());
  }

  @override
  Stream<List<Event>> watchUpcomingEvents(String campusId) {
    return watchEventsByCampus(
      campusId,
      statuses: [EventStatus.approved, EventStatus.scheduled],
      after: DateTime.now(),
    );
  }
}
