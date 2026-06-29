class ChatContext {
  final String type; // e.g., 'marketplace', 'housing'
  final String id;
  final String title;
  final String? thumbnail;
  final Map<String, dynamic>? metadata;

  ChatContext({
    required this.type,
    required this.id,
    required this.title,
    this.thumbnail,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'id': id,
      'title': title,
      'thumbnail': thumbnail,
      'metadata': metadata,
    };
  }

  factory ChatContext.fromJson(Map<String, dynamic> json) {
    return ChatContext(
      type: json['type'] ?? '',
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      thumbnail: json['thumbnail'],
      metadata: json['metadata'],
    );
  }
}
