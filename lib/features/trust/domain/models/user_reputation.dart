class UserReputation {
  final double trustScore; // 0 - 100
  final int ratingsCount;
  final double averageRating;
  final double sellerRating;
  final double buyerRating;
  final int completedTransactions;
  final String responseRate;
  final int successfulReferrals;
  final List<String> badges;

  UserReputation({
    this.trustScore = 70.0,
    this.ratingsCount = 0,
    this.averageRating = 0.0,
    this.sellerRating = 0.0,
    this.buyerRating = 0.0,
    this.completedTransactions = 0,
    this.responseRate = '95%',
    this.successfulReferrals = 0,
    this.badges = const [],
  });

  factory UserReputation.fromMap(Map<String, dynamic> data) {
    return UserReputation(
      trustScore: (data['trustScore'] ?? 70.0).toDouble(),
      ratingsCount: data['ratingsCount'] ?? 0,
      averageRating: (data['averageRating'] ?? 0.0).toDouble(),
      sellerRating: (data['sellerRating'] ?? 0.0).toDouble(),
      buyerRating: (data['buyerRating'] ?? 0.0).toDouble(),
      completedTransactions: data['completedTransactions'] ?? 0,
      responseRate: data['responseRate'] ?? '95%',
      successfulReferrals: data['successfulReferrals'] ?? 0,
      badges: List<String>.from(data['badges'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'trustScore': trustScore,
      'ratingsCount': ratingsCount,
      'averageRating': averageRating,
      'sellerRating': sellerRating,
      'buyerRating': buyerRating,
      'completedTransactions': completedTransactions,
      'responseRate': responseRate,
      'successfulReferrals': successfulReferrals,
      'badges': badges,
    };
  }
}
