import '../models/attendance.dart';
import '../models/event.dart';

abstract class AttendanceRepository {
  Future<EventAttendance?> getAttendance(String userId, String eventId);
  Stream<EventAttendance?> watchAttendance(String userId, String eventId);
  
  Stream<List<EventAttendance>> watchUserAttendance(String userId);
  
  Future<void> setAttendance(String userId, String eventId, AttendanceStatus? status);
  
  // Queries for "My Events"
  Stream<List<Event>> watchGoingEvents(String userId);
  Stream<List<Event>> watchSavedEvents(String userId);
  Stream<List<Event>> watchPastEvents(String userId);
  
  // Organizer Queries
  Stream<List<EventAttendance>> watchEventAttendees(String eventId);
}
