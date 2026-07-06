import 'package:cloud_firestore/cloud_firestore.dart';

enum ViewingRequestStatus {
  pending,
  confirmed,
  rescheduled,
  cancelled,
  completed
}

class ViewingRequest {
  final String id;
  final String listingId;
  final String listingTitle;
  final String studentId;
  final String studentName;
  final String plugId;
  final String plugName;
  final DateTime preferredDate;
  final String? notes;
  final ViewingRequestStatus status;
  final DateTime createdAt;
  final DateTime? updatedAt;

  ViewingRequest({
    required this.id,
    required this.listingId,
    required this.listingTitle,
    required this.studentId,
    required this.studentName,
    required this.plugId,
    required this.plugName,
    required this.preferredDate,
    this.notes,
    this.status = ViewingRequestStatus.pending,
    required this.createdAt,
    this.updatedAt,
  });

  factory ViewingRequest.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ViewingRequest(
      id: doc.id,
      listingId: data['listingId'],
      listingTitle: data['listingTitle'],
      studentId: data['studentId'],
      studentName: data['studentName'],
      plugId: data['plugId'],
      plugName: data['plugName'],
      preferredDate: (data['preferredDate'] as Timestamp).toDate(),
      notes: data['notes'],
      status: ViewingRequestStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => ViewingRequestStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'listingId': listingId,
      'listingTitle': listingTitle,
      'studentId': studentId,
      'studentName': studentName,
      'plugId': plugId,
      'plugName': plugName,
      'preferredDate': Timestamp.fromDate(preferredDate),
      'notes': notes,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  ViewingRequest copyWith({
    ViewingRequestStatus? status,
    DateTime? preferredDate,
    String? notes,
    DateTime? updatedAt,
  }) {
    return ViewingRequest(
      id: id,
      listingId: listingId,
      listingTitle: listingTitle,
      studentId: studentId,
      studentName: studentName,
      plugId: plugId,
      plugName: plugName,
      preferredDate: preferredDate ?? this.preferredDate,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
