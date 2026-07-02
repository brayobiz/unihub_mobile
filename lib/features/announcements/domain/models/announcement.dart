import 'package:cloud_firestore/cloud_firestore.dart';

enum AnnouncementType { global, featureSpecific }
enum AnnouncementDisplayStyle { banner, card, modal, sticky }
enum AnnouncementPriority { low, normal, high, critical }
enum AnnouncementStatus { draft, published, scheduled, archived }

class Announcement {
  final String id;
  final String title;
  final String content;
  final AnnouncementType type;
  final List<String> targetFeatures;
  final Map<String, dynamic> targetAudience;
  final AnnouncementDisplayStyle displayStyle;
  final AnnouncementPriority priority;
  final AnnouncementStatus status;
  final DateTime publishAt;
  final DateTime? expiresAt;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.type,
    this.targetFeatures = const [],
    this.targetAudience = const {},
    this.displayStyle = AnnouncementDisplayStyle.banner,
    this.priority = AnnouncementPriority.normal,
    this.status = AnnouncementStatus.draft,
    required this.publishAt,
    this.expiresAt,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'type': type.name,
      'targetFeatures': targetFeatures,
      'targetAudience': targetAudience,
      'displayStyle': displayStyle.name,
      'priority': priority.name,
      'status': status.name,
      'publishAt': Timestamp.fromDate(publishAt),
      'expiresAt': expiresAt != null ? Timestamp.fromDate(expiresAt!) : null,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      content: json['content'] ?? '',
      type: AnnouncementType.values.firstWhere((e) => e.name == json['type'], orElse: () => AnnouncementType.global),
      targetFeatures: List<String>.from(json['targetFeatures'] ?? []),
      targetAudience: Map<String, dynamic>.from(json['targetAudience'] ?? {}),
      displayStyle: AnnouncementDisplayStyle.values.firstWhere((e) => e.name == json['displayStyle'], orElse: () => AnnouncementDisplayStyle.banner),
      priority: AnnouncementPriority.values.firstWhere((e) => e.name == json['priority'], orElse: () => AnnouncementPriority.normal),
      status: AnnouncementStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => AnnouncementStatus.published),
      publishAt: (json['publishAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      expiresAt: (json['expiresAt'] as Timestamp?)?.toDate(),
      createdBy: json['createdBy'] ?? '',
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Announcement copyWith({
    String? id,
    String? title,
    String? content,
    AnnouncementType? type,
    List<String>? targetFeatures,
    Map<String, dynamic>? targetAudience,
    AnnouncementDisplayStyle? displayStyle,
    AnnouncementPriority? priority,
    AnnouncementStatus? status,
    DateTime? publishAt,
    DateTime? expiresAt,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Announcement(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      type: type ?? this.type,
      targetFeatures: targetFeatures ?? this.targetFeatures,
      targetAudience: targetAudience ?? this.targetAudience,
      displayStyle: displayStyle ?? this.displayStyle,
      priority: priority ?? this.priority,
      status: status ?? this.status,
      publishAt: publishAt ?? this.publishAt,
      expiresAt: expiresAt ?? this.expiresAt,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
