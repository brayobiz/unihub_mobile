class AdminStats {
  final int totalUsers;
  final int newUsersToday;
  final int totalMarketplaceListings;
  final int totalHousingListings;
  final int totalNotes;
  final int pendingVerifications;
  final int totalReports;
  final int resolvedReports;
  final int openSupportTickets;
  final int activeAnnouncements;

  AdminStats({
    required this.totalUsers,
    this.newUsersToday = 0,
    required this.totalMarketplaceListings,
    required this.totalHousingListings,
    required this.totalNotes,
    required this.pendingVerifications,
    required this.totalReports,
    this.resolvedReports = 0,
    this.openSupportTickets = 0,
    this.activeAnnouncements = 0,
  });

  factory AdminStats.empty() => AdminStats(
    totalUsers: 0,
    newUsersToday: 0,
    totalMarketplaceListings: 0,
    totalHousingListings: 0,
    totalNotes: 0,
    pendingVerifications: 0,
    totalReports: 0,
    resolvedReports: 0,
    openSupportTickets: 0,
    activeAnnouncements: 0,
  );
}
