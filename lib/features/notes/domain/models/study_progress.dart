import 'package:cloud_firestore/cloud_firestore.dart';

class StudyProgress {
  final String noteId;
  final String userId;
  final int lastPage;
  final int totalPages;
  final double progress; // 0.0 to 1.0
  final bool isBookmarked;
  final DateTime lastAccessed;

  StudyProgress({
    required this.noteId,
    required this.userId,
    this.lastPage = 0,
    this.totalPages = 0,
    this.progress = 0.0,
    this.isBookmarked = false,
    required this.lastAccessed,
  });

  Map<String, dynamic> toJson() {
    return {
      'noteId': noteId,
      'userId': userId,
      'lastPage': lastPage,
      'totalPages': totalPages,
      'progress': progress,
      'isBookmarked': isBookmarked,
      'lastAccessed': Timestamp.fromDate(lastAccessed),
    };
  }

  factory StudyProgress.fromJson(Map<String, dynamic> json) {
    return StudyProgress(
      noteId: json['noteId'] ?? '',
      userId: json['userId'] ?? '',
      lastPage: json['lastPage'] ?? 0,
      totalPages: json['totalPages'] ?? 0,
      progress: (json['progress'] ?? 0.0).toDouble(),
      isBookmarked: json['isBookmarked'] ?? false,
      lastAccessed: json['lastAccessed'] != null 
          ? (json['lastAccessed'] as Timestamp).toDate() 
          : DateTime.now(),
    );
  }

  StudyProgress copyWith({
    int? lastPage,
    int? totalPages,
    double? progress,
    bool? isBookmarked,
    DateTime? lastAccessed,
  }) {
    return StudyProgress(
      noteId: noteId,
      userId: userId,
      lastPage: lastPage ?? this.lastPage,
      totalPages: totalPages ?? this.totalPages,
      progress: progress ?? this.progress,
      isBookmarked: isBookmarked ?? this.isBookmarked,
      lastAccessed: lastAccessed ?? this.lastAccessed,
    );
  }
}
