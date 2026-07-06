import 'package:unihub_mobile/features/events/domain/models/event.dart';
import 'package:unihub_mobile/features/events/domain/models/organizer.dart';
import 'package:unihub_mobile/features/events/domain/models/attendance.dart';
import 'package:unihub_mobile/features/events/domain/repositories/event_repository.dart';
import 'package:unihub_mobile/features/events/domain/repositories/organizer_repository.dart';
import 'package:unihub_mobile/features/events/domain/repositories/attendance_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:unihub_mobile/services/notification_service.dart';
import 'package:unihub_mobile/core/services/notification_sender.dart';
import 'package:unihub_mobile/features/shared/domain/models/uni_notification.dart';
import 'package:unihub_mobile/core/utils/app_logger.dart';

class EventService {
  final EventRepository _eventRepository;
  final OrganizerRepository _organizerRepository;
  final AttendanceRepository _attendanceRepository;
  final FirebaseFirestore _firestore;
  final NotificationSender _notificationSender;

  EventService(
    this._eventRepository, 
    this._organizerRepository, 
    this._attendanceRepository,
    this._firestore,
    this._notificationSender
  );

  Future<void> createEvent(Event event, String userId) async {
    // DEFENSIVE: Validate parameters
    if (event.id.isEmpty || event.id.trim().isEmpty) {
      throw Exception('Event id cannot be empty');
    }
    if (userId.isEmpty || userId.trim().isEmpty) {
      throw Exception('Invalid userId: cannot be empty');
    }
    if (event.organizerId.isEmpty || event.organizerId.trim().isEmpty) {
      throw Exception('Event organizerId cannot be empty');
    }
    if (event.title.trim().isEmpty) {
      throw Exception('Event title cannot be empty');
    }

    // 1. Validate Organizer Membership & Permission
    final isAuthorized = await _validateOrganizerPermission(event.organizerId, userId);
    if (!isAuthorized) throw Exception('Unauthorized: You are not an authorized member of this organizer.');

    // 2. Business Rules Validation
    _validateEventDates(event.startAt, event.endAt);
    
    // 3. Set Initial Status (Always draft or submitted depending on UI flow)
    final initialEvent = event.copyWith(
      status: EventStatus.draft,
      updatedAt: DateTime.now(),
    );

    await _eventRepository.createEvent(initialEvent);
    
    AppLogger.info('Event Created: ${event.id} by $userId', 'EVENT_SERVICE');
  }

  Future<void> submitEvent(String eventId, String userId) async {
    // DEFENSIVE: Validate parameters
    if (eventId.isEmpty || eventId.trim().isEmpty) {
      throw Exception('Invalid eventId: cannot be empty');
    }
    if (userId.isEmpty || userId.trim().isEmpty) {
      throw Exception('Invalid userId: cannot be empty');
    }

    final event = await _eventRepository.getEventById(eventId);
    if (event == null) throw Exception('Event not found');

    // Validate event has required fields
    if (event.organizerId.isEmpty) {
      throw Exception('Event organizerId is missing');
    }
    if (event.title.trim().isEmpty) {
      throw Exception('Event title is required');
    }
    if (event.description.trim().isEmpty) {
      throw Exception('Event description is required');
    }

    final organizer = await _organizerRepository.getOrganizerById(event.organizerId);
    if (organizer == null) throw Exception('Organizer not found');

    final isAuthorized = await _validateOrganizerPermission(event.organizerId, userId);
    if (!isAuthorized) throw Exception('Unauthorized');

    // Business Rule: Only verified organizers can submit events for publishing
    if (organizer.verificationStatus != OrganizerVerificationStatus.verified && 
        organizer.verificationStatus != OrganizerVerificationStatus.official) {
      throw Exception('Only verified organizers can submit events for publishing. Please complete your organizer verification.');
    }

    if (event.status != EventStatus.draft) throw Exception('Only draft events can be submitted');

    await _eventRepository.updateEvent(event.copyWith(status: EventStatus.submitted));

    // Notify admins about new submission
    await _notificationSender.notifyAdmins(
      title: 'New Event Submission 📅',
      body: '"${event.title}" by ${organizer.name} requires review.',
      route: '/admin/events',
    );

    AppLogger.info('Event Submitted for Review: $eventId by $userId', 'EVENT_SERVICE');
  }

