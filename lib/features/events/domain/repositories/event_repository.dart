import '../models/event.dart';
import '../models/event_category.dart';

abstract class EventRepository {
  // Events
  Future<Event?> getEventById(String id);
  Stream<Event?> watchEventById(String id);
  
  Stream<List<Event>> watchEventsByCampus(String? campusId, {
    List<EventStatus>? statuses,
    String? categoryId,
    DateTime? after,
    int? limit,
    Event? startAfter,
  });
  
  Stream<List<Event>> watchEventsByOrganizer(String organizerId);
  
  Future<void> createEvent(Event event);
  Future<void> updateEvent(Event event);
  Future<void> deleteEvent(String id);
  Future<void> incrementShareCount(String id);
  
  Future<void> reportEvent({
    required String eventId,
    required String reporterId,
    required String reason,
  });
  
  // Categories
  Future<List<EventCategory>> getCategories();
  Stream<List<EventCategory>> watchCategories();
  
  // High-level Domain Queries (Implementation-agnostic)
  Stream<List<Event>> watchFeaturedEvents(String? campusId);
  Stream<List<Event>> watchLiveEvents(String? campusId);
  Stream<List<Event>> watchUpcomingEvents(String? campusId);
}
