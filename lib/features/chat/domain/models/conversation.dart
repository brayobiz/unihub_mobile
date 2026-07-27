import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_context.dart';
import 'message.dart';

class Conversation {
  final String id;
  final List<String> participants;
  final ChatContext? context; // Represents the most recent context (e.g. latest listing)
  final String? lastMessage;
  final String? lastMessageSenderId;
  final MessageStatus? lastMessageStatus;
  final DateTime lastMessageTime;
  final Map<String, int> unreadCounts;
  final Map<String, dynamic> typing;
  final bool isSupport;
  final String? supportStatus; // 'active', 'waiting_admin', 'waiting_user', 'resolved', 'closed'
  final String? supportPriority; // 'low', 'normal', 'high', 'urgent'
  final String? assignedAdminId;
  final List<Map<String, dynamic>> supportAdminNotes;
  final DateTime? expiresAt;

  Conversation({
    required this.id,
    required this.participants,
    this.context,
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageStatus,
    required this.lastMessageTime,
    required this.unreadCounts,
    this.typing = const {},
    this.isSupport = false,
    this.supportStatus,
    this.supportPriority,
    this.assignedAdminId,
    this.supportAdminNotes = const [],
    this.expiresAt,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = {
      'id': id,
      'participants': participants,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'unreadCounts': unreadCounts,
      'typing': typing,
      'isSupport': isSupport,
      'supportAdminNotes': supportAdminNotes,
    };

    if (context != null) data['context'] = context!.toJson();
    if (lastMessage != null) data['lastMessage'] = lastMessage;
    if (lastMessageSenderId != null) data['lastMessageSenderId'] = lastMessageSenderId;
    if (lastMessageStatus != null) data['lastMessageStatus'] = lastMessageStatus!.name;
    if (supportStatus != null) data['supportStatus'] = supportStatus;
    if (supportPriority != null) data['supportPriority'] = supportPriority;
    if (assignedAdminId != null) data['assignedAdminId'] = assignedAdminId;
    if (expiresAt != null) data['expiresAt'] = Timestamp.fromDate(expiresAt!);

    return data;
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    // Audit Phase 4.9: Robust Parsing to prevent crashes from malformed data
    DateTime parseDate(dynamic value) {
      if (value is Timestamp) return value.toDate();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      return DateTime.now();
    }

    return Conversation(
      id: json['id']?.toString() ?? '',
      participants: (json['participants'] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
      context: json['context'] != null ? ChatContext.fromJson(json['context'] as Map<String, dynamic>) : null,
      lastMessage: json['lastMessage']?.toString(),
      lastMessageSenderId: json['lastMessageSenderId']?.toString(),
      lastMessageStatus: json['lastMessageStatus'] != null 
          ? MessageStatus.values.firstWhere(
              (e) => e.name == json['lastMessageStatus'].toString(), 
              orElse: () => MessageStatus.sent
            )
          : null,
      lastMessageTime: parseDate(json['lastMessageTime']),
      unreadCounts: Map<String, int>.from(
        (json['unreadCounts'] as Map?)?.map((k, v) => MapEntry(k.toString(), v is int ? v : 0)) ?? {}
      ),
      typing: Map<String, dynamic>.from(json['typing'] as Map? ?? {}),
      isSupport: json['isSupport'] == true,
      supportStatus: json['supportStatus']?.toString(),
      supportPriority: json['supportPriority']?.toString(),
      assignedAdminId: json['assignedAdminId']?.toString(),
      supportAdminNotes: (json['supportAdminNotes'] as List?)?.map((e) => Map<String, dynamic>.from(e as Map)).toList() ?? [],
      expiresAt: json['expiresAt'] != null ? parseDate(json['expiresAt']) : null,
    );
  }

  /// Checks if a participant is currently typing, with a 15-second expiry.
  bool isParticipantTyping(String userId) {
    final dynamic timestamp = typing[userId];
    if (timestamp == null) return false;
    
    DateTime? typingTime;
    if (timestamp is Timestamp) {
      typingTime = timestamp.toDate();
    } else if (timestamp is DateTime) {
      typingTime = timestamp;
    }
    
    if (typingTime == null) return false;
    
    final diff = DateTime.now().difference(typingTime).inSeconds;
    return diff >= 0 && diff < 15;
  }
}
