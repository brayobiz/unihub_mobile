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
    return Conversation(
      id: json['id'] ?? '',
      participants: List<String>.from(json['participants'] ?? []),
      context: json['context'] != null ? ChatContext.fromJson(json['context']) : null,
      lastMessage: json['lastMessage'],
      lastMessageSenderId: json['lastMessageSenderId'],
      lastMessageStatus: json['lastMessageStatus'] != null 
          ? MessageStatus.values.firstWhere((e) => e.name == json['lastMessageStatus'], orElse: () => MessageStatus.sent)
          : null,
      lastMessageTime: (json['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCounts: Map<String, int>.from(json['unreadCounts'] ?? {}),
      typing: Map<String, dynamic>.from(json['typing'] ?? {}),
      isSupport: json['isSupport'] ?? false,
      supportStatus: json['supportStatus'],
      supportPriority: json['supportPriority'],
      assignedAdminId: json['assignedAdminId'],
      supportAdminNotes: List<Map<String, dynamic>>.from(json['supportAdminNotes'] ?? []),
      expiresAt: (json['expiresAt'] as Timestamp?)?.toDate(),
    );
  }
}
