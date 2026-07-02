import 'package:cloud_firestore/cloud_firestore.dart';
import 'chat_context.dart';

enum MessageType { text, image, file, quickReply }
enum MessageStatus { sending, sent, delivered, read }

class Message {
  final String id;
  final String senderId;
  final String content;
  final MessageType type;
  final MessageStatus status;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
  final ChatContext? context;

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    this.type = MessageType.text,
    this.status = MessageStatus.sent,
    required this.timestamp,
    this.metadata,
    this.context,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'senderId': senderId,
      'content': content,
      'type': type.name,
      'status': status.name,
      'timestamp': Timestamp.fromDate(timestamp),
      'metadata': metadata,
      'context': context?.toJson(),
    };
  }

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['id'] ?? '',
      senderId: json['senderId'] ?? '',
      content: json['content'] ?? '',
      type: MessageType.values.firstWhere((e) => e.name == json['type'], orElse: () => MessageType.text),
      status: MessageStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => MessageStatus.sent),
      timestamp: (json['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: json['metadata'],
      context: json['context'] != null ? ChatContext.fromJson(json['context']) : null,
    );
  }

  Message copyWith({
    String? id,
    String? senderId,
    String? content,
    MessageType? type,
    MessageStatus? status,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
    ChatContext? context,
  }) {
    return Message(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      content: content ?? this.content,
      type: type ?? this.type,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
      context: context ?? this.context,
    );
  }
}
