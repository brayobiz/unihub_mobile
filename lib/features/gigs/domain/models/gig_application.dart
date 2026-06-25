import 'package:cloud_firestore/cloud_firestore.dart';

enum ApplicationStatus { pending, accepted, rejected }

class GigApplication {
  final String id;
  final String gigId;
  final String gigTitle;
  final String employerId;
  final String freelancerId;
  final String fullName;
  final String email;
  final String phoneNumber;
  final String coverLetter;
  final String? portfolioLink;
  final String? cvUrl;
  final String? conversationId;
  final ApplicationStatus status;
  final DateTime createdAt;

  GigApplication({
    required this.id,
    required this.gigId,
    required this.gigTitle,
    required this.employerId,
    required this.freelancerId,
    required this.fullName,
    required this.email,
    required this.phoneNumber,
    required this.coverLetter,
    this.portfolioLink,
    this.cvUrl,
    this.conversationId,
    this.status = ApplicationStatus.pending,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'gigId': gigId,
    'gigTitle': gigTitle,
    'employerId': employerId,
    'freelancerId': freelancerId,
    'fullName': fullName,
    'email': email,
    'phoneNumber': phoneNumber,
    'coverLetter': coverLetter,
    'portfolioLink': portfolioLink,
    'cvUrl': cvUrl,
    'conversationId': conversationId,
    'status': status.name,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  factory GigApplication.fromJson(Map<String, dynamic> json) {
    return GigApplication(
      id: json['id'] ?? '',
      gigId: json['gigId'] ?? '',
      gigTitle: json['gigTitle'] ?? '',
      employerId: json['employerId'] ?? '',
      freelancerId: json['freelancerId'] ?? '',
      fullName: json['fullName'] ?? '',
      email: json['email'] ?? '',
      phoneNumber: json['phoneNumber'] ?? '',
      coverLetter: json['coverLetter'] ?? '',
      portfolioLink: json['portfolioLink'],
      cvUrl: json['cvUrl'],
      conversationId: json['conversationId'],
      status: ApplicationStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => ApplicationStatus.pending,
      ),
      createdAt: (json['createdAt'] as Timestamp).toDate(),
    );
  }
}
