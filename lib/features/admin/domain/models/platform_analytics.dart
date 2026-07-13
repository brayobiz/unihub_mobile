import 'package:cloud_firestore/cloud_firestore.dart';

class PlatformAnalytics {
  final int totalUsers;
  final int activeUsers; // Users logged in in the last 30 days
  final int verifiedUsers;
  final int totalMarketplaceListings;
  final int totalHousingListings;
  final int totalNotes;
  final int pendingReports;
  final int pendingVerifications;
  final int openSupportConversations;
  final int activeAnnouncements;
  final int totalEvents;
  final int pendingEventApprovals;
  final int newUsersToday;
  final int currentlyActive;
  final DateTime updatedAt;

  PlatformAnalytics({
    required this.totalUsers,
    required this.activeUsers,
    required this.verifiedUsers,
    required this.totalMarketplaceListings,
    required this.totalHousingListings,
    required this.totalNotes,
    required this.pendingReports,
    required this.pendingVerifications,
    required this.openSupportConversations,
    required this.activeAnnouncements,
    required this.totalEvents,
    required this.pendingEventApprovals,
    required this.newUsersToday,
    required this.currentlyActive,
    required this.updatedAt,
  });

  factory PlatformAnalytics.empty() => PlatformAnalytics(
    totalUsers: 0,
    activeUsers: 0,
    verifiedUsers: 0,
    totalMarketplaceListings: 0,
    totalHousingListings: 0,
    totalNotes: 0,
    pendingReports: 0,
    pendingVerifications: 0,
    openSupportConversations: 0,
    activeAnnouncements: 0,
    totalEvents: 0,
    pendingEventApprovals: 0,
    newUsersToday: 0,
    currentlyActive: 0,
    updatedAt: DateTime.now(),
  );

  PlatformAnalytics copyWith({
    int? totalUsers,
    int? activeUsers,
    int? verifiedUsers,
    int? totalMarketplaceListings,
    int? totalHousingListings,
    int? totalNotes,
    int? pendingReports,
    int? pendingVerifications,
    int? openSupportConversations,
    int? activeAnnouncements,
    int? totalEvents,
    int? pendingEventApprovals,
    int? newUsersToday,
    int? currentlyActive,
    DateTime? updatedAt,
  }) {
    return PlatformAnalytics(
      totalUsers: totalUsers ?? this.totalUsers,
      activeUsers: activeUsers ?? this.activeUsers,
      verifiedUsers: verifiedUsers ?? this.verifiedUsers,
      totalMarketplaceListings: totalMarketplaceListings ?? this.totalMarketplaceListings,
      totalHousingListings: totalHousingListings ?? this.totalHousingListings,
      totalNotes: totalNotes ?? this.totalNotes,
      pendingReports: pendingReports ?? this.pendingReports,
      pendingVerifications: pendingVerifications ?? this.pendingVerifications,
      openSupportConversations: openSupportConversations ?? this.openSupportConversations,
      activeAnnouncements: activeAnnouncements ?? this.activeAnnouncements,
      totalEvents: totalEvents ?? this.totalEvents,
      pendingEventApprovals: pendingEventApprovals ?? this.pendingEventApprovals,
      newUsersToday: newUsersToday ?? this.newUsersToday,
      currentlyActive: currentlyActive ?? this.currentlyActive,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
