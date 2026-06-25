import 'package:cloud_firestore/cloud_firestore.dart';

class NoteListing {
  final String id;
  final String authorId;
  final String authorName;
  final String university;
  final String course;
  final String unitCode;
  final String unitName;
  final String subjectCategory;
  final List<String> tags;
  final String title;
  final String description;
  final String fileUrl;
  final String noteType;
  final String yearOfStudy;
  final double price;
  final int downloadsCount;
  final DateTime createdAt;

  NoteListing({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.university,
    required this.course,
    required this.unitCode,
    required this.unitName,
    required this.subjectCategory,
    required this.tags,
    required this.title,
    required this.description,
    required this.fileUrl,
    required this.noteType,
    required this.yearOfStudy,
    required this.price,
    this.downloadsCount = 0,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'authorId': authorId,
      'authorName': authorName,
      'university': university,
      'course': course,
      'unitCode': unitCode,
      'unitName': unitName,
      'subjectCategory': subjectCategory,
      'tags': tags,
      'title': title,
      'description': description,
      'fileUrl': fileUrl,
      'noteType': noteType,
      'yearOfStudy': yearOfStudy,
      'price': price,
      'downloadsCount': downloadsCount,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory NoteListing.fromJson(Map<String, dynamic> json) {
    return NoteListing(
      id: json['id'] ?? '',
      authorId: json['authorId'] ?? '',
      authorName: json['authorName'] ?? 'Unknown',
      university: json['university'] ?? '',
      course: json['course'] ?? '',
      unitCode: json['unitCode'] ?? '',
      unitName: json['unitName'] ?? '',
      subjectCategory: json['subjectCategory'] ?? 'General',
      tags: List<String>.from(json['tags'] ?? []),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      fileUrl: json['fileUrl'] ?? '',
      noteType: json['noteType'] ?? 'Lecture Note',
      yearOfStudy: json['yearOfStudy'] ?? '1',
      price: (json['price'] ?? 0.0).toDouble(),
      downloadsCount: json['downloadsCount'] ?? 0,
      createdAt: json['createdAt'] != null 
          ? (json['createdAt'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }
}
