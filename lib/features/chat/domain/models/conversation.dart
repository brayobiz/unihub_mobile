import 'package:cloud_firestore/cloud_firestore.dart';

class Conversation {
  final String id;
  final List<String> participants;
  final String listingId;
  final String gigId;
  final String listingTitle;
  final String? lastMessage;
  final DateTime lastMessageTime;
  final Map<String, int> unreadCounts;
  final bool isSupport;
  final String? module;

  Conversation({
    required this.id,
    required this.participants,
    this.listingId = '',
    this.gigId = '',
    required this.listingTitle,
    this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCounts,
    this.isSupport = false,
    this.module,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participants': participants,
      'listingId': listingId,
      'gigId': gigId,
      'listingTitle': listingTitle,
      'lastMessage': lastMessage,
      'lastMessageTime': Timestamp.fromDate(lastMessageTime),
      'unreadCounts': unreadCounts,
      'isSupport': isSupport,
      'module': module,
    };
  }

  factory Conversation.fromJson(Map<String, dynamic> json) {
    return Conversation(
      id: json['id'] ?? '',
      participants: List<String>.from(json['participants'] ?? []),
      listingId: json['listingId'] ?? '',
      gigId: json['gigId'] ?? '',
      listingTitle: json['listingTitle'] ?? '',
      lastMessage: json['lastMessage'],
      lastMessageTime: (json['lastMessageTime'] as Timestamp).toDate(),
      unreadCounts: Map<String, int>.from(json['unreadCounts'] ?? {}),
      isSupport: json['isSupport'] ?? false,
      module: json['module'],
    );
  }
}
