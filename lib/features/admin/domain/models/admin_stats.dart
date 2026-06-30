class AdminStats {
  final int totalUsers;
  final int totalMarketplaceListings;
  final int totalHousingListings;
  final int totalNotes;
  final int pendingVerifications;
  final int totalReports;

  AdminStats({
    required this.totalUsers,
    required this.totalMarketplaceListings,
    required this.totalHousingListings,
    required this.totalNotes,
    required this.pendingVerifications,
    required this.totalReports,
  });

  factory AdminStats.empty() => AdminStats(
    totalUsers: 0,
    totalMarketplaceListings: 0,
    totalHousingListings: 0,
    totalNotes: 0,
    pendingVerifications: 0,
    totalReports: 0,
  );
}
