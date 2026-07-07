import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/attendance.dart';
import '../../domain/models/event.dart';
import '../../domain/repositories/attendance_repository.dart';
import '../../../../services/notification_service.dart';
import '../../../../core/services/notification_sender.dart';
import '../../shared/providers.dart';
import '../../../shared/domain/models/uni_notification.dart';
import '../../../../core/utils/app_logger.dart';

class AttendanceRepositoryImpl implements AttendanceRepository {
  final FirebaseFirestore _firestore;
  final NotificationSender? _notificationSender;

  AttendanceRepositoryImpl(this._firestore, [this._notificationSender]);

  @override
  Future<EventAttendance?> getAttendance(String userId, String eventId) async {
    final doc = await _firestore.collection('event_attendance').doc('${userId}_$eventId').get();
    if (!doc.exists) return null;
    return EventAttendance.fromFirestore(doc);
  }

  @override
  Stream<EventAttendance?> watchAttendance(String userId, String eventId) {
    return _firestore.collection('event_attendance').doc('${userId}_$eventId').snapshots().map((doc) {
      if (!doc.exists) return null;
      return EventAttendance.fromFirestore(doc);
    });
  }

  @override
  Stream<List<EventAttendance>> watchUserAttendance(String userId) {
    return _firestore.collection('event_attendance')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((s) => s.docs.map((d) => EventAttendance.fromFirestore(d)).toList());
  }

  @override
  Future<void> setAttendance(String userId, String eventId, AttendanceStatus? status) async {
    final docRef = _firestore.collection('event_attendance').doc('${userId}_$eventId');
    final eventRef = _firestore.collection('events').doc(eventId);
    
    await _firestore.runTransaction((transaction) async {
      final attendanceDoc = await transaction.get(docRef);
      final eventDoc = await transaction.get(eventRef);
      
      if (!eventDoc.exists) throw Exception('Event not found');
      
      final oldStatusStr = attendanceDoc.exists ? (attendanceDoc.data()?['status'] as String?) : null;
      AttendanceStatus? oldStatus;
      if (oldStatusStr != null) {
        for (final s in AttendanceStatus.values) {
          if (s.name == oldStatusStr) {
            oldStatus = s;
            break;
          }
        }
      }

      if (status == AttendanceStatus.going && oldStatus != AttendanceStatus.going) {
        final data = eventDoc.data() as Map<String, dynamic>;
        final maxCapacity = data['maxCapacity'] as int?;
        final currentCount = (data['currentAttendeeCount'] ?? 0) as int;
        if (maxCapacity != null && currentCount >= maxCapacity) {
          throw Exception('Event is at full capacity');
        }
      }

      if (status == null) {
        // Remove attendance
        if (attendanceDoc.exists) {
          transaction.delete(docRef);
          _updateCounts(transaction, eventRef, oldStatus, null);
        }
      } else {
        // Set/Update attendance
        transaction.set(docRef, {
          'userId': userId,
          'eventId': eventId,
          'status': status.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        _updateCounts(transaction, eventRef, oldStatus, status);
      }
    });

    if (status != null) {
      AppLogger.info('Attendance Update: User $userId marked ${status.name} for Event $eventId', 'ATTENDANCE_REPO');
    } else {
      AppLogger.info('Attendance Removed: User $userId removed status for Event $eventId', 'ATTENDANCE_REPO');
    }

    if (_notificationSender != null && status != null) {
      final eventDoc = await _firestore.collection('events').doc(eventId).get();
      final event = Event.fromFirestore(eventDoc);
      
      if (status == AttendanceStatus.going) {
        await _notificationSender!.sendNotification(
          recipientId: userId,
          title: 'You\'re going! 📅',
          body: 'Success! "${event.title}" has been added to your My Events hub.',
          type: NotificationType.events,
          targetId: eventId,
          targetType: 'event',
        );
      }
    }
  }

  void _updateCounts(Transaction transaction, DocumentReference eventRef, AttendanceStatus? oldStatus, AttendanceStatus? newStatus) {
    if (oldStatus == newStatus) return;

    // Decrement old
    if (oldStatus == AttendanceStatus.going) {
      transaction.update(eventRef, {'currentAttendeeCount': FieldValue.increment(-1)});
    } else if (oldStatus == AttendanceStatus.saved) {
      transaction.update(eventRef, {'savedCount': FieldValue.increment(-1)});
    }

    // Increment new
    if (newStatus == AttendanceStatus.going) {
      transaction.update(eventRef, {'currentAttendeeCount': FieldValue.increment(1)});
    } else if (newStatus == AttendanceStatus.saved) {
      transaction.update(eventRef, {'savedCount': FieldValue.increment(1)});
    }
  }

  Future<List<Event>> _getEventsByIds(List<String> ids) async {
    final List<Event> results = [];
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snapshot = await _firestore.collection('events')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      results.addAll(snapshot.docs.map((doc) => Event.fromFirestore(doc)));
    }
    return results;
  }

  @override
  Stream<List<Event>> watchGoingEvents(String userId) {
    return _watchEventsByStatus(userId, AttendanceStatus.going, isPast: false);
  }

  @override
  Stream<List<Event>> watchSavedEvents(String userId) {
    return _watchEventsByStatus(userId, AttendanceStatus.saved, isPast: false);
  }

  @override
  Stream<List<Event>> watchPastEvents(String userId) {
    // This could be either going or saved, but specifically where endAt < now
    return _firestore.collection('event_attendance')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .asyncMap((snapshot) async {
          final eventIds = snapshot.docs.map((d) => d.data()['eventId'] as String).toList();
          if (eventIds.isEmpty) return [];
          
          final events = await _getEventsByIds(eventIds);
          
          final now = DateTime.now();
          return events
              .where((e) => e.endAt.isBefore(now))
              .toList();
        });
  }

  Stream<List<Event>> _watchEventsByStatus(String userId, AttendanceStatus status, {required bool isPast}) {
    return _firestore.collection('event_attendance')
        .where('userId', isEqualTo: userId)
        .where('status', isEqualTo: status.name)
        .snapshots()
        .asyncMap((snapshot) async {
          final eventIds = snapshot.docs.map((d) => d.data()['eventId'] as String).toList();
          if (eventIds.isEmpty) return [];
          
          final events = await _getEventsByIds(eventIds);
          
          final now = DateTime.now();
          return events
              .where((e) {
                if (isPast) {
                  return e.endAt.isBefore(now);
                } else {
                  return e.endAt.isAfter(now) || e.endAt.isAtSameMomentAs(now);
                }
              })
              .toList();
        });
  }
}
