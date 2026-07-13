import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/platform_analytics.dart';
import '../../domain/models/user_analytics.dart';
import '../../domain/models/feature_analytics.dart';

class AdminAnalyticsRepository {
  final FirebaseFirestore _firestore;

  AdminAnalyticsRepository(this._firestore);

  Future<PlatformAnalytics> getPlatformAnalytics() async {
    // ... existing implementation (I will merge them later if needed, but for now I'll implement getUserAnalytics)
    // Actually, I should probably keep getPlatformAnalytics for the high-level dashboard 
    // and add getUserAnalytics for the detailed one.
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));
    final startOfToday = DateTime(now.year, now.month, now.day);

    final results = await Future.wait([
      // Users
      _firestore.collection('users').count().get(),
      _firestore.collection('users')
          .where('lastSeen', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo))
          .count().get(),
      _firestore.collection('users')
          .where('isIdentityVerified', isEqualTo: true)
          .count().get(),
      
      // Marketplace
      _firestore.collection('listings').where('status', isEqualTo: 'active').count().get(),
      
      // Housing
      _firestore.collection('housing_listings').where('status', isEqualTo: 'available').count().get(),
      
      // Notes
      _firestore.collection('notes').where('status', isEqualTo: 'active').count().get(),
      
      // Moderation
      _firestore.collection('reports').where('status', isEqualTo: 'pending').count().get(),
      _firestore.collection('housing_reports').where('status', isEqualTo: 'pending').count().get(),
      
      // Pending verifications
      _firestore.collection('identity_verifications').where('status', isEqualTo: 'pending').count().get(),
      _firestore.collection('student_verifications').where('status', isEqualTo: 'pending').count().get(),
      _firestore.collection('verification_applications').where('status', isEqualTo: 'pending').count().get(),
      _firestore.collection('organizer_verification_requests').where('status', isEqualTo: 'pending').count().get(),

      // Support
      _firestore.collection('conversations')
          .where('isSupport', isEqualTo: true)
          .where('supportStatus', whereIn: ['waiting_admin', 'active'])
          .count().get(),

      // Announcements
      _firestore.collection('announcements')
          .where('status', whereIn: ['published', 'scheduled'])
          .get(),

      // Events
      _firestore.collection('events').count().get(),
      _firestore.collection('events')
          .where('status', isEqualTo: 'submitted').count().get(),

      // New users today
      _firestore.collection('users')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday))
          .count().get(),
    ]);

    final announcementsSnap = results[13] as QuerySnapshot;
    final activeAnnouncements = announcementsSnap.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final publishAt = (data['publishAt'] as Timestamp?)?.toDate();
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
      if (publishAt == null) return false;
      return publishAt.isBefore(now) && (expiresAt == null || expiresAt.isAfter(now));
    }).length;

    return PlatformAnalytics(
      totalUsers: (results[0] as AggregateQuerySnapshot).count ?? 0,
      activeUsers: (results[1] as AggregateQuerySnapshot).count ?? 0,
      verifiedUsers: (results[2] as AggregateQuerySnapshot).count ?? 0,
      totalMarketplaceListings: (results[3] as AggregateQuerySnapshot).count ?? 0,
      totalHousingListings: (results[4] as AggregateQuerySnapshot).count ?? 0,
      totalNotes: (results[5] as AggregateQuerySnapshot).count ?? 0,
      pendingReports: ((results[6] as AggregateQuerySnapshot).count ?? 0) + 
                       ((results[7] as AggregateQuerySnapshot).count ?? 0),
      pendingVerifications: ((results[8] as AggregateQuerySnapshot).count ?? 0) + 
                           ((results[9] as AggregateQuerySnapshot).count ?? 0) + 
                           ((results[10] as AggregateQuerySnapshot).count ?? 0) +
                           ((results[11] as AggregateQuerySnapshot).count ?? 0),
      openSupportConversations: (results[12] as AggregateQuerySnapshot).count ?? 0,
      activeAnnouncements: activeAnnouncements,
      totalEvents: (results[14] as AggregateQuerySnapshot).count ?? 0,
      pendingEventApprovals: (results[15] as AggregateQuerySnapshot).count ?? 0,
      newUsersToday: (results[16] as AggregateQuerySnapshot).count ?? 0,
      updatedAt: now,
    );
  }

  Future<UserAnalytics> getUserAnalytics() async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // For trends (last 7 days)
    final trendDays = List.generate(7, (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i)));

    final results = await Future.wait([
      // Growth
      _firestore.collection('users').count().get(),
      _firestore.collection('users').where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday)).count().get(),
      _firestore.collection('users').where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek)).count().get(),
      _firestore.collection('users').where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfMonth)).count().get(),
      
      // Activity
      _firestore.collection('users').where('lastSeen', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday)).count().get(),
      _firestore.collection('users').where('lastSeen', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfWeek)).count().get(),
      _firestore.collection('users').where('lastSeen', isGreaterThanOrEqualTo: Timestamp.fromDate(thirtyDaysAgo)).count().get(),
      _firestore.collection('users').where('isOnline', isEqualTo: true).count().get(),

      // Verifications
      _firestore.collection('users').where('isIdentityVerified', isEqualTo: true).count().get(),
      // Rejected verifications (checking all 4 collections)
      _firestore.collection('identity_verifications').where('status', isEqualTo: 'rejected').count().get(),
      _firestore.collection('student_verifications').where('status', isEqualTo: 'rejected').count().get(),
      _firestore.collection('verification_applications').where('status', isEqualTo: 'rejected').count().get(),
      _firestore.collection('organizer_verification_requests').where('status', isEqualTo: 'rejected').count().get(),

      // Account Types
      _firestore.collection('users').where('accountType', isEqualTo: 'student').count().get(),
      _firestore.collection('users').where('accountType', isEqualTo: 'business').count().get(),

      // Trust Score - Average
      _firestore.collection('users').aggregate(average('trustScore')).get(),

      // Trust Distribution Buckets
      _firestore.collection('users').where('trustScore', isGreaterThanOrEqualTo: 0).where('trustScore', isLessThan: 20).count().get(),
      _firestore.collection('users').where('trustScore', isGreaterThanOrEqualTo: 20).where('trustScore', isLessThan: 40).count().get(),
      _firestore.collection('users').where('trustScore', isGreaterThanOrEqualTo: 40).where('trustScore', isLessThan: 60).count().get(),
      _firestore.collection('users').where('trustScore', isGreaterThanOrEqualTo: 60).where('trustScore', isLessThan: 80).count().get(),
      _firestore.collection('users').where('trustScore', isGreaterThanOrEqualTo: 80).count().get(),

      // Trend data points (Last 7 days)
      ...trendDays.map((date) => _firestore.collection('users').where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(date)).where('createdAt', isLessThan: Timestamp.fromDate(date.add(const Duration(days: 1)))).count().get()),
    ]);

    int offset = 0;
    final totalUsers = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final newToday = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final newWeek = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final newMonth = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    
    final dau = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final wau = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final mau = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final online = (results[offset++] as AggregateQuerySnapshot).count ?? 0;

    final verified = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final rejected = ((results[offset++] as AggregateQuerySnapshot).count ?? 0) + 
                     ((results[offset++] as AggregateQuerySnapshot).count ?? 0) +
                     ((results[offset++] as AggregateQuerySnapshot).count ?? 0) +
                     ((results[offset++] as AggregateQuerySnapshot).count ?? 0);

    final students = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final businesses = (results[offset++] as AggregateQuerySnapshot).count ?? 0;

    final avgTrust = (results[offset++] as AggregateQuerySnapshot).getAverage('trustScore') ?? 0.0;

    final trustDist = {
      '0-20': (results[offset++] as AggregateQuerySnapshot).count ?? 0,
      '21-40': (results[offset++] as AggregateQuerySnapshot).count ?? 0,
      '41-60': (results[offset++] as AggregateQuerySnapshot).count ?? 0,
      '61-80': (results[offset++] as AggregateQuerySnapshot).count ?? 0,
      '81-100': (results[offset++] as AggregateQuerySnapshot).count ?? 0,
    };

    final growthTrend = <GrowthDataPoint>[];
    for (var date in trendDays) {
      growthTrend.add(GrowthDataPoint(date, (results[offset++] as AggregateQuerySnapshot).count ?? 0));
    }

    // Identify Pending (Reuse logic from platform analytics if needed, or recalculate)
    // To avoid making this method too long, I'll just use the already fetched platform analytics 
    // or do a quick sub-query if necessary.
    final pendingVerif = await _firestore.collection('identity_verifications').where('status', isEqualTo: 'pending').count().get()
        .then((snap) => snap.count ?? 0); // Partial for now, or I could have included it in Future.wait

    return UserAnalytics(
      totalUsers: totalUsers,
      newUsersToday: newToday,
      newUsersThisWeek: newWeek,
      newUsersThisMonth: newMonth,
      dailyActiveUsers: dau,
      weeklyActiveUsers: wau,
      monthlyActiveUsers: mau,
      currentlyActive: online,
      verifiedUsers: verified,
      pendingVerifications: pendingVerif,
      rejectedVerifications: rejected,
      verificationApprovalRate: verified > 0 ? (verified / (verified + rejected)) : 0.0,
      usersByUniversity: {}, // Will handle this via a separate specific fetch for top unis
      usersByAccountType: {'Student': students, 'Business': businesses},
      averageTrustScore: avgTrust,
      trustScoreDistribution: trustDist,
      growthTrend: growthTrend,
      updatedAt: now,
    );
  }

  Stream<PlatformAnalytics> watchPlatformAnalytics() async* {
    yield await getPlatformAnalytics();
    yield* Stream.periodic(const Duration(minutes: 5)).asyncMap((_) => getPlatformAnalytics());
  }

  Stream<UserAnalytics> watchUserAnalytics() async* {
    yield await getUserAnalytics();
    yield* Stream.periodic(const Duration(minutes: 10)).asyncMap((_) => getUserAnalytics());
  }

  Future<FeatureAnalytics> getFeatureAnalytics() async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    final results = await Future.wait([
      // 0-4: Marketplace
      _firestore.collection('listings').count().get(),
      _firestore.collection('listings').where('status', isEqualTo: 'active').count().get(),
      _firestore.collection('listings').where('status', isEqualTo: 'sold').count().get(),
      _firestore.collection('listings').where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday)).count().get(),
      _firestore.collection('listings').aggregate(sum('viewsCount'), sum('savesCount'), sum('chatsStartedCount')).get(),

      // 5-9: Housing
      _firestore.collection('housing_listings').count().get(),
      _firestore.collection('housing_listings').where('status', isEqualTo: 'available').count().get(),
      _firestore.collection('housing_listings').where('status', isEqualTo: 'taken').count().get(),
      _firestore.collection('housing_listings').where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday)).count().get(),
      _firestore.collection('housing_listings').aggregate(sum('views'), sum('saves')).get(),

      // 10-13: Notes
      _firestore.collection('notes').count().get(),
      _firestore.collection('notes').where('status', isEqualTo: 'active').count().get(),
      _firestore.collection('notes').where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday)).count().get(),
      _firestore.collection('notes').aggregate(sum('views'), sum('downloadsCount')).get(),

      // 14-16: Events
      _firestore.collection('events').count().get(),
      _firestore.collection('events').where('status', isEqualTo: 'approved').count().get(),
      _firestore.collection('events').where('status', isEqualTo: 'submitted').count().get(),

      // 17-21: Support
      _firestore.collection('conversations').where('isSupport', isEqualTo: true).count().get(),
      _firestore.collection('conversations').where('isSupport', isEqualTo: true).where('supportStatus', whereIn: ['waiting_admin', 'active']).count().get(),
      _firestore.collection('conversations').where('isSupport', isEqualTo: true).where('supportStatus', isEqualTo: 'waiting_admin').count().get(),
      _firestore.collection('conversations').where('isSupport', isEqualTo: true).where('supportStatus', isEqualTo: 'waiting_user').count().get(),
      _firestore.collection('conversations').where('isSupport', isEqualTo: true).where('supportStatus', isEqualTo: 'resolved').where('updatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday)).count().get(),

      // 22-25: Moderation
      _firestore.collection('reports').where('status', isEqualTo: 'pending').count().get(),
      _firestore.collection('reports').where('status', isEqualTo: 'resolved').where('updatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday)).count().get(),
      // Reusing logic for pending verifications
      _firestore.collection('identity_verifications').where('status', isEqualTo: 'pending').count().get(),
      _firestore.collection('identity_verifications').where('status', isEqualTo: 'rejected').where('updatedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfToday)).count().get(),

      // 26: Announcements
      _firestore.collection('announcements').get(),
    ]);

    int offset = 0;
    
    // Marketplace
    final mTotal = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final mActive = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final mSold = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final mNew = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final mAgg = results[offset++] as AggregateQuerySnapshot;
    final mViews = (mAgg.getSum('viewsCount') ?? 0).toInt();
    final mSaves = (mAgg.getSum('savesCount') ?? 0).toInt();
    final mChats = (mAgg.getSum('chatsStartedCount') ?? 0).toInt();

    // Housing
    final hTotal = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final hAvailable = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final hTaken = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final hNew = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final hAgg = results[offset++] as AggregateQuerySnapshot;
    final hViews = (hAgg.getSum('views') ?? 0).toInt();
    final hSaves = (hAgg.getSum('saves') ?? 0).toInt();

    // Notes
    final nTotal = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final nActive = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final nNew = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final nAgg = results[offset++] as AggregateQuerySnapshot;
    final nViews = (nAgg.getSum('views') ?? 0).toInt();
    final nDownloads = (nAgg.getSum('downloadsCount') ?? 0).toInt();

    // Events
    final eTotal = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final eActive = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final ePending = (results[offset++] as AggregateQuerySnapshot).count ?? 0;

    // Support
    final sTotal = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final sOpen = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final sWaitAdmin = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final sWaitUser = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final sResolvedToday = (results[offset++] as AggregateQuerySnapshot).count ?? 0;

    // Moderation
    final modPendingReports = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final modResolvedReportsToday = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final modPendingVerif = (results[offset++] as AggregateQuerySnapshot).count ?? 0;
    final modRejectedVerifToday = (results[offset++] as AggregateQuerySnapshot).count ?? 0;

    // Announcements
    final announcementsSnap = results[offset++] as QuerySnapshot;
    int activeAnn = 0;
    int scheduledAnn = 0;
    int expiredAnn = 0;
    for (var doc in announcementsSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final publishAt = (data['publishAt'] as Timestamp?)?.toDate();
      final expiresAt = (data['expiresAt'] as Timestamp?)?.toDate();
      if (publishAt == null) continue;
      if (publishAt.isAfter(now)) {
        scheduledAnn++;
      } else if (expiresAt != null && expiresAt.isBefore(now)) {
        expiredAnn++;
      } else {
        activeAnn++;
      }
    }

    return FeatureAnalytics(
      marketplace: MarketplaceStats(
        totalListings: mTotal,
        activeListings: mActive,
        soldListings: mSold,
        newListingsToday: mNew,
        listingsByCategory: {}, // Complex to do via aggregation without cloud functions
        totalViews: mViews,
        totalSaves: mSaves,
        totalChatsStarted: mChats,
      ),
      housing: HousingStats(
        totalListings: hTotal,
        availableListings: hAvailable,
        takenListings: hTaken,
        newListingsToday: hNew,
        listingsByUniversity: {}, 
        totalViews: hViews,
        totalSaves: hSaves,
      ),
      notes: NotesStats(
        totalNotes: nTotal,
        activeNotes: nActive,
        newNotesToday: nNew,
        notesByCategory: {},
        totalViews: nViews,
        totalDownloads: nDownloads,
      ),
      events: EventStats(
        totalEvents: eTotal,
        upcomingEvents: 0, // Need date comparison
        liveEvents: eActive,
        pendingApprovals: ePending,
        totalAttendees: 0,
      ),
      support: SupportStats(
        totalConversations: sTotal,
        openConversations: sOpen,
        waitingAdmin: sWaitAdmin,
        waitingUser: sWaitUser,
        resolvedToday: sResolvedToday,
      ),
      moderation: ModerationStats(
        pendingReports: modPendingReports,
        resolvedReportsToday: modResolvedReportsToday,
        pendingVerifications: modPendingVerif,
        rejectedVerificationsToday: modRejectedVerifToday,
      ),
      announcements: AnnouncementStats(
        activeAnnouncements: activeAnn,
        scheduledAnnouncements: scheduledAnn,
        expiredAnnouncements: expiredAnn,
      ),
      updatedAt: now,
    );
  }

  Stream<FeatureAnalytics> watchFeatureAnalytics() async* {
    yield await getFeatureAnalytics();
    yield* Stream.periodic(const Duration(minutes: 15)).asyncMap((_) => getFeatureAnalytics());
  }
}
