import 'package:cloud_firestore/cloud_firestore.dart';

class EventCategory {
  final String id;
  final String label;
  final String icon; // Icon name or emoji
  final String? description;
  final int priority;
  final bool isActive;

  EventCategory({
    required this.id,
    required this.label,
    required this.icon,
    this.description,
    this.priority = 0,
    this.isActive = true,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'label': label,
      'icon': icon,
      'description': description,
      'priority': priority,
      'isActive': isActive,
    };
  }

  factory EventCategory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EventCategory(
      id: doc.id,
      label: data['label'] ?? '',
      icon: data['icon'] ?? '',
      description: data['description'],
      priority: data['priority'] ?? 0,
      isActive: data['isActive'] ?? true,
    );
  }
}
