class UserAnalytics {
  final int totalUsers;
  final int newUsersToday;
  final int newUsersThisWeek;
  final int newUsersThisMonth;
  
  final int dailyActiveUsers;
  final int weeklyActiveUsers;
  final int monthlyActiveUsers;
  final int currentlyActive;

  final int verifiedUsers;
  final int pendingVerifications;
  final int rejectedVerifications;
  final double verificationApprovalRate;

  final Map<String, int> usersByUniversity;
  final Map<String, int> usersByAccountType;
  
  final double averageTrustScore;
  final Map<String, int> trustScoreDistribution; // e.g., 0-20, 21-40, etc.

  final List<GrowthDataPoint> growthTrend;
  final DateTime updatedAt;

  UserAnalytics({
    required this.totalUsers,
    required this.newUsersToday,
    required this.newUsersThisWeek,
    required this.newUsersThisMonth,
    required this.dailyActiveUsers,
    required this.weeklyActiveUsers,
    required this.monthlyActiveUsers,
    required this.currentlyActive,
    required this.verifiedUsers,
    required this.pendingVerifications,
    required this.rejectedVerifications,
    required this.verificationApprovalRate,
    required this.usersByUniversity,
    required this.usersByAccountType,
    required this.averageTrustScore,
    required this.trustScoreDistribution,
    required this.growthTrend,
    required this.updatedAt,
  });

  factory UserAnalytics.empty() => UserAnalytics(
    totalUsers: 0,
    newUsersToday: 0,
    newUsersThisWeek: 0,
    newUsersThisMonth: 0,
    dailyActiveUsers: 0,
    weeklyActiveUsers: 0,
    monthlyActiveUsers: 0,
    currentlyActive: 0,
    verifiedUsers: 0,
    pendingVerifications: 0,
    rejectedVerifications: 0,
    verificationApprovalRate: 0.0,
    usersByUniversity: {},
    usersByAccountType: {},
    averageTrustScore: 0.0,
    trustScoreDistribution: {},
    growthTrend: [],
    updatedAt: DateTime.now(),
  );
}

class GrowthDataPoint {
  final DateTime date;
  final int count;

  GrowthDataPoint(this.date, this.count);
}
