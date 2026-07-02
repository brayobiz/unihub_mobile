import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/campus_constants.dart';

class RoommateProfile {
  final String id;
  final String userId;
  final String name;
  final String university;
  final String campus;
  final String course;
  final int yearOfStudy;
  final double budget;
  final String preferredLocation;
  final String gender;
  final List<String> lifestyle; // e.g., ["Early Bird", "Non-smoker"]
  final String bio;
  final String profileImage;
  final DateTime createdAt;
  final bool isActive;

  RoommateProfile({
    required this.id,
    required this.userId,
    required this.name,
    required this.university,
    required this.campus,
    required this.course,
    required this.yearOfStudy,
    required this.budget,
    required this.preferredLocation,
    required this.gender,
    required this.lifestyle,
    required this.bio,
    this.profileImage = '',
    required this.createdAt,
    this.isActive = true,
  });

  factory RoommateProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RoommateProfile(
      id: doc.id,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      university: CampusConstants.resolveToId(data['university']?.toString()) ?? (data['university'] ?? '').toString(),
      campus: CampusConstants.resolveToId(data['campus']?.toString()) ?? (data['campus'] ?? '').toString(),
      course: data['course'] ?? '',
      yearOfStudy: data['yearOfStudy'] ?? 1,
      budget: (data['budget'] ?? 0).toDouble(),
      preferredLocation: data['preferredLocation'] ?? '',
      gender: data['gender'] ?? '',
      lifestyle: List<String>.from(data['lifestyle'] ?? <String>[]),
      bio: data['bio'] ?? '',
      profileImage: data['profileImage'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'name': name,
      'university': university,
      'campus': campus,
      'course': course,
      'yearOfStudy': yearOfStudy,
      'budget': budget,
      'preferredLocation': preferredLocation,
      'gender': gender,
      'lifestyle': lifestyle,
      'bio': bio,
      'profileImage': profileImage,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
    };
  }
}
