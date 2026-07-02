import 'package:flutter/material.dart';

enum BadgeType {
  verification, // Platform badges (Identity, Student)
  professional, // Professional roles (Seller, Tutor)
  achievement,  // Milestones (Top Seller, Early Adopter)
  community,    // Social standing (Helper, Contributor)
  feature,      // Feature-specific (Premium, Beta)
}

class AppBadge {
  final String id;
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final BadgeType type;
  final DateTime? awardedAt;
  final Map<String, dynamic> metadata;

  const AppBadge({
    required this.id,
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.type,
    this.awardedAt,
    this.metadata = const {},
  });

  // Helper to create badges from existing logic
  static AppBadge identityVerified() => const AppBadge(
    id: 'identity_verified',
    label: 'ID Verified',
    description: 'Platform identity confirmed via government ID',
    icon: Icons.badge_rounded,
    color: Colors.blue,
    type: BadgeType.verification,
  );

  static AppBadge studentVerified() => const AppBadge(
    id: 'student_verified',
    label: 'Student',
    description: 'Confirmed enrollment at a university',
    icon: Icons.school_rounded,
    color: Colors.green,
    type: BadgeType.verification,
  );
}
