import 'package:cloud_firestore/cloud_firestore.dart';

enum AttendanceStatus { saved, going }

class EventAttendance {
  final String id; // userId_eventId
  final String userId;
  final String eventId;
  final AttendanceStatus status;
  final DateTime updatedAt;

  EventAttendance({
    required this.id,
    required this.userId,
    required this.eventId,
    required this.status,
    required this.updatedAt,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'eventId': eventId,
      'status': status.name,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory EventAttendance.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventAttendance(
      id: doc.id,
      userId: data['userId'] ?? '',
      eventId: data['eventId'] ?? '',
      status: AttendanceStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => AttendanceStatus.saved,
      ),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }
}