  Future<void> approveEvent(String eventId, String adminId) async {
    // DEFENSIVE: Validate parameters
    if (eventId.isEmpty || eventId.trim().isEmpty) {
      throw Exception('Invalid eventId: cannot be empty');
    }
    if (adminId.isEmpty || adminId.trim().isEmpty) {
      throw Exception('Invalid adminId: cannot be empty');
    }

    final event = await _eventRepository.getEventById(eventId);
    if (event == null) throw Exception('Event not found');

    if (event.status != EventStatus.submitted) throw Exception('Event must be in submitted state to be approved');

    // Re-verify admin privileges (defense-in-depth)
    final adminDoc = await _firestore.collection('users').doc(adminId).get();
    final adminData = adminDoc.data() as Map<String, dynamic>?;
    final isAdminFlag = adminData?['isAdmin'] ?? false;
    final roles = List<String>.from(adminData?['roles'] ?? []);
    if (!isAdminFlag && !roles.contains('admin')) {
      throw Exception('Unauthorized: Administrative privileges required.');
    }

    await _eventRepository.updateEvent(event.copyWith(status: EventStatus.approved));

    // Notify organizer members
    final members = await _organizerRepository.getOrganizerMembers(event.organizerId);
    for (final member in members) {
      await _notificationSender.sendNotification(
        recipientId: member.userId,
        title: 'Event Approved! ✅',
        body: 'Your event "${event.title}" has been approved and is now live on campus.',
        type: NotificationType.events,
        targetId: event.id,
        targetType: 'event',
      );
    }

    AppLogger.info('Event Approved: $eventId by Admin: $adminId', 'EVENT_SERVICE');
  }

  Future<void> scheduleEvent(String eventId) async {
    final event = await _eventRepository.getEventById(eventId);
    if (event == null) throw Exception('Event not found');
    
    if (event.status != EventStatus.approved) throw Exception('Event must be approved to be scheduled');

    await _eventRepository.updateEvent(event.copyWith(status: EventStatus.scheduled));
  }

  Future<void> updateEvent(Event updatedEvent, String userId) async {
    // DEFENSIVE: Validate parameters
    if (updatedEvent.id.isEmpty || updatedEvent.id.trim().isEmpty) {
      throw Exception('Event id cannot be empty');
    }
    if (userId.isEmpty || userId.trim().isEmpty) {
      throw Exception('Invalid userId: cannot be empty');
    }
    if (updatedEvent.organizerId.isEmpty) {
      throw Exception('Event organizerId cannot be empty');
    }

    final originalEvent = await _eventRepository.getEventById(updatedEvent.id);
    if (originalEvent == null) throw Exception('Event not found');

    final isAuthorized = await _validateOrganizerPermission(updatedEvent.organizerId, userId);
    if (!isAuthorized) throw Exception('Unauthorized');

    await _eventRepository.updateEvent(updatedEvent.copyWith(updatedAt: DateTime.now()));

    // Smart Notifications: Only notify for major changes
    bool timeChanged = originalEvent.startAt != updatedEvent.startAt;
    bool venueChanged = originalEvent.venue.address != updatedEvent.venue.address;

    if (timeChanged || venueChanged) {
      // Trigger update notification for attendees (future enhancement)
    }

    AppLogger.info('Event Updated: ${updatedEvent.id} by $userId', 'EVENT_SERVICE');
  }

