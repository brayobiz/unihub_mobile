enum ReportType { marketplace, housing, feedItem, user, chat }

enum ReportStatus { pending, underReview, resolved, dismissed }

class AdminReport {
  final String id;
  final String reporterId;
  final String? reportedUserId; // The user being reported or author of content
  final String? targetId; // ID of listing, post, etc.
  final ReportType type;
  final String reason;
  final String? detailedReason;
  final ReportStatus status;
  final DateTime createdAt;
  final List<ModerationHistoryItem> history;
  final Map<String, dynamic> metadata;

  AdminReport({
    required this.id,
    required this.reporterId,
    this.reportedUserId,
    this.targetId,
    required this.type,
    required this.reason,
    this.detailedReason,
    this.status = ReportStatus.pending,
    required this.createdAt,
    this.history = const [],
    this.metadata = const {},
  });
}

class ModerationHistoryItem {
  final String adminId;
  final String action; // 'dismissed', 'warned', 'removed_content', 'suspended', 'banned'
  final String? notes;
  final DateTime timestamp;

  ModerationHistoryItem({
    required this.adminId,
    required this.action,
    this.notes,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'adminId': adminId,
    'action': action,
    'notes': notes,
    'timestamp': timestamp,
  };

  factory ModerationHistoryItem.fromJson(Map<String, dynamic> json) => ModerationHistoryItem(
    adminId: json['adminId'] ?? '',
    action: json['action'] ?? '',
    notes: json['notes'],
    timestamp: (json['timestamp'] as dynamic)?.toDate() ?? DateTime.now(),
  );
}
