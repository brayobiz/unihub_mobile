import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_context.dart';
import 'message.dart';

class Conversation {
  final String id;
  final List<String> participants;
  final ChatContext context;
  final String? lastMessage;
  final String? lastMessageSenderId;
  final MessageStatus? lastMessageStatus;
  final DateTime lastMessageTime;
  final Map<String, int> unreadCounts;
  final Map<String, dynamic> typing;
  final bool isSupport;

  Conversation({
    required this.id,
    required this.participants,
    required this.context,
    this.lastMessage,
    this.lastMessageSenderId,
    this.lastMessageStatus,
    required this.lastMessageTime,
    required this.unreadCounts,
    this.typing = const {},
    this.isSupport = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participants': participants,
      'context': context.toJson(),
      'lastMessage': lastMessage,
      'lastMessageSenderId': lastMessageSenderId,
      'lastMessageStatus': lastMessageStatus?.name,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'unreadCounts': unreadCounts,
      'typing': typing,
      'isSupport': isSupport,
    };
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] ?? '',
      participants: List<String>.from(json['participants'] ?? []),
      context: ChatContext.fromJson(json['context'] ?? {}),
      lastMessage: json['lastMessage'],
      lastMessageSenderId: json['lastMessageSenderId'],
      lastMessageStatus: json['lastMessageStatus'] != null 
          ? MessageStatus.values.firstWhere((e) => e.name == json['lastMessageStatus'], orElse: () => MessageStatus.sent)
          : null,
      lastMessageTime: (json['lastMessageTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      unreadCounts: Map<String, int>.from(json['unreadCounts'] ?? {}),
      typing: Map<String, dynamic>.from(json['typing'] ?? {}),
      isSupport: json['isSupport'] ?? false,
    );
  }
}