  Future<void> cancelEvent(String eventId, String userId, String reason) async {
    // DEFENSIVE: Validate parameters
    if (eventId.isEmpty || eventId.trim().isEmpty) {
      throw Exception('Event id cannot be empty');
    }
    if (userId.isEmpty || userId.trim().isEmpty) {
      throw Exception('Invalid userId: cannot be empty');
    }
    if (reason.trim().isEmpty) {
      throw Exception('Cancellation reason is required');
    }

    final event = await _eventRepository.getEventById(eventId);
    if (event == null) throw Exception('Event not found');

    final isAuthorized = await _validateOrganizerPermission(event.organizerId, userId);
    if (!isAuthorized) throw Exception('Unauthorized');

    // Soft "cancel"
    await _eventRepository.updateEvent(event.copyWith(status: EventStatus.cancelled, metadata: {...event.metadata, 'cancelReason': reason}));

    AppLogger.info('Event Cancelled: $eventId by $userId. Reason: $reason', 'EVENT_SERVICE');
  }

  Future<void> setEventLive(String eventId) async {
    // DEFENSIVE: Validate parameter
    if (eventId.isEmpty || eventId.trim().isEmpty) {
      throw Exception('Invalid eventId: cannot be empty');
    }

    final event = await _eventRepository.getEventById(eventId);
    if (event == null) throw Exception('Event not found');
    
    // Transition from approved or scheduled to live
    if (event.status != EventStatus.approved && event.status != EventStatus.scheduled) {
      throw Exception('Event must be approved or scheduled to go live');
    }

    await _eventRepository.updateEvent(event.copyWith(status: EventStatus.live));
    AppLogger.info('Event Live: $eventId', 'EVENT_SERVICE');
  }

  Future<void> endEvent(String eventId) async {
    // DEFENSIVE: Validate parameter
    if (eventId.isEmpty || eventId.trim().isEmpty) {
      throw Exception('Invalid eventId: cannot be empty');
    }

    final event = await _eventRepository.getEventById(eventId);
    if (event == null) throw Exception('Event not found');

    await _eventRepository.updateEvent(event.copyWith(status: EventStatus.ended));
    AppLogger.info('Event Ended: $eventId', 'EVENT_SERVICE');
  }

  Future<void> archiveEvent(String eventId, String userId) async {
    // DEFENSIVE: Validate parameters
    if (eventId.isEmpty || eventId.trim().isEmpty) {
      throw Exception('Event id cannot be empty');
    }
    if (userId.isEmpty || userId.trim().isEmpty) {
      throw Exception('Invalid userId: cannot be empty');
    }

    final event = await _eventRepository.getEventById(eventId);
    if (event == null) throw Exception('Event not found');

    final isAuthorized = await _validateOrganizerPermission(event.organizerId, userId);
    if (!isAuthorized) throw Exception('Unauthorized');

    await _eventRepository.updateEvent(event.copyWith(status: EventStatus.archived));
    AppLogger.info('Event Archived: $eventId by $userId', 'EVENT_SERVICE');
  }

  // --- Attendance Business Logic ---

  Future<void> setAttendance(String userId, String eventId, AttendanceStatus? status) async {
    // 1. Core Trust Rule: Identity verification required for "Going"
    if (status == AttendanceStatus.going) {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final isVerified = userDoc.data()?['isIdentityVerified'] ?? false;
      if (!isVerified) {
        throw Exception('Identity verification is required to reserve a spot for events.');
      }
    }

    // 2. Event State Rule: Can only attend approved/scheduled/live events
    final event = await _eventRepository.getEventById(eventId);
    if (event == null) throw Exception('Event not found');
    
    if (status != null && 
        event.status != EventStatus.approved && 
        event.status != EventStatus.scheduled && 
        event.status != EventStatus.live) {
      throw Exception('This event is not accepting registrations at this time.');
    }

    // 3. Delegate to repository for atomic transaction
    await _attendanceRepository.setAttendance(userId, eventId, status);
  }

  // Helper Validations
  Future<bool> _validateOrganizerPermission(String organizerId, String userId) async {
    final member = await _organizerRepository.getMember(organizerId, userId);
    return member != null;
  }

  void _validateEventDates(DateTime start, DateTime end) {
    if (start.isBefore(DateTime.now())) {
      throw Exception('Event cannot start in the past');
    }
    if (end.isBefore(start)) {
      throw Exception('Event must end after it starts');
    }
  }
}
